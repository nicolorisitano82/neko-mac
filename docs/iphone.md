# Neko on iPhone: what would survive the move

A study, not a plan. It asks one question — *what is left of this app on a
platform with no desktop* — and answers it with the API that is missing in each
case rather than with an opinion. Where a number decides something, the number is
here; where it has to be measured on a device, it is listed as a spike with the
threshold that would settle it.

The short answer: **about a third of the code ports unchanged, the cat ports
completely, and the thesis of the last release does not port at all.** What is
left is a good app. It is a different app.

## 1. What there is to move

Measured on this repository today:

| | lines | what it is |
| --- | --- | --- |
| **Pure logic** — no AppKit at all | **3 723** | the diary, the pace, the engine chooser, the feeds, the place, the voice, the filter, all four answer providers, the model store, the llama binding |
| **Barely AppKit** — one or two calls | **2 944** | the sprite state machine, the listener, the actions, the antics, the persona, the permissions |
| **AppKit-bound** | **5 601** | the panel, the bubble, the typed line, the preferences (2 171 on their own), the desktop observer, the Carbon hotkey |
| | **12 268** | across 34 implementation files |

Plus 44 characters — 1 376 PNGs, 7.4 MB — which are just images and move as they
are. The Mac bundle is 69 MB, of which **55 MB is `neko-paint`**, the
stable-diffusion command-line helper. That 55 MB is the first thing iOS takes
away, and section 3 explains why.

The useful way to read that table: the work of the last release — the diary, the
budget, the seams, the voice, the feeds — is almost entirely in the first row. The
part that would have to be rewritten is the part that was written in 2007.

## 2. What the app currently is

Four claims, and iOS has something to say about each:

1. **It lives on top of everything.** A borderless panel at
   `NSStatusWindowLevel`, on every Space, ignoring activation.
2. **It chases the pointer.** A global mouse position, sampled ten times a
   second.
3. **It watches the day without reading anything.** Which application is in
   front, how long you have been in it, how often you switch, keys and mouse per
   minute, how long since you last touched anything.
4. **It speaks when it judges the moment right.** Eight to fifteen times a day,
   at a seam in the work, through a bubble that is not a notification.

## 3. What iOS takes away

### No window above other applications

There is no public way for a third-party app to draw over another app. No
overlay, no floating sprite, no equivalent of a borderless always-on-top panel.
This is not a permission that can be requested; the window server is not exposed.

*Consequence:* the cat cannot live on the phone the way it lives on the Mac. Every
product shape in section 5 is a different answer to "then where does it live".

### No pointer to chase

There is no system-wide cursor, and an app receives touches only inside its own
view hierarchy. On iPadOS with a trackpad there **is** a pointer, and
`UIHoverGestureRecognizer` reports it — but again only inside the app.

*Consequence:* `MyPanel`'s pursuit logic survives as code and loses its target. In
the app's own canvas it can chase a finger, a hovering Pencil, or nothing.

### No cross-app observation

`NekoDesktop` — 528 lines, the input to every timing decision — has no iOS
counterpart. `CGEventSourceCounterForEventType`, `CGEventSourceSecondsSinceLastEventType`,
the window list, the accessibility tree: none of it exists for third-party apps.

The one legitimate route to "which app are you using" is the **Screen Time API**
(FamilyControls, DeviceActivity, ManagedSettings). It needs the
`com.apple.developer.family-controls` entitlement, which is **requested from
Apple per bundle identifier and approved in days to weeks**, and its authorization
prompt is a guardian-style approval. It reports activity in categories and
thresholds, not "you have been in Xcode for forty minutes".

*Consequence:* the breakpoint work of step 2 has no inputs. Four seams become
zero, unless the app is the thing you are using.

### No background life

An app in the background gets a few minutes, then nothing. `BGAppRefreshTask` runs
when the system feels like it, not on a twenty-second heartbeat. There is no way
to keep a state machine ticking, a microphone open, or a pace accruing while
somebody works in another app.

*Consequence:* `NekoRate`'s day — which accrues time at the Mac — can only count
time in *this* app. The wake word (`NekoWakeWord`, 345 lines) is not portable at
all: always-listening in the background needs the audio background mode, which
exists for playback, and using it to keep a microphone open is both a review
problem and a battery problem.

### No helper processes

`fork`/`exec` of a second binary is not available. `neko-paint` — the 55 MB
stable-diffusion CLI the Mac app spawns with `NSTask` — cannot ship in this form.

