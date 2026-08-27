# Plugins: adding, enabling, disabling, removing

The other half of [plugins.md](plugins.md). That document says what a plugin may
be; this one says how one arrives, how it is switched on and off, how it goes
away, and what the app does when one misbehaves.

The rule underneath all of it: **nothing a plugin can do is a surprise.** It is
declared in a manifest, shown in a panel before it is switched on, visible in a
list afterwards, and undoable in one click.

[plugin-guide.md](plugin-guide.md) is what to read if you are writing one rather
than deciding what they may be.

## 1. Where they live

```
~/Library/Containers/com.yourcompany.neko/Data/Library/
    Application Support/Neko/
        Memory/                       the diary, since 2.1
        Models/                       the GGUF files
        Plugins/                      new
            com.example.markets.nekoplugin/
            com.example.translate.nekoplugin/
```

Inside the container, not in the open home folder, because the app is sandboxed
and that is where it can actually read. That has one consequence worth stating
plainly: **a plugin cannot be installed by dragging it into a folder in the
Finder**, the way a character can be dropped next to the app's resources. The
sandbox is what makes the rest of this app defensible, and this is what it costs.

So installation is a panel, and the panel is the same mechanism the folder access
already uses: `NSOpenPanel`, the user chooses, the app copies the folder into the
container and holds nothing else.

## 2. Adding one

A window of its own — **Plugins…** in the menu, not a tab in the preferences.
Plugins are not settings: the preferences are things about how the cat behaves,
and a plugin is a thing somebody installed. The window also has to say more than a
tab has room for, and the paragraph about what none of them can reach belongs
where somebody is deciding whether to trust a folder they downloaded.

What happens between choosing a folder and having a plugin:

1. **It is read, not run.** The manifest is parsed; anything unreadable stops here
   with the reason on screen. No file inside the plugin is opened yet, and nothing
   is executed.
2. **It is checked against the interface.** `Interface` newer than the app knows
   about, `MinimumApp` above this version, a duplicate identifier, a fragment over
   budget, a fragment containing a marker, a verb with `Confirms = false`, a route
   in a language the app does not serve: each one refused, each one with the
   sentence that says which.
3. **It is described back.** Not "com.example.markets wants permissions" — the
   panel says what it will be able to do, in the words the rest of this app uses:

   > **ANSA Sport** by Somebody, version 1.2
   >
   > Adds two news feeds and one question route ("borsa", "titoli", "mercato").
   > Contributes 180 characters of instructions.
   >
   > It will be able to **fetch its two feeds over the network**. It ships **no
   > program**. It cannot see your diary, your screen, your files, your microphone
   > or where you are, and it cannot make the cat speak on its own.

   For an executable plugin the third paragraph is blunter, and it is the one the
   user has to read:

   > It ships a **program**, which will run as a child of Neko when one of its
   > routes matches. Neko cannot limit what that program does with your network or
   > your own files — only what it is told and what it is asked. Do not enable
   > this unless you trust where it came from.

4. **It is copied in, disabled.** Arriving is not the same as being on. The row
   appears in the list with its switch off.

## 3. Enabling and disabling

One switch per row, and the switch is the whole of it:

- **Enabled** identifiers live in one array in the defaults,
  `NekoPluginsEnabled`. A plugin not in that array is never read, never asked,
  never run. Disabling is not a flag the plugin can see; it is the app not
  consulting it.
- **Enabling** re-validates first. A plugin that was fine in 2.3 and claims
  `Interface 3` after an update is refused at the switch, with the reason, rather
  than half-working.
- **Disabling is instant and total.** Routes stop matching, instructions stop
  being contributed, an engine stops being offered, a running child process is
  killed. Nothing needs a relaunch, which is deliberate: a plugin somebody wants
  to switch off is usually a plugin doing something they dislike right now.
- **The list says what each one is doing**, not what it claims: "2 feeds, 1 route,
  180 characters of instructions", and, when it has been asked something,
  "answered 3 times today, 1 timeout".

## 4. Trust, and the part that is uncomfortable

An executable plugin is a program from the internet, and this app is itself
unsigned and asks people to right-click to open it. Pretending there is a clean
answer would be worse than saying what there is:

- **Declarative plugins need no trust decision.** They are a plist and some feed
  addresses. The app fetches feeds it already fetches, and nothing runs.
- **Shortcut-backed plugins inherit the user's own trust.** The Shortcut is theirs;
  they wrote it or they installed it. The app names which Shortcut, every time.
- **Executable plugins get a one-time confirmation with the paragraph in section
  2**, the author and the checksum recorded at install, and a check at every
  launch: if the program has changed since it was enabled, it is disabled and the
  user is told. That is not security against a determined author — it is
  protection against a plugin quietly becoming a different plugin.
- **No plugin store, no downloader, no auto-update.** The app has no business
  fetching code. A plugin arrives because somebody put it there.

What the sandbox still gives, and it is not nothing: a plugin's program runs as a
child of a sandboxed app, so it inherits the sandbox's restrictions on the
microphone, the camera and the user's Documents and Desktop. Measured in this
project before: an auxiliary binary inside this bundle is killed by TCC the moment
it asks for anything privacy-sensitive.

## 5. Removing one

**Remove** on the row, with a confirmation that names what goes:

> **Remove ANSA Sport?** Its folder, its two feeds, its route and anything it was
> told to remember about your day. Nothing else changes. This cannot be undone.

And then, in this order: kill anything of its running, drop it from
`NekoPluginsEnabled`, remove any diary lines it contributed (the same
`forgetLinesContaining:` the memory tab uses, matched on the plugin identifier the
notes carry), revoke any folder access granted for it, delete the folder.

