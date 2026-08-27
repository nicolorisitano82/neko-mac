# Plugins: the interface

A design for the next version. It answers one question — *what can somebody else
add to this app without being able to break it* — and it answers it in terms of
the code that exists today rather than in the abstract. The companion document,
[plugins-management.md](plugins-management.md), covers installing, enabling,
disabling and removing them.

[plugin-guide.md](plugin-guide.md) is the practical companion to this document:
the folder, the manifest key by key, every refusal and the sentence the panel
shows for it, and a worked example of the executable protocol in Swift.

## 0. The precedent, and why it decides the shape

This app already has plugins. A character is a folder with a manifest and some
images:

```
Ace.nekochar/
  character.plist     Identifier, Name, Author, License, SpriteWidth, States…
  awake.png  down1.png  down2.png  …
```

Forty-three of them ship, several were added by dropping in a folder, and not one
of them can crash the app, read a file, reach the network or do anything the app
would not otherwise do. That is the standard the rest has to meet.

The alternative — a plugin as loadable code — is worse here than it is in most
apps, for two specific reasons:

1. **The sandbox is the product.** The app holds the microphone, the location, a
   folder or two the user handed over by name, and a diary about their working
   life. Code loaded in-process inherits all of it. There is no way to give a
   dylib "only the feeds" once it is inside the process.
2. **Signing.** A sandboxed app cannot load libraries that are not signed
   compatibly, and turning that off (`disable-library-validation`) is exactly the
   entitlement that would make the sandbox decorative. The entitlements today are
   five lines and every one of them is defensible; this would be the sixth and it
   would not be.

So: **plugins are data, or they are separate processes.** Nothing is ever loaded
into this app.

## 1. Three kinds, in order of how much they can do

| kind | is | can do | risk |
| --- | --- | --- | --- |
| **Declarative** | a manifest and some files | add feeds, characters, phrasebooks, prompt fragments, question routes, action verbs that map to a URL scheme or a Shortcut | none that the app does not already take |
| **Shortcut-backed** | a manifest naming one of the user's Shortcuts | answer questions, perform an action | whatever that Shortcut can do, which the user wrote |
| **Executable** | a manifest and a program | anything it can compute from what it is handed | its own; runs as a child process with none of this app's entitlements |

Most plugins should be declarative. The executable kind exists because
`neko-paint` already proves it works — a separate binary, spoken to over a pipe,
doing one job — and because "add a feed" is not the interesting half of what
people will want.

## 2. What a plugin looks like

```
Ansa Sport.nekoplugin/
  plugin.plist
  feeds.plist            (declared by the manifest, optional)
  answer                 (an executable, only if the manifest says so)
  README.md
```

`plugin.plist`, in full:

```
Identifier        "com.example.ansasport"     unique, reverse-DNS, never changes
Name              "ANSA Sport"                shown in the list
Version           "1.2"
Author            "Somebody"
License           "MIT"
Interface         2                            which version of this document
MinimumApp        "2.3"
Summary           "Adds the sport wire and two questions about it."

Extends           { … see section 3 … }
Wants             ( network, shortcut )        what it needs, declared up front
```

Rules that hold for every plugin, of every kind:

- **The manifest is the contract.** A plugin that did not declare `Extends.Feeds`
  cannot add a feed, whatever its files contain. The app reads the manifest,
  decides what this plugin is allowed to be asked, and never consults it for
  anything else.
- **`Wants` is the whole of its power.** Empty means it is pure data. `network`
  means its feeds may be fetched. `shortcut` means it may name a Shortcut of the
  user's. `executable` means it ships a program. There is no `files`, no
  `microphone`, no `location`: those belong to the app and are not delegable.
- **Anything a plugin produces is data, never instructions.** This is the same
  invariant the web feature has, tested in `tests/screen.m`: text that came from
  somewhere else can inform what the cat says and can never authorise anything.
  A plugin's output is quoted into a prompt with that framing, and an answer built
  on it may not open, copy or move anything.
- **It cannot raise a limit.** Not the day's remark budget, not the interval, not
  the memory block's thousand characters, not the sixteen-second listening window.
  A plugin can be quieter than the app; never louder.

## 3. What can be extended: Ask Neko, part by part

Asking is a pipeline, and every stage is a place somebody might reasonably want to
change. Named here as they are named in the code, because that is what makes this
a design rather than a wish.

```
invocation → capture → routing → instructions → engine → markers
          → filtering → presentation → memory → timing
```

### 3.1 Invocation — `NekoHotKey`, `NekoWakeWord`, the menu

*Declarative.* `Extends.Invocations` adds a named entry point: a menu item, and
(later) an App Intent so Shortcuts and the Action button can reach it. Each
invocation names what it starts: a plain question, a specific route (3.3), or a
plugin command.

Not extensible: the wake word itself. One always-listening microphone is a
decision the app makes once, and a plugin that could add a second word could keep
the microphone open for its own reasons.

