#!/usr/bin/env python3
"""Turns NekoAI's pets into a Neko plugin full of characters.

    tools/import-nekoai.py                       # fetches what it needs
    tools/import-nekoai.py --from ../NekoAI      # from a checkout you have
    tools/import-nekoai.py --list                # says what it would take, and refuses

`nucket/NekoAI` is the modern rebuild of the same idea this application is — a
sprite that follows the cursor, with a model behind it — and its pets are laid out
in a way that maps onto this one's eighteen states almost exactly. So this exists.

**What it refuses, and why that is the interesting part.** The repository is MIT,
which covers what its author holds the rights to. Its own manifests say who that
is, per pet, in an `author` field — and two of them answer:

    pac-man      author: "Namco / Neko98 community"
    tie-fighter  author: "Lucasfilm / Neko98 community"

Those are not the repository's to relicense, and Neko goes out in a signed disk
image that anybody can download. So this script takes only pets whose own
manifest claims them for the project, and prints the author of every one it puts
back. That rule is in code rather than in a comment because a person running this
in a hurry should not have to remember it.

It also skips the three that already ship with Neko — classic-neko, tabby and
bsd-daemon are the same oneko sprites this application has had all along.

**What comes out** is a `.nekoplugin` folder, not files dropped into
`Resources/Characters`. Characters from somebody else arrive the way 2.5 decided
they should: as a plugin, switched off until somebody turns it on, with its
licence and its attribution in a README beside it — and out of the signed bundle.
"""

import argparse, json, os, plistlib, shutil, subprocess, sys, tempfile, urllib.request

REPO = "nucket/NekoAI"
RAW = "https://raw.githubusercontent.com/%s/HEAD/" % REPO
API = "https://api.github.com/repos/%s/" % REPO

# Their animation names, in the order this application would rather have them.
# Everything unmatched is left out: Neko falls a missing state back to a coarser
# one and eventually to "stop", so a pet with no clawing simply does not claw.
STATES = {
    "stop":     ["idle"],
    "awake":    ["awaken", "alert", "surprised"],
    "sleep":    ["sleep"],
    "akubi":    ["yawn", "falling_asleep"],          # the yawn
    "kaki":     ["wash", "scratch_wall", "bored", "sit", "thinking"],
    "jare":     ["playing", "happy", "eating", "hunting", "studying"],
    "u_move":   ["walk_up"],
    "d_move":   ["walk_down"],
    "l_move":   ["walk_left"],
    "r_move":   ["walk_right"],
    "ul_move":  ["walk_up_left"],
    "ur_move":  ["walk_up_right"],
    "dl_move":  ["walk_down_left"],
    "dr_move":  ["walk_down_right"],
    "u_togi":   ["scratch_up"],
    "d_togi":   ["scratch_down"],
    "l_togi":   ["scratch_left"],
    "r_togi":   ["scratch_right"],
}

# Already here, with the same sprites, since long before this script.
ALREADY_OURS = {"classic-neko", "tabby", "bsd-daemon"}

# The one thing a manifest can say that stops it.
OURS_TO_GIVE = "nekoai community"


def fetch(path):
    with urllib.request.urlopen(RAW + path, timeout=30) as answer:
        return answer.read()


def pet_names(source):
    if source:
        return sorted(n for n in os.listdir(os.path.join(source, "pets"))
                      if os.path.isdir(os.path.join(source, "pets", n)))
    with urllib.request.urlopen(API + "contents/pets", timeout=30) as answer:
        return sorted(item["name"] for item in json.load(answer)
                      if item["type"] == "dir")


def read(source, path):
    if source:
        with open(os.path.join(source, path), "rb") as f:
            return f.read()
    return fetch(path)


def read_or_none(source, path):
    """A manifest can name a file the repository does not have — shiba-pixel names
    thirty-six of them and has none of them — so a missing sprite is a fact about
    that pet rather than the end of the run."""
    try:
        return read(source, path)
    except Exception:
        return None


def ticks_for(fps):
    """Neko ticks eight times a second; their manifests speak in frames a second."""
    if not fps or fps <= 0:
        return 2
    return max(1, min(8, int(round(8.0 / float(fps)))))


def sprite_size(path):
    """Asked of the file rather than assumed: these are not all 32x32."""
    try:
        out = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", path],
                             capture_output=True, text=True).stdout
        width = height = 32
        for line in out.split("\n"):
            if "pixelWidth:" in line:
                width = int(line.split(":")[1])
            if "pixelHeight:" in line:
                height = int(line.split(":")[1])
        return width, height
    except Exception:
        return 32, 32


