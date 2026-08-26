# The measurements

Every claim in [docs/truelife-roadmap.md](../docs/truelife-roadmap.md) came from
one of these. They are here so that the claims can be checked again — by somebody
else, or by me next month — rather than taken on the word of a commit message.

```sh
./build.sh          # they run against the built app
tests/run.sh        # all of them
tests/run.sh rate   # one of them
tests/run.sh --slow # including the ones that take minutes
```

Each harness is built as a second executable **inside `build/Neko.app`**. That is
not tidiness: several of them measure Italian strings and Italian layouts, and a
binary outside the bundle silently gets English and passes. `run.sh` removes it
again afterwards.

| harness | what it measures |
| --- | --- |
| `brains.m` | which engine may speak unasked, and which engines the diary is refused to |
| `desktop.m` | the four seams in somebody's work, and how long a seam lasts |
| `memory.m` | the diary: written, capped, deletable |
| `beat.m` | the moment of listening after it speaks, barge-in, the typed line, the previous turn |
| `rate.m` | how often it speaks: five staged days against the rule this replaced |
| `screen.m` | that nothing read from a screen can become something the Mac does |
| `layout.m` | every pair of controls in every tab, and every paragraph against the space it was given |
| `line.m` | that the typed line takes the keyboard and gives it back — its own bundle |
| `place.m` | the order the two location questions have to be asked in |
| `hear.m` | that the cat reacts to a sentence starting, not to it ending |
| `noise.m` | that its timing drifts rather than scattering — spectrum, memory, spread |
| `turn.m` | that it steps toward what it is attending to, and only a step |
| `beside.m` | that it stops an arm's length short, and off the line it walked in on |
| `persona.m` | that the character survives the longest prompt the app can build |

## Two things about writing more of these

**Settings arrive as arguments.** `run.sh` passes `-NekoAskEnabled 1` and the
rest, which NSUserDefaults reads before anything saved, so a test says what it
needs without touching what the user chose. The other side of that: a test
**cannot** change a setting the runner passed — the argument wins over
`setObject:forKey:` — which is why `brains.m` asks the engines directly rather
than through the setting.

**A test that skips must say so.** `notMeasured()` prints a line; a test that
quietly does nothing reads exactly like a test that passed. Three things are
printed rather than measured, and each says why: Focus and Do Not Disturb (no
public API, and the file is unreadable), the microphone itself (TCC kills an
auxiliary binary inside a bundle the moment it asks for anything private), and
the nightly reflection (it needs yesterday's file and a model; measured in the
roadmap instead).

## One trap worth knowing

AppKit drains the autorelease pool while the run loop turns, and `spin()` turns
it. Anything a test holds *across* a spin — an array it is iterating, a string it
will print at the end — has to be retained rather than autoreleased. A harness
that got this wrong iterated a deallocated array for twenty-four rounds and
crashed on the twenty-fifth, which is exactly as confusing as it sounds. Run a
suspect harness with `NSZombieEnabled=YES` and it says so in one line.

## If every compiler call refuses

`You have not agreed to the Xcode license agreements` means `xcode-select` is
pointing at a full Xcode install whose licence nobody has accepted, and it stops
`clang`, `swiftc` and `xcrun` alike — the build fails and every harness fails with
it. Either accept it once with `sudo xcodebuild -license accept`, or build against
the Command Line Tools, which need no licence and are what this project has always
used:

```sh
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
```

## What they cannot do

Nothing here proves a route does not exist — only that it was not taken this
once. `screen.m` is the one place that tries anyway, by reading the source: if
`NekoAction` ever asks the desktop for text, or the advisor ever reaches
`NekoAction`, it fails. That is a weaker test than a proof and a stronger one
than a comment.