### 3.2 Capture — `NekoListener`, `NekoLine`

Not extensible, deliberately. Speech and the typed line are the two ways in, and
both touch the microphone or the keyboard. A plugin that wanted to supply text
should be a route (3.3) instead.

### 3.3 Routing — the part the web feature invented

`NekoWeb wantedFor:` decides in code, before any engine is consulted, whether a
question is about the news or the weather. That mechanism exists because the
measured alternative was a model inventing headlines. It generalises exactly:

```
Extends.Routes = (
  { Match = { Words = ("borsa", "titoli", "mercato"); Language = "it"; };
    Do = { Feed = "com.example.markets/prices"; };
    Verbatim = true; },
  { Match = { Words = ("traduci", "translate"); };
    Do = { Command = "translate"; };
    Answer = "through-model"; }
)
```

A route claims a question by matching words in it. What it may then do:

- **`Feed`** — fetch one of its own declared feeds (needs `network`), and either
  show the lines verbatim or hand them to the engine as quoted context.
- **`Shortcut`** — run a named Shortcut and use its output the same way.
- **`Command`** — run its executable with the question on stdin (needs
  `executable`).

Conflicts are resolved by specificity then by order in the plugin list, and a
route can never claim a question the app's own routes claim: the built-in ones
win, and the Plugins tab says so.

### 3.4 Instructions — `NekoAnswerProvider`

*Declarative, and bounded.* `Extends.Instructions` contributes a fragment to the
prompt: a rule, a preference, a piece of domain knowledge. Two limits, both
learned the hard way in 2.2: a fragment is **at most 240 characters**, and the
total of all plugin fragments is **at most 600**. The measured reason is in the
changelog — a long prompt is how a 3B model starts answering `ACTION: cannot` to
"should I take a break?" — and a plugin cannot be allowed to spend that budget on
the app's behalf.

Fragments go in one labelled block, after the app's own instructions and before
the persona reminder that closes every prompt. They cannot contain a marker
(`ACTION:`, `IMAGE:`, `LOOK:`) and are refused at install time if they do.

### 3.5 Engines — `NekoAnswerProvider`, `NekoBrains`

`Extends.Engines` adds an answerer. Three forms: a Shortcut, an executable, or an
HTTP endpoint (`network`). Each declares one thing that matters more than the
rest:

```
Engine = { Identifier = "com.example.llm"; Kind = "http";
           StaysOnThisMac = false; }
```

`StaysOnThisMac` is not a hint. `NekoBrains staysOnThisMac:` is what decides
whether the diary is offered to an engine, and it is tested for every provider in
`tests/brains.m`. A plugin engine that claims to be local and is not would be the
one lie in this design that matters, so: the claim is only believed for the
`executable` kind with no `network` in `Wants`. Everything else is remote by
definition, whatever it says.

An added engine can be chosen for questions. It is never eligible to speak
unprompted — that stays with `bestOnDeviceProvider`, for the same reason it does
today.

### 3.6 Markers and verbs — `NekoAction`

The verb list is closed on purpose: six verbs, each one read back to the user and
waiting for a yes. `Extends.Verbs` adds to it, and the price of admission is the
same as the existing six:

```
Verb = { Name = "play"; Summary = "Play %@ in Music"; Kind = "shortcut";
         Shortcut = "Play album"; Confirms = true; }
```

`Confirms` cannot be false. A plugin verb goes through `propose:` like everything
else: shown in the bubble, performed on a yes, and a dismissed bubble is a no.
Verbs that would touch files are not available to plugins at all — file work goes
through the folders the user handed over by name, and those were handed to the
app.

### 3.7 Filtering — `NekoSense`, `NekoVoice`

*Declarative.* `Extends.Refusals` adds patterns that make a line not worth saying:
a house style, a word somebody never wants to hear, a language rule. Plugins may
only ever **add** refusals. There is no way to remove one — a plugin that could
switch off the spelling gate, the flattery trim or the feeling-claim rule would be
able to undo the parts of 2.1 and 2.2 that took the longest to get right.

### 3.8 Presentation — `NekoBubble`

*Declarative and small.* A route may ask for one of the shapes the bubble already
knows: a sentence, a list, a picture from a file it produced, a picture with a
caption. No plugin draws. The bubble is the one piece of this app that has to keep
working while a model is wrong, and a plugin with a view in it would be a plugin
that can cover the screen.

### 3.9 Memory — `NekoMemory`

Read: never. A plugin cannot see the diary, and there is no `Wants` value that
grants it. This is the flat rule that makes the diary defensible at all.

Write: `Extends.Notes` lets a route contribute one line to the day, marked with
the plugin's identifier, which the nightly reflection then treats like any other
note. A plugin can therefore help the cat remember that you ship on Fridays. It
cannot ask what else you do.

