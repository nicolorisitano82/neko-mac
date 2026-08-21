# Ask Neko — design

An optional mode: a keystroke, you ask a question out loud, and the answer
arrives in a speech bubble beside the cat, as if the cat had answered.

Nothing here is implemented yet. This document is the plan, and the three
assumptions it rests on were measured inside the sandboxed app first:

| Checked | Result |
|---|---|
| `RegisterEventHotKey` in the App Sandbox | works, `OSStatus 0`, no permission prompt |
| `SFSpeechRecognizer`, `AVSpeechSynthesizer` | both present, authorisation still undetermined |
| Reading `NSPasteboard` | works, no permission |
| `shortcuts` CLI | present, macOS 27 |

## The part that cannot work as described

**Siri has no public API that hands an answer back to another app.** Nothing can
ask Siri a question and read what it replied — not AppleScript, not Shortcuts,
not an entitlement. The same is true of the ChatGPT extension inside Siri: it
answers *to the user*, never to a program.

So "ask Siri through Neko" has to become one of three different things.

### Route A — Shortcuts as the bridge (recommended)

Neko turns speech into text, hands the text to a Shortcut the user owns, and
shows whatever the Shortcut returns.

The Shortcut is where the intelligence lives, and it is the user's choice: the
Apple Intelligence "Use Model" action, which can escalate to ChatGPT, or a
ChatGPT action, or anything else that ends in text. Neko ships a template and a
one-click install link, not a model.

- **No API keys** in the app, no network code of ours, no data leaving through
  us.
- The user can read and edit exactly what happens to their question.
- Handing the question over: write it to a file inside our own container and
  launch `shortcuts://run-shortcut?name=Ask%20Neko&input=...`, or run the
  `shortcuts` CLI. Getting the answer back is the awkward half: the tidiest
  permission-free channel is the clipboard — the Shortcut ends with *Copy to
  Clipboard*, Neko reads it and puts the previous clipboard contents back.
  A file in a folder the user grants once, with a security-scoped bookmark, is
  the cleaner alternative and costs one extra prompt.
- **Cost**: a template Shortcut to write and document, plus a fragile-ish
  handshake. It is the only route that gets an answer from Apple Intelligence or
  ChatGPT without us becoming an API client.

### Route B — Neko asks a model directly

The user pastes their own API key once, we store it in the Keychain, and Neko
calls the model itself.

- Full control: streaming, the cat's own voice and tone, error handling that
  makes sense, no clipboard tricks.
- Needs `com.apple.security.network.client`, key storage, and a paragraph in the
  README explaining that questions go to that provider.
- It has nothing to do with Siri, and it makes a toy into something that spends
  the user's money.

### Route C — theatre

The hotkey pops the bubble, Neko says something in character, and Siri is
activated for real by the user's own shortcut. Neko never sees the answer; it
only reacts.

- Half a day of work, zero permissions, zero privacy questions.
- It is a joke, not a feature. Worth knowing it exists as a fallback.

**Decided: A and B, as two providers behind one protocol**, with C as the
behaviour when neither is configured. A ships first, because it needs no keys.

### The provider protocol

One method, asynchronous, cancellable:

```objc
@protocol NekoAnswerProvider <NSObject>
- (NSString *)name;                 /* shown in the preferences */
- (BOOL)isConfigured;               /* false sends the caller to route C */
- (void)askQuestion:(NSString *)question
         completion:(void (^)(NSString *answer, NSError *error))completion;
- (void)cancel;
@end
```

The controller owns the current provider, picked in the preferences, and knows
nothing about how either one works. Both implementations share the same rules:
answer or fail within 12 seconds, always call back on the main thread, and treat
cancellation as neither.

`NekoShortcutProvider` writes the question where the Shortcut expects it, runs
it, waits for the clipboard to change, restores the previous clipboard contents,
and hands back what it found.

`NekoModelProvider` reads the key from the Keychain, posts the question with the
system prompt that gives the cat its voice, and streams nothing — the bubble
appears complete, since a talking cat that types is a different feature.

Adding a third provider later means one class and one line in the picker.

## Flow

```
        ⌃⌥N
         │
         ▼
   [listening]  ──── 8 s of silence, or Esc ────▶ [cancelled]
         │  speech → text, on device when the language allows
         ▼
   [thinking]   ──── provider fails or times out (12 s) ──▶ [shrug]
         │
         ▼
   [answering]  ──── bubble, optionally spoken ──▶ dismissed on click,
                                                   on Esc, or after
                                                   6 s + 40 ms per character
```

The cat's existing animations carry the states, so no new art:

| Phase | Sprite | Why it reads right |
|---|---|---|
| listening | `awake` | ears up, already the "something is happening" pose |
| thinking | `kaki` then `jare` | grooming and looking about, the idle fidget |
| answering | `mati2` | sitting still, facing the viewer |
| failed | `mati3` (yawn) | a shrug the character already owns |

