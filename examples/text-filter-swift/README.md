# A text filter in Swift

The worked example from [docs/plugin-guide.md](../../docs/plugin-guide.md), section
7: a command-line program that speaks the plugin protocol on stdin and stdout.
It takes a client's name out of a question before a remote engine ever sees it.

It is **not a plugin folder**, and deliberately so: the executable interface it
speaks is `Interface 2`, which the app refuses today with *"It was written for a
newer version of Neko's plugin interface."* This is here so the contract can be
written against, and tested, before any of it ships.

## Build and try it

```sh
swiftc -O -target arm64-apple-macos11.0 filter.swift -o filter
codesign --sign - --force filter

echo '{"interface":2,"kind":"text.out","text":"il contratto Acme scade venerdì","language":"it"}' | ./filter
```

```json
{"text":"il contratto the client scade venerdì"}
```

Both failures exit non-zero, which is what the app will read:

```sh
echo '{"interface":1,"kind":"text.out","text":"prova","language":"it"}' | ./filter
echo 'not json' | ./filter
```

With only the Command Line Tools installed the Intel slice will not link — they
ship the Swift compatibility libraries for arm64 alone. The guide says what to do
about that.
