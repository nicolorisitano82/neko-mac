# Writing a Neko plugin

A guide for somebody with a Mac, Xcode's command line tools, and something they
want the cat to be able to do. [plugins.md](plugins.md) says *why* the design is
shaped like this; this says how to build one.

Two things to know before anything else.

**A plugin is a folder with a manifest, and the manifest is the contract.** What
it declares is what it may be asked, and nothing else about it is consulted. A
plugin that did not declare `Feeds` cannot add a feed however many feed addresses
its files contain.

**Nothing is loaded into the app.** Neko is sandboxed and holds a microphone, a
location, folders somebody handed over by name, and a diary about their working
life. Code inside that process would inherit all of it. So a plugin is either
data, or one of the user's own Shortcuts, or — the part specified in section 6 —
a **separate process** that speaks JSON over a pipe and knows nothing about the
inside of the app.

Everything in sections 1 to 5 works in Neko 2.5 and later, except verbs
(section 4c), which need 2.6, and the player door, which needs 2.7. Section 6 is a specification, not a description: a
manifest that declares it is refused today, with the sentence that says so.

## 1. The shape of one

```
My Thing.nekoplugin/
    plugin.plist          the manifest — required, and the whole contract
    README.md             optional, for people
    filter                optional, the program from section 6
```

The folder name must end in `.nekoplugin`. Everything else about the layout is
yours.

To try it: **Plugins…** in Neko's menu → **Add…** → choose the folder. It is read
before it is copied, so a manifest with a mistake in it is refused where you are
looking rather than later in a list. It arrives **switched off**; the switch is
in the same row.

There is no plugin store, no downloader and no auto-update. A plugin arrives
because somebody put it there.

## 2. The manifest

A property list. Anything `plutil -lint` accepts — XML or the old-style text
format — and `plutil -convert xml1` is a good habit before shipping.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Identifier</key>   <string>com.example.markets</string>
    <key>Name</key>         <string>Markets</string>
    <key>Version</key>      <string>1.0</string>
    <key>Author</key>       <string>Your name</string>
    <key>License</key>      <string>MIT</string>
    <key>Interface</key>    <integer>1</integer>
    <key>MinimumApp</key>   <string>2.5</string>
    <key>Summary</key>      <string>Two feeds about the markets.</string>
    <key>Wants</key>
    <array><string>network</string></array>
    <key>Extends</key>
    <dict>
        <key>Feeds</key>
        <array>
            <dict>
                <key>Identifier</key> <string>borsa</string>
                <key>Name</key>       <string>Il Sole 24 Ore</string>
                <key>Detail</key>     <string>markets, in Italian</string>
                <key>Address</key>    <string>https://www.ilsole24ore.com/rss/finanza.xml</string>
                <key>Prominent</key>  <false/>
            </dict>
        </array>
    </dict>
</dict>
</plist>
```

| key | type | required | what it is |
| --- | --- | --- | --- |
| `Identifier` | string | **yes** | reverse-DNS, unique. It is how the app remembers your plugin across updates. |
| `Name` | string | **yes** | shown in the panel. |
| `Version` | string | recommended | compared with `NSNumericSearch`, so `1.10` is above `1.9`. |
| `Author`, `License` | string | recommended | shown in the panel; `License` matters if you ship feeds you do not own. |
| `Interface` | integer | **yes** | which plugin interface you wrote for. **1** today. |
| `MinimumApp` | string | recommended | the oldest Neko that can run it. |
| `Summary` | string | recommended | one sentence, shown under the name. |
| `Wants` | array of strings | when needed | `network` is the only one so far. Declare it or your feeds are refused. |
| `Extends` | dict | **yes**, in practice | what you actually add — `Feeds`, `Text`, `Characters`. |

Unknown keys inside `Extends` are **refused, not ignored**: ignoring one would
mean your plugin believes it is doing something it is not.

## 3. Feeds

The extension point the app's own news sources use — they ship as
`Plugins/Neko News.nekoplugin` inside the app, which is the honest test of this
interface. Read it; it is the largest worked example there is.

```xml
<key>Feeds</key>
<array>
    <dict>
        <key>Identifier</key> <string>borsa</string>
        <key>Name</key>       <string>Il Sole 24 Ore</string>
        <key>Detail</key>     <string>markets, in Italian</string>
        <key>Address</key>    <string>https://…</string>
        <key>Prominent</key>  <false/>
    </dict>
