# Wikipedia

The example the routes section of the guide is written around, and the one that
answers a question rather than fetching a list. Say *"chi è Alan Turing"* and Neko
asks Wikipedia for the opening of the article, then answers from it — quoting it
as Wikipedia's words, because they are.

## What it hears

| you say | what it looks up |
| --- | --- |
| chi è · chi era · che cos'è · cosa sono · parlami di | the thing you named |
| cerca su wikipedia *qualcosa* | likewise |
| who is · what is · tell me about | in English |
| qui est · qu'est-ce que · parle-moi de | in French |
| quién es · qué es · háblame de | in Spanish |

Nothing to set up: it needs the network and nothing else. No Shortcut, no account,
no permission.

## The one thing worth knowing before you enable it

**A search carries your words.** Neko's own two dozen feeds never do — the request
for ANSA says only that somebody fetched a public feed, and the question stays on
your Mac. A route with a `%@` in its address is different by necessity: the thing
you named goes to whoever owns that address, because that is what looking
something up *is*.

The plugins window says so on the row, with the host named, and that sentence is
generated from this manifest rather than written by it — a plugin cannot promise
you what its own address does not do.

## What comes back, and what it cannot do

Wikipedia's summary endpoint answers in JSON, and Neko reads the title, the
description and the extract out of it by a closed list of field names. The URLs,
the image sizes and the rest of the plumbing are left where they are.

It arrives marked as text from outside, which means an answer built on it may not
open, copy or move anything, whatever the article says. There is a test that
stages a reply containing `ACTION: open-app Terminal` and counts Terminals.

## Making it yours

The address is Italian. For another language change `it.wikipedia.org` to
`en.`, `fr.` or `es.` — or copy the folder, change the `Identifier` and the
phrases, and keep both. Anything that publishes RSS, Atom, JSON with a readable
field, or plain text works the same way; section 4d of `docs/plugin-guide.md` is
the whole contract.