While Ask Neko is active the pet stops chasing the pointer and stays put: being
asked a question is more important than the cursor. The panel is frozen the same
way **Pause** freezes it, and resumes afterwards.

## The bubble

A second panel, borderless and non-activating, so it never takes focus from what
the user is doing:

- Positioned above the cat, flipped below when there is no room, and clamped to
  the same screen bounds the cat already respects.
- Follows the cat if it moves; while a bubble is up the cat does not move, so
  this only matters for the tail end of an animation.
- Rounded rectangle with a small tail pointing at the cat, `NSVisualEffectView`
  behind the text so it stays legible over any wallpaper, and text in the system
  font at the system size.
- Sized to the text, capped at 420 points wide and ten lines, then scrollable —
  or better, truncated with the full answer copied to the clipboard on click.
- Dismissed by click, by Esc, or by a timeout that scales with the length of the
  answer.

Speaking the answer is a separate preference, off by default, using
`AVSpeechSynthesizer` with a slightly raised pitch. Voice is charming once and
tiring on the twentieth question, so it must be easy to turn off.

## The keystroke

**⌃⌥N** — Control-Option-N. Decided, and configurable:

- One-handed, the two modifiers sit next to each other, and N is for Neko.
- Control-Option is almost unused by applications, so it shadows nothing.
- It is not a dead key: ⌥N alone types a tilde on several layouts, which is why
  the plain Option version is a bad idea, and ⌘⌥N would shadow *New Smart
  Folder* in Finder.

Alternatives worth offering, in order: ⌃⌥Space, ⌘⌃N, ⌥⇧N. Double-tapping a
modifier, the way Siri does, needs global event monitoring and therefore the
Accessibility permission, so it is out.

The shortcut must be configurable — a recorder field in the preferences —
because any fixed default collides with someone's launcher.

## The preferences window has run out of room

It is already 445 by 340 points with nine controls, and Ask Neko adds a switch,
a shortcut recorder, a provider picker, a key field and a *speak the answer*
switch. Cramming those in makes the window a wall.

Split it into an `NSTabView` with two tabs: **Pet**, holding everything that
exists today, and **Ask Neko**, holding the new block, disabled as a whole until
the feature is switched on. Same window size for both tabs, so it does not
resize as you switch.

This is worth doing before the feature rather than after: the tab split touches
every control that already exists, and doing it twice is wasted work.

## Permissions and what has to change

| | |
|---|---|
| `NSMicrophoneUsageDescription` | Info.plist, explaining that audio is captured only while the bubble says *listening* |
| `NSSpeechRecognitionUsageDescription` | Info.plist |
| `com.apple.security.device.audio-input` | entitlement, the only new one for route A |
| `com.apple.security.network.client` | entitlement, route B only |
| Frameworks | `Speech`, `AVFoundation`, `Carbon` for the hotkey |

The microphone permission is requested the first time the feature is used, never
at launch, and the feature is **off by default**. A one-time explanation sheet
before the first prompt says what will happen, because a desktop toy asking for
the microphone with no warning is alarming.

## Privacy, plainly

- The microphone opens on the keystroke and closes when recognition ends. No
  hot word, no background listening, ever.
- `SFSpeechRecognizer` runs on device when the chosen locale supports it, and the
  preference says which mode is in use rather than hiding it.
- Route A sends nothing anywhere by itself: whatever the user's Shortcut does is
  visible in the Shortcuts app.
- Route B states the destination in the preferences, next to the key field.
- The clipboard is restored after the handshake, and the app never keeps a
  transcript on disk.

## What can go wrong

| Failure | What the user sees |
|---|---|
| Microphone denied | the bubble says so once, with a button to the right pane of System Settings, and the feature switches itself off |
| Nothing recognised | *I didn't catch that* and back to normal after two seconds |
| No provider configured | route C: a canned reply in character, plus a hint about the Shortcut |
| Shortcut missing or renamed | *I can't find my Shortcut* and a link to install the template |
| Provider slow | thinking animation until the 12 s timeout, then the shrug |
| Hotkey already taken | registration fails at startup: the preferences field shows the conflict instead of failing silently |
| Answer enormous | truncated in the bubble, whole thing copied on click |

## Build order

1. **Hotkey and the bubble**, with a canned answer. Proves the interaction, the
   panel plumbing and the freeze, and is usable as route C. Half a day.
2. **Speech to text**, permissions and the listening state. A day, most of it in
   the permission flow and the error paths.
3. **Route A**, the Shortcuts bridge and its template. A day, and the part most
   likely to need iteration.
4. **Route B** behind the same protocol. Half a day plus the Keychain, and the
   README paragraph naming where questions go.

Phase 0, before any of it: the tab split in the preferences window.

Phases 1 and 2 are worth having on their own: a cat that hears you and answers
something in character is already the whole joke.

## Not for the web version

The Angular port has no microphone story worth having and no global hotkey, so
`Ask Neko` stays a desktop feature. The engine's option object gains nothing.