*Consequence:* drawing must be in-process (link the library, or Core ML), or must
go through Apple's own image generation. Note for the Mac side too: **Apple has
deprecated `ImageCreator`** — the headless Image Playground API — and it stops
working in iOS 27 and macOS 27. The supported route is `imagePlaygroundSheet`,
which is a UI the person drives, not a function that returns a picture. A cat
that draws on its own has to carry its own diffusion.

### No way to speak unasked, except the one thing this app refuses to be

The only channel for an app to say something while you are elsewhere is a local
notification. The entire argument of the last release was that a remark you cannot
answer is a notification, and that notifications are what people switch off. On
iPhone, "speak at a seam in the work" would be implemented as a notification
delivered on a guess.

*Consequence, and it is the finding of this document:* **the truelife thesis
cannot be delivered on iPhone.** Not because the code is hard to move — the pace,
the filter, the diary all move — but because the platform denies both halves at
once: the observation that would find the moment, and the channel that would use
it without becoming a notification.

## 4. What iOS gives back

Not a consolation list — three of these are better than anything the Mac version
has:

- **Focus status.** `INFocusStatusCenter`, with the user's authorization, reports
  whether a Focus is on. On macOS this was the one thing that could not be read at
  all: the state lives in a file no application may open. The iPhone version would
  know when to be quiet, properly, which the Mac version only approximates with a
  full-screen-window check.
- **Location, without apology.** `NekoPlace` already exists and already keeps a
  town and a region rather than coordinates. On a phone that moves, "che notizie ci
  sono qui" and "che tempo fa" are better questions than they are on a desk.
- **Foundation Models.** iOS 26 exposes Apple's on-device ~3B model to
  third-party apps: no key, no cost, no network, three lines of Swift. The Mac
  app's own measurements say a 1.5B is not enough to carry these instructions and
  Apple's model is; on iPhone that engine is the default rather than the
  fallback — on iPhone 15 Pro and later.
- **Presence without notification.** A widget, a Control Center control, a Live
  Activity, the Dynamic Island. A widget's line can change several times a day
  within its refresh budget (**about 40–70 reloads in 24 hours**, tuned by the
  system to when you look at it) and costs nobody an alert. A Live Activity lasts
  up to 8 hours active and 12 on the Lock Screen, and **cannot start on its
  own** — a person starts it.
- **A real invocation.** App Intents give the cat Siri, the Shortcuts app, the
  Action button and a Control Center control — a better replacement for the Carbon
  hotkey than the hotkey was.
- **The one place typing is legitimately visible.** A keyboard extension sees what
  you type, by design and with the user's knowledge. It is also boxed in: roughly
  **48–60 MB of memory**, no background work, no network at all unless the person
  grants Full Access.

## 5. Three things it could be

### A. The pet you visit — *recommended*

The cat lives in its own app: a canvas it roams, a bubble it speaks in, the
diary, the questions, the drawings, the feeds. Presence outside the app is a
**widget** — the cat in whatever pose it is in, plus one line it has been saving
up — and, optionally, a Control Center control that opens straight into asking.

*Ports directly:* everything in row one of section 1, the sprite engine, the
listener, the bubble, the typed line.
*Rewrites:* the container (SwiftUI or UIKit), the settings screen, the invocation.
*Abandons:* the seams, the wake word, cross-app actions, file copying.
*What replaces the rate:* the pace becomes what the widget shows, not what
interrupts you. Eight to fifteen remarks a day is a perfectly good widget
schedule and a terrible notification schedule.

### B. The cat in the keyboard

A keyboard extension with the cat walking along the suggestion row: it reacts to
the rhythm of typing, gets curious about a long pause, and can be tapped to ask
something. This is the only shape in which the *ambient* half of the app survives,
because a keyboard is the one place iOS lets an app see what you are writing.

*Costs:* 48–60 MB total, which rules out any local model inside the extension
(the smallest one here is 1.12 GB) and probably any generated line at all —
answers would come from the containing app through a shared container, or from
Foundation Models in the app rather than the extension. Full Access turns the
privacy story into the product's main claim, and it had better be airtight: the
Mac version's rule is that text read from the screen can never reach an action,
and a keyboard would need the same rule written twice as loudly.

### C. The session companion

You start a session — work, study, writing — and the cat appears as a **Live
Activity** in the Dynamic Island for up to eight hours, with a pose and a line.
Because the person starts it, an interruption inside it is invited rather than
imposed, which is a legitimate answer to the notification problem.

