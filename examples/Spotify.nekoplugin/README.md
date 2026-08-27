# Spotify

Six phrases. They split in two, and the split is the interesting part.

**Searching needs nothing.** "Metti Taylor Swift" opens
`spotify:search:Taylor%20Swift`, which is an address like any other — no
permission, no automation, no Apple events. It does not press play for you: an
address cannot, and pretending otherwise would be worse than saying so.

That URI is Spotify's own documented one, and unlike the Apple Music example's it
has **not** been verified here — the attempt ran into Spotify's first-run
local-network prompt and was left alone. If it comes forward without the search
done, it is the same failure Apple Music had, and the fix is the same: make the
search a Shortcut. Say so and it will be changed.

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