def convert(name, source, into, verbose=True):
    """One pet to one .nekochar. Returns its manifest, or None if it was refused."""
    manifest = json.loads(read(source, "pets/%s/pet.json" % name))
    author = (manifest.get("author") or "").strip()

    if name in ALREADY_OURS:
        print("  skipped %-14s Neko already ships these sprites" % name)
        return None
    if author.lower() != OURS_TO_GIVE:
        print("  REFUSED %-14s its own manifest credits “%s”, which the MIT licence"
              " on that repository does not cover" % (name, author))
        return None

    animations = manifest.get("animations", {})
    sprites_dir = manifest.get("spritesDir", "sprites")

    # Fetched before anything is written, because a state whose sprites are not
    # in the repository is a state this cannot have.
    have, missing = {}, 0
    for one in animations.values():
        for frame in one.get("files") or []:
            if frame in have:
                continue
            body = read_or_none(source, "pets/%s/%s/%s" % (name, sprites_dir, frame))
            if body is None:
                missing += 1
            else:
                have[frame] = body

    states, wanted = {}, []
    for state, theirs in STATES.items():
        for one in theirs:
            frames = [f for f in (animations.get(one, {}).get("files") or [])
                      if f in have]
            if not frames:
                continue
            states[state] = {
                "Frames": frames,
                "TicksPerFrame": ticks_for(animations[one].get("fps")),
            }
            wanted.extend(frames)
            break

    if "stop" not in states:
        print("  REFUSED %-14s no idle pose it has the sprites for (%d file(s) its "
              "manifest names are not in the repository)" % (name, missing))
        return None

    folder = os.path.join(into, "%s.nekochar" % manifest["name"])
    os.makedirs(folder, exist_ok=True)
    for one in sorted(set(wanted)):
        with open(os.path.join(folder, one), "wb") as f:
            f.write(have[one])

    width, height = sprite_size(os.path.join(folder, states["stop"]["Frames"][0]))
    out = {
        "Identifier": name.replace("-", ""),
        "Name": manifest["name"],
        "Author": author,
        "License": "MIT, from github.com/%s" % REPO,
        # Their `personality` is a paragraph and their `description` is a line.
        # Neko's Persona is read into a prompt beside a dozen other things, and
        # the budget is why the shorter one wins.
        "Persona": (manifest.get("description") or manifest["name"]).strip(),
        "SpriteWidth": width,
        "SpriteHeight": height,
        "States": states,
    }
    with open(os.path.join(folder, "character.plist"), "wb") as f:
        plistlib.dump(out, f, sort_keys=True)

    if verbose:
        note = ", %d sprite(s) it names are missing upstream" % missing if missing else ""
        print("  took    %-14s %s, %d of 18 states, %dx%d, by %s%s"
              % (name, manifest["name"], len(states), width, height, author, note))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--from", dest="source", help="a NekoAI checkout to read instead")
    ap.add_argument("--into", default="examples/NekoAI characters.nekoplugin")
    ap.add_argument("--list", action="store_true",
                    help="say what would be taken and refused, and write nothing")
    args = ap.parse_args()

    names = pet_names(args.source)
    print("%d pets in %s\n" % (len(names), REPO))

    if args.list:
        for name in names:
            manifest = json.loads(read(args.source, "pets/%s/pet.json" % name))
            author = (manifest.get("author") or "").strip()
            if name in ALREADY_OURS:
                verdict = "already ours"
            elif author.lower() != OURS_TO_GIVE:
                verdict = "REFUSED — credits “%s”" % author
            else:
                verdict = "would take"
            print("  %-14s %-13s %s" % (name, verdict, manifest.get("name", "")))
        return 0

    staging = tempfile.mkdtemp(prefix="nekoai-")
    taken = [c for c in (convert(n, args.source, staging) for n in names) if c]
    if not taken:
        print("\nnothing to write")
        shutil.rmtree(staging, ignore_errors=True)
        return 1

    into = args.into
    if os.path.exists(into):
        shutil.rmtree(into)
    os.makedirs(into)
    for one in os.listdir(staging):
        shutil.move(os.path.join(staging, one), os.path.join(into, one))
    shutil.rmtree(staging, ignore_errors=True)

    plugin = {
        "Identifier": "com.example.nekoaicharacters",
        "Name": "NekoAI characters",
        "Version": "1.0",
        "Interface": 1,
        "MinimumApp": "2.5",
        "Author": "sprites by the NekoAI community, converted",
        "License": "MIT — see README.md",
        "Summary": "%s from nucket/NekoAI, converted to Neko's own eighteen states. "
                   "Sprites only: a character cannot ask for anything, reach anything "
                   "or do anything." % ", ".join(c["Name"] for c in taken),
        "Wants": [],
        "Extends": {"Characters": ["%s.nekochar" % c["Name"] for c in taken]},
    }
    with open(os.path.join(into, "plugin.plist"), "wb") as f:
        plistlib.dump(plugin, f, sort_keys=True)

    with open(os.path.join(into, "README.md"), "w") as f:
        f.write(README % (
            REPO,
            "\n".join("- **%s** — %s, by %s" % (c["Name"], c["Persona"], c["Author"])
                      for c in taken),
            REPO))

    print("\nwrote %s — %d characters" % (into, len(taken)))
    print("try it with Plugins… → Add…, and it arrives switched off")
    return 0


README = """# NekoAI characters

Sprites from [nucket/NekoAI](https://github.com/%s), converted to Neko's own
eighteen states by `tools/import-nekoai.py`.

%s

## Where these came from, and what is not here

NekoAI is the modern rebuild of the same idea this application is, and its pets
are laid out close enough to this one's states that converting them is mechanical.
Its repository is under the MIT licence, which covers what its author holds the
rights to — and its own per-pet manifests say who that is.

Two of its pets name somebody else:

    pac-man      author: "Namco / Neko98 community"
    tie-fighter  author: "Lucasfilm / Neko98 community"

Those are not in here and the converter refuses them by rule rather than by a note
in a comment. Three more are missing because Neko has had them all along, from the
same oneko family: the classic Neko, Tabby, and the BSD daemon.

## What a character can do

Nothing. A character is sprites and a line of description; it cannot ask for
anything, fetch anything, reach the network, or do anything at all. That is why
this can be a folder somebody drops in.

## Licence

MIT, from the upstream repository. The full text and the copyright notice are at
https://github.com/%s/blob/HEAD/LICENSE — keep them with these files if you pass
them on.
"""

if __name__ == "__main__":
    sys.exit(main())
