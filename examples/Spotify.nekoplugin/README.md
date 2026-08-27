# Spotify

Six phrases. They split in two, and the split is the interesting part.

**Searching and playing needs nothing.** "Metti Taylor Swift" opens
`spotify:search:Taylor%20Swift`, which is an address like any other — no
permission, no automation, no Apple events. Spotify comes forward with the search
already done. It does not press play for you: an address cannot, and pretending
otherwise would be worse than saying so.

**Volume, pause and skip need three Shortcuts of your own**, because macOS
publishes no address for them:

| phrase | Shortcut it runs |
| --- | --- |
| alza il volume / volume up | `Neko Volume Up` |
| abbassa il volume / volume down | `Neko Volume Down` |
| pausa / pause the music | `Neko Pause` |
| prossima canzone / next track | `Neko Next Track` |

Make them in the Shortcuts app — *Set Volume*, *Play/Pause*, *Next Track* are all
built-in actions there — and name them exactly as above. A phrase whose Shortcut
does not exist does nothing and says so.

Every one of them is read back before it happens. Neko never acts on a phrase
without showing you the sentence and waiting for a yes, and this plugin cannot opt
out of that: a verb with no `Confirm` line is refused when the manifest is read.