</array>
```

- `Identifier` is **the word somebody says**: "che notizie ci sono su *borsa*". One
  plain word, letters and digits only. It is matched as a whole word, and only
  once the sentence has already said it is after the news — so a common word is a
  bad choice, and a word the app already governs (`ansa`, `sport`, `mondo`, …) is
  simply never reached.
- `Address` must be `https`. RSS or Atom; the app takes the first eight items,
  title plus the one-line summary, and strips any markup inside them.
- `Detail` is looked up as a **string key** before it is shown, so if it happens
  to be a phrase Neko already translates you get the translation for free.
  Otherwise it passes through as written.
- `Prominent` puts your word in the short list a model is shown. Leave it out. The
  list is eight words long because a longer one costs a small model more than the
  choice is worth, and the app recognises your word by itself anyway.

**Requires `Wants = ["network"]`.** Feeds without it are refused.

What the app does with a feed is what it does with its own: fetches it with an
ephemeral session, no cookies, no history, eight seconds, sends nothing about the
question, and quotes the headlines as written. It never lets an answer built on
them open, copy or move anything.

## 4. Text, in and out

Your plugin can be handed what somebody said before the engine sees it, or what
the cat is about to say before it is shown, and hand something back.

```xml
<key>Text</key>
<dict>
    <key>Direction</key> <string>both</string>   <!-- in, out, or both -->
    <key>Shortcut</key>  <string>Tidy up</string>
</dict>
```

The work is done by **one of the user's own Shortcuts**. You name it; you cannot
name a program here. That is the whole reason this is allowed without a trust
decision: the Shortcut is theirs, and nothing new runs inside the app.

Your Shortcut receives the text as input and must **put its result on the
clipboard** — the app saves and restores the clipboard around the call. Four
rules, all enforced:

1. **Words and nothing else.** If what comes back carries `ACTION:`, `IMAGE:` or
   `LOOK:` *anywhere in it*, the whole transformation is discarded and the
   original text stands. A plugin reaching for a marker is not making a
   punctuation mistake.
2. **It never blocks the conversation.** Slow, missing or broken means the
   original text after the timeout.
3. **It sees the words and nothing around them.** Not the diary, not the
   instructions, not what the cat noticed, not where the Mac is.
4. **What was said is what is remembered.** The diary keeps the words somebody
   actually said; your rewording is what the engine is asked.

Useful things to do with it: translate the answer, redact a client's name before
a remote engine sees the question, expand your own abbreviations, force a house
style. Useless things: anything that needs to know what came before, because you
are handed one string.

## 4a. Characters

A plugin can ship characters — the cat itself, or a dog, or whatever somebody
drew. A character is a `.nekochar` folder: thirty-one PNGs or GIFs and a
`character.plist`, exactly the format the app's own forty-three use. Copy one out
of `Neko.app/Contents/Resources/Characters` and look at it; that is the whole
documentation of the format.

```
My Thing.nekoplugin/
    plugin.plist
    Ratto.nekochar/
        character.plist
        mati2.gif  awake.gif  right1.gif  …
```

```xml
<key>Characters</key>
<array>
    <string>Ratto.nekochar</string>
</array>
```

Named one by one, not found by scanning: the manifest is the contract, and a
folder that appears after it was written is not part of it. Each name must end in
`.nekochar`, must actually be inside your plugin, and must contain a readable
`character.plist` whose `Identifier` is one plain word.

Nothing in `Wants` — a character is images.

The rule that matters: **a plugin can add a character and never replace one.** If
your character's identifier is one the app already ships, the app's own wins and
yours is simply not in the list. Choose your own word.

Switched on, your character appears in the menu at once — the list is thrown away
and rebuilt when a plugin changes. Switched off, it disappears from the menu, and
if it was the one in use the app falls back to its own first character.

## 4b. Your own translations

The app runs in English, Italian, French and Spanish. A plugin carries its own
translations, in its own folder:

```
My Thing.nekoplugin/
    plugin.plist
    it.lproj/plugin.strings
    fr.lproj/plugin.strings
