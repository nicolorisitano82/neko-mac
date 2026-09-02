#!/usr/bin/env python3
"""Reads Neko's diary and says what is actually in it.

    tools/diary.py                  # the diary on this Mac
    tools/diary.py --dir PATH       # somewhere else
    tools/diary.py --lines          # print the durable lines too

Written because a week of it went unexamined and produced a fault nobody could
see from inside the application: the cat's own remarks are written to the diary
by `noteSaid`, the nightly reflection reads the day back, and on a day where the
cat spoke and nobody else did, the reflection has nothing to work from but the
cat. What comes out becomes a durable line, and durable lines go into every
prompt — so the next remark is made from the last one.

Measured on this Mac the loop is visible to the eye: `test zqqmark` on the 26th,
`test barge` on the 27th, `test boat` on the 28th, `test chiatta` on the 29th.
The same non-fact, degrading, in three languages, restated in `durable.txt` every
day for six days.

So this counts four things, and each one is a lever:

  1. **How much of the diary is the cat talking to itself** — `sed` lines against
     `saw` and `you`. A day that is all `sed` is a day with nothing to reflect on.
  2. **How much of it is repetition** — near-identical lines, which is what an
     advisor with no memory of what it just said produces.
  3. **How much of every prompt the durable lines eat**, and how much of that is
     the same fact worded differently.
  4. **How many durable lines are traceable** to something the person said or the
     Mac noticed, rather than to the cat's own voice. An untraceable durable line
     is either invented or self-derived, and both are worse than an empty file.

It reads and prints; it changes nothing. What to do about the numbers is at the
bottom of the output.
"""

import argparse, os, re, sys
from collections import Counter, defaultdict

STOP = set("""
essere avere fare stare dire dopo prima ancora molto tanto poco quando perche
perché quello questa questo quella come cosa dove ogni tutto tutta tutti tutte
sono stato stata state stati anche solo altro altra oltre verso senza sopra
sotto della dello delle degli nella nello nelle negli alla allo alle agli
oggi ieri domani mattina sera notte giorno giorni volta volte
that this with have from what when where which been were will would
their there here just some more than then only about into over
""".split())

KINDS = ("saw", "sed", "you")


def words(text):
    out = set()
    for word in re.findall(r"[^\W\d_]+", text.lower(), re.UNICODE):
        if len(word) >= 4 and word not in STOP:
            out.add(word)
    return out


def close(a, b, floor=0.6):
    """Two lines saying the same thing, roughly. Jaccard over content words: no
    dependencies, and generous enough to catch a translation of itself."""
    if not a or not b:
        return False
    return len(a & b) / float(len(a | b)) >= floor


def collapse(lines):
    """Groups of lines that say the same thing. Returns the groups, largest
    first."""
    sets = [words(l) for l in lines]
    groups, taken = [], set()
    for i in range(len(lines)):
        if i in taken:
            continue
        group = [i]
        taken.add(i)
        for j in range(i + 1, len(lines)):
            if j not in taken and close(sets[i], sets[j]):
                group.append(j)
                taken.add(j)
        groups.append(group)
    groups.sort(key=len, reverse=True)
    return groups


def read_day(path):
    out = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            parts = line.split("\t")
            if len(parts) >= 3:
                out.append((parts[0], parts[1], "\t".join(parts[2:])))
            else:
                out.append(("", "?", line))
    return out


def read_durable(path):
    """day, the times it was distilled from, and the lesson.

    Three fields since the citation was added: a durable line that could not
    point at a note in its own day is now refused before it is written, so the
    times here are a fact rather than an inference. Two fields means a line from
    before that, and those are counted separately."""
    out = []
    if not os.path.exists(path):
        return out
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            parts = line.split("\t")
            if len(parts) >= 3:
                out.append((parts[0], parts[1], "\t".join(parts[2:])))
            elif len(parts) == 2:
                out.append((parts[0], "", parts[1]))
            else:
                out.append(("", "", line))
    return out


