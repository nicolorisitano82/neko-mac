# Apple Music

The same shape as the Spotify example, with one measured difference.

## Searching needs a Shortcut, and here is why

The obvious thing to do is open `music://music.apple.com/search?term=Battisti`, and
that is what version 1.0 of this example did. It does not work. Opened on macOS 26,
Musica comes forward, selects **Cerca** — and the search field is empty: the app
honours the path of the link and throws the query away. Forcing the web address
into Musica instead (`https://music.apple.com/it/search?term=…`) lands on the same
empty page.

So this example does not pretend. Searching runs a Shortcut of yours, the same way
the volume does, and the words you said are handed to it as input.

## The five Shortcuts

Make them in the Shortcuts app, with these exact names:

| name | what it does | how to build it |
| --- | --- | --- |
| `Neko Play Music` | plays what you asked for | **Find Music** where *Title contains* → Shortcut Input, then **Play Music** |
| `Neko Volume Up` | louder | **Set Volume** to *Current Volume + 10%* |
| `Neko Volume Down` | quieter | the same, minus |
| `Neko Pause` | stops | **Pause** (Play/Pause) |
| `Neko Next Track` | skips | **Skip Forward** |

Every one of them takes no setting up beyond that, and Neko never sees what they
do — it asks Shortcuts to run one by name and is told nothing back.

## What needs nothing

`metti la radio` opens `music://music.apple.com/radio`, which is a path with no
query and does work. That is the whole of what an address buys here.

## Both examples use the same names on purpose

They do the same job, so you only make them once. **Enable one of the two, not
both**: they share phrases, and with both switched on which one answers "metti"
depends on the order they were read in, which is not a thing to leave to chance.