```

`plugin.strings` is a property list — the same `"key" = "value";` format as
anywhere else in macOS, or XML if you prefer. The keys are **the English strings
from your manifest**:

```
"Markets" = "Mercati";
"Two feeds about the markets." = "Due feed sui mercati.";
"markets, in Italian" = "mercati, in italiano";
```

What is looked up: your `Name`, your `Summary`, and every feed `Name` and
`Detail`. The order is your strings, then the app's own tables, then the string as
you wrote it. That second step is why the feeds that ship inside the app keep
their translations without a strings file of their own — their details are phrases
Neko already translates.

A plugin that ships English only says English things. That is your business, and
the app will not refuse you for it. What it does refuse is a `*.lproj` folder
whose `plugin.strings` cannot be read at all: *"Its fr.lproj translations cannot be
read; plugin.strings has to be a property list."* A silent fallback there would
leave you believing your translations work.

## 4c. Verbs — phrases you ask to be told about

A verb is a phrase and a door. You list the words; when somebody says them, the
app reads your sentence back, and on a yes it opens one thing: an address, or one
of the user's own Shortcuts.

```xml
<key>Extends</key>
<dict>
    <key>Verbs</key>
    <array>
        <dict>
            <key>Identifier</key>  <string>search</string>
            <key>Phrases</key>
            <array>
                <string>metti</string>
                <string>play</string>
                <string>put on</string>
            </array>
            <key>Confirm</key>     <string>Cerco “%@” su Spotify?</string>
            <key>Summary</key>     <string>searches Spotify and opens it</string>
            <key>Url</key>         <string>spotify:search:%@</string>
        </dict>
        <dict>
            <key>Identifier</key>  <string>volumeup</string>
            <key>Phrases</key>
            <array>
                <string>alza il volume</string>
                <string>volume up</string>
            </array>
            <key>Confirm</key>     <string>Alzo il volume?</string>
            <key>Shortcut</key>    <string>Neko Volume Up</string>
        </dict>
    </array>
</dict>
<key>Wants</key>
<array><string>open</string><string>shortcuts</string></array>
```

### The keys

| key | required | what it is |
| --- | --- | --- |
| `Identifier` | yes | one plain word, unique inside your plugin |
| `Phrases` | yes | the words to listen for, three letters at least each |
| `Confirm` | yes | the sentence shown before anything happens; a `%@` in it is filled with the rest of what was said |
| `Summary` | no | one line, shown in the plugins window |
| `Url` | one of the three | the address to open; a `%@` in it is filled with the rest of what was said, percent-encoded |
| `Shortcut` | one of the three | the name of a Shortcut the user has; it is handed the rest of what was said |
| `Player` + `Command` | one of the three | `music` or `spotify`, and one command from the closed list below |

`Confirm` and `Summary` go through your `*.lproj/plugin.strings` like everything
else, so a verb can read itself back in four languages.

### How a phrase is matched

Matching is done by the app, in code, before any model is consulted. What that
means for you:

- **Whole words only.** `metti` matches *"metti Taylor Swift"* and does not match
  *"mettiamo che sia lunedì"*. A phrase inside a longer word is not a match.
- **Longest wins.** With both `alza` and `alza il volume` listed, *"alza il volume
  per favore"* is the second one. Order in the array does not matter; length does.
- **Case is ignored, and the words are not.** The argument is cut from what was
  actually said, so `spotify:search:%@` gets *Taylor Swift* and not *taylor
  swift*.
- **The argument is everything after the phrase**, trimmed of spaces and of
  `? ! . , ; : “ ” " '`.
