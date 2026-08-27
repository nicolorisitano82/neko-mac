# Apple Music

Nothing to set up. Switch it on, allow Neko to control Musica when macOS asks, and
say things.

| you say | what happens |
| --- | --- |
| alza il volume · più forte · volume up | Musica's own volume, ten points up |
| abbassa il volume · più piano · quieter | ten points down |
| metti in pausa · pausa · ferma la musica | pause |
| riprendi · resume | play |
| prossima canzone · salta questa · next track | skip |
| canzone precedente · torna indietro | back |
| metti Battisti · play something by Battisti | plays it **from your library** |
| metti la radio | opens Apple Music radio |

Neko speaks to Musica directly, through the scripting dictionary Apple publishes
for it. There is no Shortcut to build and no address that only half works.

## The two honest limits

**"Metti X" plays from your own library.** Musica's dictionary can look through
what you have; it cannot search the streaming catalogue, and nothing outside
Musica can. Neko tries the artist first and then the title, and when there is no
match it says so — *"nella tua libreria non c'è niente di Battisti"* — rather than
opening a window and leaving you to it.

That limit was measured, not assumed. `music://music.apple.com/search?term=…`
brings Musica forward, selects **Cerca**, and leaves the field empty: the app
honours the path and drops the query. An earlier version of this example shipped
that address, which is exactly the sort of thing this file now records.

**macOS asks once.** The first command brings up *"Vuoi consentire a Neko di
controllare Musica?"*. Say no and nothing here works until you change it in
Privacy & Security → Automation; Neko's Permissions tab has a button that takes
you there.

## What it cannot do

Read your library, know what you listen to, or tell anybody anything about it. It
sends one of eight commands and hears back only whether the command worked.

Enable this **or** the Spotify example, not both: they answer the same sentences,
and with both on, *"alza il volume"* is decided by the order they were read in.