### 3.10 Timing — `NekoRate`, `NekoDesktop`

Not extensible in the direction anybody would want. A plugin cannot make the cat
speak more often, cannot lower the seam requirement, and cannot ask for the
budget. It *can* declare `Quieter = true`, which halves its own routes' share of
the day. The asymmetry is the design: 2.1 spent a release establishing when this
app is allowed to interrupt, and that is not somebody else's setting.

## 4. The executable protocol

One line in, one line out, over stdin and stdout, UTF-8, newline-terminated JSON.
Nothing else — no sockets, no shared files, no arguments carrying secrets.

```
→ {"v":2,"call":"answer","question":"quanto fa sette per otto","locale":"it"}
← {"v":2,"say":"Cinquantasei."}

→ {"v":2,"call":"route","question":"che borsa fa oggi","locale":"it"}
← {"v":2,"lines":["FTSE MIB +0,4%","Spread 118"],"verbatim":true}

← {"v":2,"error":"no network"}
```

The envelope the app guarantees, and enforces:

- **Eight seconds**, then the process is killed and the plugin is told to have
  timed out. Twice in a session and it is disabled until relaunch, with the reason
  in the Plugins tab.
- **No entitlements.** It is a child process of a sandboxed app: no microphone, no
  location, no Downloads, and the network only if `Wants` said so — which the app
  can only enforce by not being the one to open it, so a plugin that wants the
  network is a plugin the user is told about in those words.
- **64 KB of output**, then it is cut off. A plugin cannot fill the diary or the
  prompt by being verbose.
- **Nothing about the person is sent.** The question, the locale, and whatever the
  route matched. Not the diary, not the front application, not the window titles,
  not the location. If a plugin needs a town it asks for it in the question.

## 5. What a plugin can never do

Collected in one place, because a design like this is judged by this list rather
than by the other four sections.

1. Run inside this app.
2. See the diary, the screen text, the window titles, the front application, or
   the location.
3. Reach the microphone, the camera, or the user's files.
4. Perform anything without the confirmation the app shows and waits for.
5. Remove a refusal, raise a limit, widen the day's budget, or shorten the
   interval.
6. Speak unprompted.
7. Turn its own output into an action — its lines are quoted as somebody else's
   words, exactly like a headline.

## 6. What this buys, concretely

The three plugins worth writing first, as a test of whether the design is real:

- **A wire nobody shipped.** Feeds, a route, a phrasebook. Pure data, no `Wants`
  beyond `network`, ten minutes to write.
- **A translator.** A route that claims "traduci …", an executable that shells out
  to whatever the author likes, and the answer read back in the cat's voice. Tests
  the executable protocol and the timeout.
- **A house style.** Instructions and refusals only: a team that wants the cat to
  use their vocabulary and never their competitor's. Tests the fragment budget and
  the refusal-only rule.

## 7. Testing a plugin, and testing the system

The suite in [tests/](../tests) is how everything else in this app is defended,
and plugins do not get an exemption:

- `tests/plugin.m` — the manifest reader: a good manifest, a manifest claiming
  something it did not declare, a fragment over budget, a fragment containing a
  marker, an interface version from the future, a verb with `Confirms = false`.
  Each one refused, with the reason.
- `tests/plugin-protocol.m` — a fixture plugin in `examples/`, driven end to end:
  a normal answer, a timeout, 64 KB of output, malformed JSON, a crash. The app
  survives all five and says which happened.
- `tests/screen.m` gains one case: a plugin's output containing
  `ACTION: open-app Terminal` reaches the bubble as text and nothing else — the
  same test the web feature already has, with a plugin as the source.

## 8. Open questions

1. **Is the executable kind worth it at all?** Everything in section 6 except the
   translator is declarative. If the first ten plugins anybody writes are data,
   the protocol is a liability with a timeout.
2. ~~**How does a plugin ship a character?**~~ **Answered: it does.** The manifest
   names `.nekochar` folders inside the plugin, one by one, and they join the menu
   when it is switched on. A plugin can add a character and never replace one: an
   identifier the app already ships is not reachable. Dropping a folder next to
   the app's resources still works and is still fine for one's own machine — a
   plugin is how you give one to somebody else, with a name, a version and a
   switch.
3. **Signing and trust.** An executable plugin from the internet is the same
   problem as any other download, and this app is itself unsigned. Section 4 of
   [plugins-management.md](plugins-management.md) is the honest answer, and it is
   not a comfortable one.
4. ~~**Localisation.**~~ **Answered: inside the plugin.** A plugin carries
   `<lang>.lproj/plugin.strings`, keyed on the English strings in its own
   manifest, and the app looks there first, then in its own tables, then gives
   back the string as written. English-only is allowed and says English things —
   the app does not refuse a plugin for the languages it lacks. It does refuse a
   language folder whose strings file cannot be read, because a silent fallback
   would leave the author believing it worked.