- **A verb that needs words is not a match without them.** If your `Confirm`
  sentence has a `%@` in it — or your `Url` does — and the person said only
  *"metti"*, no verb fires and the question goes on to the engine as usual. One
  without a `%@` is complete as it stands: *"alza il volume"* is the whole
  sentence. (This is asked of the read-back rather than of the door, because a
  Shortcut and a player can want the words just as much as an address can. Asking
  the address alone is what made 2.6's volume verbs do nothing.)
- **Only when doing things is switched on.** Verbs live under the same switch as
  the app's own actions, in Settings → Actions. Off, nothing you listed is even
  looked at.

### The three doors, and what is behind them

**An address.** `Url` may begin with `https`, `spotify`, `music`, `itms`, `itmss`
or `mailto`, and with nothing else. `file:` is refused. `shortcuts:` is refused as
an address — that is what `Shortcut` is for, and smuggling it in here to skip the
Shortcut half is the one attack this list exists to stop. Your manifest must
declare `Wants = open`.

**A Shortcut.** `Shortcut` is a name, and a name only: the user makes the Shortcut
themselves and calls it what you told them to. If it is not there, the verb
answers *"That did not work."* Nothing comes back from it — a verb does something,
it does not answer. Your manifest must declare `Wants = shortcuts`.

**A player.** `Player` is `music` or `spotify`; `Command` is one of `play`,
`pause`, `playpause`, `next`, `previous`, `volumeup`, `volumedown`, `playnamed`.
Neko sends it to Music or Spotify itself, through the scripting dictionary each of
them publishes, and macOS asks the person once per application under Privacy &
Security → Automation. Your manifest must declare `Wants = players`.

You do not supply a line of script, and a verb carrying a `Script` or
`AppleScript` key is refused. The scripts live in `NekoPlayer.m`, in one file,
where anybody deciding whether to trust this can read every command a plugin is
able to cause.

Two limits worth knowing before you design around them, both measured:

- **`playnamed` works on `music` only, and only in the person's own library.**
  Musica's dictionary cannot search the streaming catalogue and Spotify's cannot
  search at all. Asked for `playnamed` on `spotify`, the verb answers a sentence
  saying so.
- **`music://music.apple.com/search?term=…` does not search.** It brings Musica
  forward, selects Cerca, and drops the term. Do not ship it; an earlier version
  of the Apple Music example did.

Exactly one of the three, never two. A verb that could do two things is a verb
whose read-back sentence is a lie.

### What is checked, and when

Twice. Once when the manifest is read — everything in the table above, plus the
scheme, plus the markers. And once at the moment of doing, after the yes: the
plugin still installed, still enabled, still allowed to open things. A switch
turned off between the question and the yes counts as off.

### Write the read-back as if it were the only thing the person reads

Because it is. *"Cerco “Taylor Swift” su Spotify?"* names the thing and the place.
*"Faccio?"* names nothing, and would be accepted by the app and rejected by
anybody sensible. A `Confirm` that repeats the words back without saying what will
happen to them proves nothing about whether it was understood.

### Two of them ship with the app, as examples

`examples/Spotify.nekoplugin` and `examples/Apple Music.nekoplugin` in this
repository, and inside the app itself — **Plugins… → Examples…** shows them in
Finder, ready to drag onto **Add…**. Eight verbs and seven: volume, pause, resume,
skip and back sent straight to the player, and searching through the one address
each of them honours. Nothing to build. Their READMEs say what each cannot do, and
why enabling both at once means two cats answering the same sentence.

They ship switched off and outside the seeded folder, which is the honest place
for an example: something to read and copy, not something that starts answering
for you.

## 5. Getting it wrong: every refusal, and its sentence

The app refuses in sentences rather than codes, and a refused plugin stays in the
list with its reason so you can fix it. These are the exact sentences:

| what you did | what the panel says |
| --- | --- |
| no readable manifest | *There is no readable plugin.plist inside it.* |
| `Identifier` missing or not reverse-DNS | *Its Identifier is missing or is not of the form com.example.thing.* |
| no `Name` | *It has no Name to show.* |
| no `Interface` | *It does not say which plugin interface it was written for.* |
| `Interface` above what the app knows | *It was written for a newer version of Neko's plugin interface (2; this one understands 1).* |
| `MinimumApp` above the app | *It needs Neko 3.0 or newer, and this is 2.6.* |
| a marker in `Summary` | *Its summary contains one of Neko's own markers, which a plugin may not write.* |
| `Extends` not a dict | *Its Extends section is not a dictionary.* |
| an extension point that does not exist | *It extends "Routes", which this version of Neko does not offer yet.* |
| `Feeds` not a list | *Its Feeds section is not a list.* |
| feeds without `Wants = network` | *It adds feeds without asking for the network, so nothing could be fetched.* |
| a feed missing `Identifier` or `Name` | *One of its feeds has no Identifier or no Name.* |
| a feed word with a space or punctuation | *The feed word "two words" has punctuation or spaces in it; it has to be one plain word.* |
| a feed address that is not https | *The feed "borsa" is not an https address.* |
| a marker in a feed name or detail | *One of its feeds carries one of Neko's own markers in its name.* |
| `Text` without `Shortcut` | *It processes text without naming a Shortcut to do it with.* |
| `Text` with a `Program` | *It wants to process text with a program of its own, which this version does not allow — only one of your own Shortcuts.* |
| `Direction` not in/out/both | *Its Text section has to say Direction: in, out or both.* |
| `Characters` not a list | *Its Characters section is not a list.* |
| a character name not ending in `.nekochar` | *Each of its characters has to be the name of a folder ending in .nekochar.* |
| a character folder that is not there | *It says it ships the character "Ratto.nekochar", and that folder is not inside it.* |
| a character with no readable manifest | *The character "Ratto.nekochar" has no readable character.plist with an Identifier in it.* |
| a character identifier with a space | *The character identifier "two words" has punctuation or spaces in it; it has to be one plain word.* |
| `Verbs` not a list | *Its Verbs section is not a list.* |
| a verb that is not a dict | *One of its verbs is not a dictionary.* |
| a verb with no `Identifier`, or one repeated | *Each of its verbs needs its own Identifier.* |
| a verb with no `Phrases` | *The verb "search" lists no Phrases to listen for.* |
| a phrase of one or two letters | *The verb "search" has a phrase too short to match on; three letters at least.* |
| a marker in a phrase | *One of its verbs carries one of Neko's own markers in a phrase.* |
| no `Confirm` | *The verb "search" has no Confirm sentence, and nothing here happens without being read back first.* |
| a marker in `Confirm` | *One of its verbs carries one of Neko's own markers in its Confirm sentence.* |
| not exactly one of `Url`, `Shortcut`, `Player`+`Command` | *The verb "search" needs exactly one of Url, Shortcut, or Player and Command.* |
| a verb with a `Program` | *One of its verbs wants to run a program of its own, which this version does not allow.* |
| a scheme outside the list, `shortcuts:` included | *The verb "search" opens an address Neko will not open; allowed are https, spotify, music, itms and mailto.* |
| a `Url` verb without `Wants = open` | *It has verbs that open an address without asking to open things.* |
| a `Shortcut` verb without `Wants = shortcuts` | *It has verbs that run one of your Shortcuts without asking to.* |
| a `Player` verb without `Wants = players` | *It has verbs that command Music or Spotify without asking to.* |
| a player that is not music or spotify | *The verb "play" names the player "Terminal", and Neko only knows music and spotify.* |
| a command outside the list | *The verb "play" asks for "quit", which is not one of the commands Neko can send.* |
| `Player` without `Command`, or the other way round | *The verb "play" needs both a Player and a Command.* |
| a verb carrying a `Script` of its own | *One of its verbs carries a script of its own. Neko sends its own commands to Music and Spotify and never anybody else's.* |
| an unreadable `.lproj/plugin.strings` | *Its fr.lproj translations cannot be read; plugin.strings has to be a property list.* |

Two identifiers claiming the same string: the first one read wins, and the second
is not used.

While developing, the app's own log is where the rest is:

```bash
log stream --predicate 'process == "Neko"' --style compact
```

That is where you will see *"%@ returned a marker; the whole transformation is
ignored"*, *"names the Shortcut … which is not there"*, and *"took too long; the
text is unchanged"*.

## 6. A program of your own — the specification

**Status: specified, not implemented.** `Interface 2`, and a manifest declaring it
is refused today with *"It was written for a newer version of Neko's plugin
interface"*. This section exists so that a plugin can be written against a
contract that will not change under it, and so that the reasoning is on the record
before any of it ships.

### What it is

A **command-line program inside your plugin folder**, launched as a child of the
app when there is something for it to do, handed one JSON object on standard
input, and expected to write one JSON object on standard output and exit.

One request per launch. No daemon, no state between calls, no socket. That is a
deliberate cost: it is slower than a long-lived process and much easier to reason
about, and a plugin that crashes takes nothing with it.

```xml
<key>Interface</key> <integer>2</integer>
<key>Extends</key>
<dict>
    <key>Text</key>
    <dict>
        <key>Direction</key> <string>out</string>
        <key>Program</key>   <string>filter</string>   <!-- relative to the folder -->
    </dict>
</dict>
<key>Wants</key>
<array><string>program</string><string>network</string></array>
```

`Wants` must contain `program`. A plugin that ships a program without declaring it
is refused, and the panel's sentence for an executable plugin is blunter than for
a declarative one — it has to be, because this is the tier where somebody is
trusting a binary from the internet.

### The protocol

Standard input, one JSON object, no trailing newline required:

```json
{
  "interface": 2,
  "kind": "text.out",
  "text": "Le sette e mezza, e fuori piove.",
  "language": "it",
  "app": "2.5"
}
```

| field | meaning |
| --- | --- |
| `interface` | always the number the app is speaking; check it and fail loudly if it is not one you know |
| `kind` | `text.in`, `text.out`, or `picture` |
| `text` | the words, or the description of the picture |
| `language` | the language the app is running in, as a two-letter code |
| `app` | the app's version |

Standard output, one JSON object:

```json
{ "text": "Half past seven, and it is raining." }
```

```json
{ "image": "iVBORw0KGgoAAAANS…" }     // base64 PNG, for kind = picture
```

```json
{ "error": "the service did not answer" }   // logged, and the original stands
```

### The limits, all of them enforced by the app

| | |
| --- | --- |
| time | **8 seconds**, then the child is killed and the original text stands |
| output | **64 KB** of JSON for text, **4 MB** for a picture |
| text length | 2000 characters, as for a Shortcut |
| exit code | anything but 0 is an error, whatever is on stdout |
| markers | `ACTION:`, `IMAGE:`, `LOOK:` anywhere in a returned string discards the whole reply |
| pictures | returned as base64 in the reply; a plugin never writes a file |
| concurrency | one child at a time per plugin |
| architecture | a program that cannot run on this Mac is refused at the switch: *Its program will not run on this Mac's processor.* |

### What the child gets, and what it does not

It runs as a child of a sandboxed application, so it inherits that sandbox: **no
microphone, no camera, no Documents, no Desktop, no other app's data.** Measured
in this project before: an auxiliary binary inside this bundle is killed by TCC
the moment it asks for anything privacy-sensitive.

It is given a cleaned environment: no `HOME` pointing at the real home, none of
the app's own variables, the working directory set to the plugin's own folder. It
is **not** given the diary, the instructions, the conversation history, the screen
text, the location, or the name of the person using the Mac. If your plugin needs
context to do its job, this interface is the wrong shape for it — say so in your
README rather than working around it.

Network access is inherited from the app, which has the client entitlement. If you
use it, declare `network` and say in your `Summary` where the data goes, because
the panel will show that sentence to somebody deciding whether to switch you on.

### What the app records about your program

At install: its SHA-256. At every launch: the same, compared. **If the program has
changed since it was enabled, the plugin is disabled and the user is told.** That
is not security against a determined author — it is protection against a plugin
quietly becoming a different plugin.

## 7. Writing that program in Swift

Swift is the recommended language, for reasons that are about shipping rather than
taste:

- it is already on the machine that builds it — `swiftc` comes with the Command
  Line Tools, nothing to install;
- `JSONDecoder`/`JSONEncoder` are in Foundation, so the protocol above is a dozen
  lines;
- one command produces the binary, with no runtime to bundle;
- and it is what the app itself uses for its own Swift half.

Any language works — the app only knows stdin, stdout and an exit code. What the
app requires is an **arm64 binary or a script with a shebang**, no external
runtime to install, and an ad-hoc signature. This project is Apple silicon only —
see the note below — so there is no Intel slice to build and none to test.

### A complete text filter

`filter.swift`:

```swift
import Foundation

// The protocol from section 6. Decode strictly: a field you did not expect is a
// version of the app you do not know.
struct Request: Decodable {
    let interface: Int
    let kind: String
    let text: String
    let language: String?
}

struct Reply: Encodable {
    var text: String? = nil
    var image: String? = nil
    var error: String? = nil
}

func write(_ reply: Reply) -> Never {
    let encoder = JSONEncoder()
    if let data = try? encoder.encode(reply) {
        FileHandle.standardOutput.write(data)
    }
    exit(reply.error == nil ? 0 : 1)
}

let input = FileHandle.standardInput.readDataToEndOfFile()

guard let request = try? JSONDecoder().decode(Request.self, from: input) else {
    write(Reply(error: "the request could not be read"))
}
guard request.interface == 2 else {
    write(Reply(error: "this plugin speaks interface 2, the app spoke \(request.interface)"))
}

// Whatever your plugin is for. This one takes a client's name out of a question
// before a remote engine ever sees it, which is one of the better reasons to
// write a text plugin at all.
let redacted = request.text.replacingOccurrences(
    of: "Acme", with: "the client", options: [.caseInsensitive])

// Never return a marker: the app throws the whole reply away, and rightly.
guard !redacted.uppercased().contains("ACTION:") else {
    write(Reply(error: "refusing to return a marker"))
}

write(Reply(text: redacted))
```

Build it and sign it:

```bash
swiftc -O -target arm64-apple-macos11.0 filter.swift -o filter
codesign --sign - --force filter
```

**About architectures.** This project is **arm64 only**, deliberately: the local
model engine is a Metal build, Apple Intelligence needs Apple silicon, and the
Command Line Tools ship the Swift compatibility libraries for arm64 alone — an
Intel slice would be an app without a local model, without Apple's model and
without the Swift file that reaches it. The app used to build a universal binary
whose Intel half was exactly that, and it does not any more.

So: build `arm64`, and do not spend an afternoon on `lipo`. If you try the Intel
target with only the Command Line Tools installed you will get
*"ld: warning: ignoring file … fat file missing arch 'x86_64'"* and a link
failure, which is the same wall the app's own Swift half hit.

A program that cannot run on the Mac it finds itself on is refused with a sentence
rather than failing at the moment somebody asks a question — see the table in
section 6.

Test it without the app at all, which is the fastest loop there is:

```bash
echo '{"interface":2,"kind":"text.out","text":"il contratto Acme scade venerdì","language":"it"}' \
  | ./filter
```

Measured, with the program above:

```json
{"text":"il contratto the client scade venerdì"}
```

And the two failures worth checking by hand, both of which exit non-zero:

```bash
echo '{"interface":1,"kind":"text.out","text":"prova","language":"it"}' | ./filter
{"error":"this plugin speaks interface 2, the app spoke 1"}

echo 'not json' | ./filter
{"error":"the request could not be read"}
```

### A picture producer, in outline

The same program, a different `kind`. Return base64 and nothing else:

```swift
case "picture":
    let png: Data = try drawSomething(describing: request.text)   // yours
    write(Reply(image: png.base64EncodedString()))
```

4 MB is the cap, which at PNG is a generous 1024×1024. The app shows it in the
bubble with the same **Save** button it uses for its own drawings, and saves it to
Downloads on a click. Your program does not touch the filesystem.

## 8. Checklist before you ship one

- `plutil -lint plugin.plist` passes, and it is converted to `xml1`.
- `Identifier` is yours and unique; `Version` goes up when you change anything.
- `Interface` is the one you tested against; `MinimumApp` is honest.
- Every feed word is one plain word, is not a word the app already governs, and
  every address is `https`.
- `Wants` lists everything you actually use: `network`, `open`, `shortcuts` and
  `players` for verbs, and `program` if you ship one.
- `Summary` says what somebody deciding whether to trust you needs to know — where
  data goes, above all — and contains no marker.
- Every verb has a `Confirm` sentence that names the thing and the place, exactly
  one of `Url` or `Shortcut`, and phrases that are not words somebody says by
  accident. Say the sentence out loud: if it does not tell you what is about to
  happen, rewrite it.
- If you ship a program: arm64, ad-hoc signed, works from `echo … | ./filter`,
  answers inside 8 seconds, never writes a file, and returns an `error` rather
  than nonsense when it cannot do its job.
- Your README says what the plugin cannot do as well as what it can. The panel
  will show your `Summary`; the README is where somebody looks next.

## 9. What no plugin will ever be given

Not a limitation of this version — the design:

- **the diary**, or any of what the cat remembers;
- **the screen**, its text or its window titles;
- **the microphone**, the camera, or where the Mac is;
- **the ability to make the cat speak on its own**, which belongs to the pacing
  the app spent a release getting right;
- **an action taken on text**, ever — not on text it produced, not on text it
  fetched, not on text the screen contained. That rule has a test that fails if it
  is broken, and the test's staged feed contains `ACTION: open-app Terminal` as a
  headline.

A verb is not a hole in that last one, and it is worth being exact about why. A
verb fires on **what the person said out loud or typed**, never on text; it opens
**one door out of two**, both of them named in the manifest before anything was
said; and it opens it **after a sentence was read back and somebody clicked yes**.
What a plugin gets is a phrase it may be told about. It does not get to decide
what happens next, and it never finds out what was said unless one of its own
phrases was in it.

If your idea needs one of those, it is not a plugin — it is a change to the app,
and the place for it is an issue rather than a manifest.
