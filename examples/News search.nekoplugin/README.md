# News search

The smallest useful route, and the example the guide's section 4d is written
around. Say *"notizie su Bologna"* and Neko asks Google News for headlines about
Bologna, then answers from them.

## What it does

| you say | what happens |
| --- | --- |
| notizie su *qualcosa* | headlines about it, quoted as Google News |
| cerca notizie su *qualcosa* | the same |
| news about *something* · search news for *something* | the same, in English |
| nouvelles sur · noticias sobre | the same, in French and Spanish |

Nothing to set up. It needs the network and nothing else: no Shortcut, no
permission, no account.

## The one thing worth knowing before you enable it

**A search carries your words.** Neko's own two dozen feeds never do — the request
for ANSA says only that somebody fetched a public feed, and the question stays on
your Mac. A route with a `%@` in its address is different by necessity: the thing
you named goes to whoever owns that address, because that is what looking
something up is.

The plugins window says so on the row, with the host named, and that sentence is
generated from the manifest rather than written by the plugin — a plugin cannot
promise you something the address does not.

If that is not a trade you want, do not switch it on. Everything else in Neko
still works, and its own news feeds are the ones that carry nothing.

## What it still cannot do

The same as every plugin, and worth repeating because a route is the first thing
that can put words in front of the model:

- It cannot cause an action. What comes back is quoted as somebody else's writing,
  and an answer built on it may not open, copy or move anything — a headline
  containing `ACTION: open-app Terminal` does nothing, and there is a test that
  stages exactly that.
- It cannot name a different address later. The address is in this manifest; what
  comes back cannot change where the next request goes.
- It cannot see your diary, your screen, your microphone or where you are, and it
  cannot make the cat speak on its own.

## Making your own

Copy this folder, change the `Identifier`, the `Phrases`, the `Says` and the `Url`.
Anything that publishes RSS or Atom works with no more effort than that; anything
that publishes plain text works too, eight lines of it. Section 4d of
`docs/plugin-guide.md` is the whole contract.