def main():
    home = os.path.expanduser("~/Library/Application Support/Neko/Memory")
    ap = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dir", default=home)
    ap.add_argument("--lines", action="store_true",
                    help="print the durable lines and what they trace to")
    args = ap.parse_args()

    if not os.path.isdir(args.dir):
        print("no diary at %s" % args.dir)
        return 1

    days = sorted(n for n in os.listdir(args.dir) if re.match(r"\d{4}-\d\d-\d\d\.txt$", n))
    if not days:
        print("no day files in %s" % args.dir)
        return 1

    print("\n%s\n%d day file(s)\n" % (args.dir, len(days)))

    print("--- what is in each day, by who said it ---\n")
    print("  %-12s %5s %5s %5s %5s   %s" % ("day", "saw", "sed", "you", "all", "repeats"))
    totals = Counter()
    said_by_day = {}
    heard_by_day = {}
    for name in days:
        rows = read_day(os.path.join(args.dir, name))
        kinds = Counter(kind for _, kind, _ in rows)
        for kind in KINDS:
            totals[kind] += kinds[kind]
        said = [text for _, kind, text in rows if kind == "sed"]
        said_by_day[name[:-4]] = said
        heard_by_day[name[:-4]] = [text for _, kind, text in rows
                                   if kind in ("saw", "you")]
        groups = collapse(said)
        biggest = len(groups[0]) if groups else 0
        print("  %-12s %5d %5d %5d %5d   %s" % (
            name[:-4], kinds["saw"], kinds["sed"], kinds["you"], len(rows),
            ("%d lines saying one thing" % biggest) if biggest > 1 else "—"))

    everything = sum(totals[k] for k in KINDS) or 1
    print("\n  of %d lines: %d%% the cat talking (sed), %d%% noticed (saw), "
          "%d%% said to it (you)" % (
        everything, 100 * totals["sed"] // everything,
        100 * totals["saw"] // everything, 100 * totals["you"] // everything))

    all_sed = [t for day in said_by_day.values() for t in day]
    groups = collapse(all_sed)
    distinct = len(groups)
    if all_sed:
        print("  and of %d remarks, %d distinct things — %d%% of what it said, "
              "it had said before" % (len(all_sed), distinct,
              100 * (len(all_sed) - distinct) // len(all_sed)))
        print("\n  the five it repeated most:")
        for group in groups[:5]:
            if len(group) < 2:
                break
            print("    %3d ×  %s" % (len(group), all_sed[group[0]][:88]))

    print("\n--- the durable lines, which go into every single prompt ---\n")
    durable = read_durable(os.path.join(args.dir, "durable.txt"))
    standing = read_durable(os.path.join(args.dir, "standing.txt"))
    if not durable and not standing:
        print("  none")
    body = "\n".join(text for _, _, text in durable + standing)
    print("  %d dated, %d standing, %d characters of every prompt"
          % (len(durable), len(standing), len(body)))

    facts = [text for _, _, text in durable + standing]
    factGroups = collapse(facts)
    if facts:
        print("  %d lines, %d distinct facts — the prompt spends %d%% of that "
              "budget restating itself" % (len(facts), len(factGroups),
              100 * (len(facts) - len(factGroups)) // len(facts)))

    # Traceable: does the line share a word of substance with something the
    # person said or the Mac noticed, on the day it was drawn from?
    print("\n--- and where each durable line came from ---\n")
    heardWords = defaultdict(set)
    saidWords = defaultdict(set)
    for day, lines in heard_by_day.items():
        for line in lines:
            heardWords[day] |= words(line)
    for day, lines in said_by_day.items():
        for line in lines:
            saidWords[day] |= words(line)

    fromPerson = fromItself = fromNowhere = 0
    cited = 0
    for day, times, text in durable:
        if times:
            # Said rather than guessed: the line names the notes it came from,
            # and those were checked against the day before it was written.
            cited += 1
            where = "cited: " + times
        else:
            mine = words(text)
            theirs = heardWords.get(day, set())
            own = saidWords.get(day, set())
            where = ("the person or the Mac" if mine & theirs
                     else "its own remarks" if mine & own
                     else "nowhere in that day")
        if times or words(text) & heardWords.get(day, set()):
            fromPerson += 1
        elif words(text) & saidWords.get(day, set()):
            fromItself += 1
        else:
            fromNowhere += 1
        if args.lines:
            print("  %-12s %-24s %s" % (day, where, text[:66]))
    if not args.lines and durable:
        print("  (use --lines to see them one by one)")
    if durable:
        print("\n  %d of %d name the notes they came from" % (cited, len(durable)))
        print("  %d traceable to the person or the Mac, %d to the cat's own "
              "remarks, %d to nothing in that day"
              % (fromPerson, fromItself, fromNowhere))

    print("\n--- what the numbers mean ---\n")
    complaints = []
    if everything and totals["sed"] * 2 > everything:
        complaints.append(
            "More than half the diary is the cat's own voice. A day whose lines\n"
            "     are all `sed` has nothing to reflect on, and the reflection is\n"
            "     being asked to find a durable fact in a monologue.")
    if all_sed and distinct * 3 < len(all_sed):
        complaints.append(
            "It says the same thing over and over. Nothing compares a remark\n"
            "     against what was said an hour ago, so the diary fills with one\n"
            "     observation written thirty ways.")
    if facts and len(factGroups) * 2 <= len(facts):
        complaints.append(
            "Half the durable lines or more are the same fact worded twice. That\n"
            "     is prompt budget spent on nothing, every question, all month.")
    if fromItself + fromNowhere > fromPerson:
        complaints.append(
            "Most durable lines trace to the cat rather than to the person. That\n"
            "     is the loop: what it said becomes what it knows, becomes what it\n"
            "     says. `test zqqmark` → `test barge` → `test boat` → `test chiatta`\n"
            "     is one non-fact degrading over four days of this.")
    if not complaints:
        print("  Nothing above the line. The diary is mostly things somebody said\n"
              "  or the Mac noticed, it does not repeat itself, and the durable\n"
              "  lines are distinct and traceable.")
    for i, one in enumerate(complaints, 1):
        print("  %d.  %s\n" % (i, one))
    print("  Nothing here was changed. The diary is plain text: a line you\n"
          "  disagree with can be deleted with any editor.\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