A plugin that is removed leaves nothing behind but the sentence in the changelog
of somebody's own diary. That is the same standard the **Forget everything** button
already meets.

## 6. When one goes wrong

The discipline is the one the rest of the app uses: say what happened, in a
sentence, where the person can see it.

| what happens | what the app does |
| --- | --- |
| the program takes more than 8 seconds | killed; the route falls back to the app's own answer; the row shows "1 timeout" |
| twice in one session | disabled until relaunch, with the reason |
| malformed output | ignored; counted; the row says "malformed reply" |
| more than 64 KB | cut off at the limit; counted |
| a crash | counted; the app is unaffected, which is the point of a child process |
| a feed that never answers | the same as any other feed: the cat says it could not reach it |
| a fragment that turns out to break answers | the row's switch, and the whole thing is gone |

A plugin never fails silently and never fails loudly. It fails in one line in the
window and one sentence in the bubble.

## 7. The window

It should look like the Permissions tab rather than a marketplace: a scrolling
list of rows, one row per plugin, each with the name, the author, what it extends,
a state word, and two controls.

```
● ANSA Sport            Somebody · 1.2                    [switch]
  2 feeds, 1 route, 180 characters of instructions
  answered 3 times today                                  Reveal · Remove

○ Translate             Nobody · 0.9                      [switch]
  1 route, ships a program                                Reveal · Remove
  disabled: the program changed since you enabled it

  [ Add… ]  [ Show the folder ]

  Plugins live in Neko's own folder in Application Support. Nothing here runs
  inside Neko, and nothing here can see your diary, your screen, your files or
  where you are — or make the cat speak on its own.
```

The paragraph at the bottom is not decoration. It is the sentence somebody needs
when they are deciding whether to trust a folder they downloaded, and it belongs
where they are deciding.

## 8. What is built so far

The first slice, on the `2.5` branch:

- **`NekoPlugin`** — reads a manifest and refuses in sentences: no readable
  `plugin.plist`, an identifier that is not of the form `com.example.thing`, no
  name, no interface version, an interface from the future, a Neko version from
  the future, one of the app's own markers in its summary, feeds without asking
  for the network, an address that is not `https`, a feed word with a space in it,
  and — refused rather than ignored — extending something this version does not
  offer. A refused plugin still appears in the list with the reason.
- **`NekoPlugins`** — the folder inside the container, the enabled list, copying
  one in, removing it. Arriving is not the same as being on.
- **`NekoPluginsPanel`** — its own window, opened from the menu, with the
  paragraph about what none of them can reach at the bottom of it.
- **Feeds**, wired into the router that answers "che notizie ci sono". The app's
  own two dozen sources moved out of `NekoWeb.m` and into a plugin that ships
  inside the bundle, which is the honest test of the interface: if they could not
  be expressed as a plugin, it was not an interface yet. It is copied into the
  container at launch and switched on the first time it arrives — the one
  exception to *arriving is not the same as being on*, because a plugin shipped by
  the app is not a folder somebody downloaded, and the news would otherwise have
  stopped working on the day it moved. Switched off by hand, it stays off through
  every later launch and update.
- **Text in and out**, by running one of the user's own Shortcuts: the plugin
  names a Shortcut and never a program. What comes back may change words and
  nothing else — a marker anywhere in it and the whole transformation is thrown
  away — it never blocks the conversation, it sees the words and nothing around
  them, and the diary keeps what was actually said rather than the rewording.

Twenty-six checks in `tests/plugin.m`, the whole path included: it arrives
switched off, its feed is unreachable, switching it on makes the feed answer to
its word, switching it off removes it again, and removing the plugin leaves
nothing.

## 9. What to build next

**Pictures out.** Same shape as text: a plugin names a Shortcut, is handed a
description, and hands back an image — which the app shows with the same Save
button it already has, and which the plugin may never write to disk itself. It is
the next slice rather than this one because an image has two more things to settle
that text does not: what happens when it comes back enormous, and whether it
replaces the local painter or sits beside it.

**Then verbs and routes**, which is where the interface stops being about data.

Four steps, each shippable alone, in the order that keeps the app defensible at
every point:

1. **The manifest reader and the tab, declarative only.** Feeds, characters,
   phrasebooks, refusals. No routes, no engines, no programs. This is most of the
   value and none of the risk, and it is where `tests/plugin.m` gets written.
2. **Routes, feeds first.** The mechanism `NekoWeb wantedFor:` already is,
   generalised — and the existing twenty-four feeds become the first plugin,
   shipped inside the app, which is the honest way to prove the interface is
   enough.
3. **Instructions and refusals, with the budget enforced.** Small, and the place
   to be strictest: the measured history of this app says a long prompt is how a
   small model gets worse.
4. **The executable protocol, if the first three have found somebody who needs
   it.** Section 8 of [plugins.md](plugins.md) says why that condition is there.

Steps 1 to 3 are perhaps a week between them. Step 4 is a week on its own, mostly
in the failure paths, and it should not be started until something exists that
step 3 cannot do.

## 10. What this design refuses to do, and why

- **No in-process loading.** Section 0 of [plugins.md](plugins.md).
- **No plugin store.** An app that downloads code is a different app with a
  different threat model, and this one has 12 000 lines and a diary about somebody
  to defend.
- **No API for the diary, the screen, the location or the front application.**
  Those four are why the app is trusted with anything; delegating them is how that
  ends.
- **No plugin that speaks unprompted.** Interrupting somebody is the hardest thing
  in this app to get right — a release was spent on when it is allowed — and it
  stays the app's decision.
- **No settings a plugin can write.** It reads its own manifest and it is asked
  questions. It does not get to change how the cat behaves when it is not
  involved.