*Costs:* it is a mode, not a life. The cat exists while a session does.

### And the honest note about iPad

On iPad the original behaviour survives best: there is a pointer, hover events
exist, and side-by-side apps mean the cat's window is next to your work rather
than over it. Nothing about the observation problem changes — it still cannot see
what you are doing in the other half of the screen — but the *pet* is intact.

## 6. The port, file by file

| file | lines | verdict |
| --- | --- | --- |
| `NekoMemory`, `NekoRate`, `NekoBrains`, `NekoVoice`, `NekoSense`, `NekoWeb`, `NekoPlace`, `NekoModelStore`, providers, `NekoLlamaEngine` | 3 723 | **keep.** Foundation, URLSession, CoreLocation, ggml. `NekoRate` keeps its arithmetic and changes what a "day" counts. |
| `MyPanel`, `MyView`, `NekoCharacter` | 1 069 | **adapt.** The 18-state machine and the 0.125 s tick are pure logic; `NSView`→`UIView`, `NSImage`→`UIImage`, and the pursuit target changes. |
| `NekoBubble`, `NekoLine` | 745 | **adapt.** Same geometry, no window levels, no key-window problem — it is all one app now. |
| `NekoListener` | 244 | **keep, mostly.** `SFSpeechRecognizer` and `AVAudioEngine` exist on iOS, on-device recognition included. Foreground only. |
| `NekoAsk` | 1 181 | **adapt.** The flow survives; the hotkey, the panel hold and the beat's microphone rules change shape. |
| `NekoAction` | 409 | **shrink.** `open-url` survives, Shortcuts survive through App Intents, and opening an arbitrary application survives only where it publishes a URL scheme. Copying and moving files reduces to this app's own container plus a document picker. |
| `NekoFolderAccess` | 158 | **replace.** `UIDocumentPickerViewController` and security-scoped URLs — the same idea, a different class. |
| `NekoPermissions` | 240 | **rewrite.** Microphone, speech, location, notifications; no accessibility, no screen recording; possibly Family Controls. |
| `NekoPainter` | 167 | **rewrite.** No helper process. Either link stable-diffusion.cpp in-process or use Core ML; `ImageCreator` is a dead end from iOS 27. |
| `NekoController` | 2 171 | **rewrite.** It is a status item and six tabs of AppKit. The settings become a screen; the character picker becomes a list. |
| `NekoDesktop` | 528 | **drop, or reduce to almost nothing.** See section 3. |
| `NekoHotKey`, `NekoWakeWord` | 532 | **drop.** Carbon, and an always-open microphone. |
| `NekoAdvisor`, `NekoAntics` | 547 | **keep the antics, park the advisor.** Curiosity works inside the app; unprompted remarks have nowhere to go. |

Roughly: **4 000 lines move as they are, 3 000 need a UIKit translation, 3 500
get rewritten, 1 000 get dropped.**

## 7. Measure these before committing to anything

Each of these is a day or less, and each has a number that decides a design
question rather than confirming a hope.

1. **Does a useful local model fit?** Load the 1.12 GB 1.5B on the oldest target
   device with `com.apple.developer.kernel.increased-memory-limit`, generate 200
   tokens, and watch for jetsam. The entitlement raises the per-app limit but
   cannot exceed physical RAM, and it does nothing on 4 GB devices. *Decides:*
   whether "a model on this iPhone" is a feature or a line in the FAQ.
2. **How many devices get Foundation Models?** It needs an Apple
   Intelligence-capable device. *Decides:* whether the good engine is the default
   or a minority path, and therefore how much the written-in fallbacks matter.
3. **What does a widget actually get?** Ship a timeline that wants a new line
   every 45 minutes and count the reloads over three real days against the
   40–70 budget. *Decides:* whether the widget can carry the colleague rate.
4. **Speech, on device, on a phone.** Time from tap to first words and to final
   for Italian and English, with `requiresOnDeviceRecognition`. The Mac numbers
   (1.5 s of patience, 15 s of limit) may need to change.
5. **The sprite engine at 60 Hz in UIKit.** 44 characters, an 8×4 sheet, a
   `CALayer` with `contentsRect` rather than a view per frame. *Decides:* whether
   the cat can also live in a widget snapshot and a Live Activity, which are
   redrawn by the system rather than animated.
6. **Family Controls, if section 5B or any ambient shape is on the table.**
   Request the entitlement early: approval is days to weeks, and the answer
   changes what the product can claim.
