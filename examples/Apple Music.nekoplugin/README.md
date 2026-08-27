# Apple Music

The same shape as the Spotify example, and the same split.

**Searching needs nothing**: "metti Battisti" opens
`music://music.apple.com/search?term=Battisti`, and Musica comes forward with the
search done. An address cannot press play, and this plugin does not claim it can.

**Volume, pause and skip need three Shortcuts of your own** — `Neko Volume Up`,
`Neko Volume Down`, `Neko Pause`, `Neko Next Track` — because macOS publishes no
address for them. Build them from the Shortcuts app's own media actions.

Both this and the Spotify example use the same Shortcut names on purpose: they do
the same job, and you only have to make them once. Enable one of the two, not
both — whichever you enable first wins a phrase they share, and having both switched
on means "metti" is decided by the order they were read in, which is not a thing to
leave to chance.
