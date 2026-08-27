# Spotify

Nothing to set up. Switch it on, allow Neko to control Spotify when macOS asks,
and say things.

| you say | what happens |
| --- | --- |
| alza il volume · più forte · volume up | Spotify's own volume, ten points up |
| abbassa il volume · più piano · quieter | ten points down |
| metti in pausa · pausa · ferma la musica | pause |
| riprendi · resume | play |
| prossima canzone · salta questa · next track | skip |
| canzone precedente · torna indietro | back |
| metti Taylor Swift · play Taylor Swift | opens the search in Spotify |

Neko speaks to Spotify directly, through the scripting dictionary Spotify
publishes. There is no Shortcut to build.

## The one honest limit

**"Metti X" opens a search rather than playing.** Spotify's dictionary can play a
URI it is handed and cannot search for one; nothing outside Spotify can search
Spotify. So that verb uses `spotify:search:` — Spotify's own address — which
brings its window forward with the search done, and you press play.

Everything else is a real command and happens where you are.

## macOS asks once

The first command brings up *"Vuoi consentire a Neko di controllare Spotify?"*.
Say no and nothing here works until you change it in Privacy & Security →
Automation; Neko's Permissions tab has a button that takes you there.

Spotify may also ask you, on its own first launch, to find devices on the local
network. That prompt is Spotify's and has nothing to do with Neko.

## What it cannot do

See what you are playing, read your playlists, or tell anybody anything. It sends
one of a fixed list of commands and hears back only whether it worked.

Enable this **or** the Apple Music example, not both: they answer the same
sentences, and with both on, *"alza il volume"* is decided by the order they were
read in.