7. **Diffusion in-process.** Peak memory and seconds per step for SD 1.5 through
   Core ML on the target device, against the Mac's measured 14.5 s for a
   512-pixel picture at 14 steps.

## 8. What not to build

- **A notification pet.** Everything the last release established says this fails,
  and the App Store is full of the evidence.
- **An always-listening background microphone.** The audio background mode is for
  playing audio. This would be a rejection, and on a phone it would also be a
  battery complaint.
- **A keyboard with Full Access and a vague privacy story.** If the cat reads what
  you type, the app has to be able to say exactly where that text goes and prove
  it. The Mac version's invariant — screen text can never reach an action — has a
  test that fails if it is ever broken; a keyboard would need that test and a
  second one for the network.
- **The desktop metaphor, ported.** A floating cat that cannot float is a worse
  version of both things.

## 9. If it were built

1. **A spike, one week.** The sprite engine in UIKit, one character, chasing a
   finger; the diary and the pace linked in and running against in-app time; a
   question answered by Foundation Models. This proves the interesting third of
   the port in the cheapest possible way.
2. **The app, three to four weeks.** Canvas, bubble, ask, settings, characters,
   feeds, diary, drawings deferred.
3. **Presence, one week.** A widget with a pose and a line; a Control Center
   control and an App Intent for asking; Focus status honoured.
4. **Then decide** between B and C — or neither — with the numbers from section 7
   in hand rather than from this document.

Drawings and a local model come last on purpose: they are the two heaviest things
and the two the platform is least ready for.

## 10. Open questions

1. **Does a pet you have to open still work?** The Mac cat earns its place by
   being *there*. A cat behind an app icon is a different relationship, and no
   amount of engineering answers whether it is still worth having.
2. **Is a widget line a remark?** It is the only way to say something without an
   alert. Whether somebody experiences it as the cat talking, or as furniture, is
   the thing to find out first — and it is cheap to find out.
3. **What happens to the diary when the day is unobservable?** On the Mac the
   diary is fed by what the cat noticed. On iPhone it would be fed almost entirely
   by what you said to it. That may be better — it is certainly more honest — but
   the nightly reflection was tuned on observations, and it would need retuning on
   conversation.
4. **One codebase or two?** The 3 723 portable lines are worth sharing, which
   argues for a package and two thin platform layers. Every hour spent on that
   structure is an hour not spent finding out whether answer 1 is yes.

## Sources

- [Foundation Models framework, iOS 26](https://developer.apple.com/videos/play/wwdc2026/339/) — on-device ~3B model, third-party access, Apple Intelligence-capable devices; [background](https://www.macrumors.com/2025/06/09/foundation-models-framework/)
- [WidgetKit refresh budget](https://developer.apple.com/forums/thread/654331) — 40–70 reloads a day, window tuned to usage; [practical notes](https://swiftsenpai.com/development/refreshing-widget/)
- [ActivityKit](https://developer.apple.com/documentation/activitykit) — 8 hours active, 12 on the Lock Screen, started by a person; [iOS 26 guide](https://swiftcrafted.dev/article/live-activities-dynamic-island-ios-26-swiftui-activitykit-guide)
- [Increased Memory Limit entitlement](https://developer.apple.com/forums/thread/770868) — raises the per-app limit, cannot exceed physical RAM, no effect on 4 GB devices; [summary](https://zenn.dev/mtfum/articles/ios_memory_entitlements?locale=en)
- [Requesting the Family Controls entitlement](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement) — per bundle ID, Apple approval; [what the APIs do](https://medium.com/@juliusbrussee/a-developers-guide-to-apple-s-screen-time-apis-familycontrols-managedsettings-deviceactivity-e660147367d7)
- [INFocusStatusCenter](https://developer.apple.com/documentation/intents/infocusstatuscenter?language=objc) — Focus status with the user's authorization
- [ImageCreator deprecation](https://developer.apple.com/news/?id=dz9wvq0r) — stops working in iOS 27 / macOS 27; [Image Playground for developers](https://developer.apple.com/videos/play/wwdc2026/375/)
- [Keyboard extension limits](https://www.fleksy.com/blog/limitations-of-custom-keyboards-on-ios/) — memory ceiling, no background work, Full Access gates the network; [the 48 MB wall in practice](https://github.com/facebook/react-native/issues/31910)
- llama.cpp ships `examples/llama.swiftui`, which is how the engine in this repository would reach a phone at all.

All the numbers about *this* app — lines, files, sprite weight, model sizes, the
55 MB helper — were counted in this working copy while writing this document.
