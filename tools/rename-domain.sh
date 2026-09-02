#!/bin/sh
# Moves everything Neko keeps from the old bundle identifier to the new one.
#
#   tools/rename-domain.sh              says what it would move, and moves nothing
#   tools/rename-domain.sh --go         moves it
#
# 2.14 changed CFBundleIdentifier from com.yourcompany.neko — a placeholder that
# had been there since 2007 — to com.nekomac.neko. That is a one-line change to a
# plist and it silently orphans four things, because macOS keys all of them to the
# identifier and not to the name:
#
#     the settings          which character, which engine, which model
#     the diary             Memory/, including facts.txt and synonyms.txt
#     the models            2.6 GB of them on the machine this was written on
#     the plugins           whatever was dropped in
#
# A sandboxed application cannot read another application's container, so it
# cannot do this for itself. That is the whole reason this file exists rather
# than a migration in NekoController.
#
# **The permissions do not come across, and nothing can bring them.** The
# microphone, Accessibility and Automation are granted to an application's
# identity; to macOS the new identifier is a different application that has never
# asked. They have to be granted again, which the Permissions tab will say by
# itself the first time it looks.
#
# Order matters, and the script enforces it: launch the new build **once** so the
# system creates its container properly — a container is not just a folder, it
# carries metadata the sandbox writes — then quit it, then run this.
set -e

OLD=com.yourcompany.neko
NEW=com.nekomac.neko
GO=no
[ "$1" = "--go" ] && GO=yes

OLDDIR="$HOME/Library/Containers/$OLD/Data/Library/Application Support/Neko"
NEWDIR="$HOME/Library/Containers/$NEW/Data/Library/Application Support/Neko"
OLDPREFS="$HOME/Library/Containers/$OLD/Data/Library/Preferences/$OLD.plist"

if pgrep -f "Neko.app/Contents/MacOS/Neko" >/dev/null 2>&1; then
	echo "Neko is running. Quit it from its own menu first — this moves the files"
	echo "underneath it, and a process holding them open is how one gets half moved."
	exit 1
fi

if [ ! -d "$HOME/Library/Containers/$NEW" ]; then
	echo "There is no container for $NEW yet."
	echo ""
	echo "Launch the new build once and quit it, then run this again. The system"
	echo "makes the container itself, with metadata a plain mkdir does not write —"
	echo "creating it by hand is how an application ends up with no container at all."
	exit 1
fi

echo "from  $OLD"
echo "to    $NEW"
echo ""

MOVED=0
for PART in Memory Models Plugins Images; do
	FROM="$OLDDIR/$PART"
	TO="$NEWDIR/$PART"
	[ -d "$FROM" ] || continue
	SIZE=$(du -sh "$FROM" 2>/dev/null | cut -f1)
	if [ -d "$TO" ] && [ -z "$(ls -A "$TO" 2>/dev/null)" ]; then
		# An empty folder is not a diary. Launching the new build once — which
		# this script insists on, so the system makes the container properly —
		# creates these empty, and refusing to move on account of them was the
		# first thing that went wrong when this was used.
		echo "  move    $PART ($SIZE) — over an empty folder the first launch made"
		MOVED=$((MOVED + 1))
		if [ "$GO" = yes ]; then
			rmdir "$TO"
			mv "$FROM" "$TO"
		fi
		continue
	fi
	if [ -e "$TO" ]; then
		echo "  keep    $PART — the new one already has something in it, and this"
		echo "                  script will not merge two diaries or two model"
		echo "                  folders. Look in both and move it yourself:"
		echo "                    $TO"
		continue
	fi
	echo "  move    $PART ($SIZE)"
	MOVED=$((MOVED + 1))
	if [ "$GO" = yes ]; then
		mkdir -p "$NEWDIR"
		mv "$FROM" "$TO"
	fi
done

if [ -f "$OLDPREFS" ]; then
	echo "  copy    the settings — which character, which engine, which model"
	if [ "$GO" = yes ]; then
		# Through defaults rather than by copying the file: cfprefsd caches these,
		# and a plist moved underneath it is a plist that gets overwritten again.
		defaults export "$OLD" - | defaults import "$NEW" -
	fi
else
	echo "  none    no settings found for the old identifier"
fi

echo ""
if [ "$GO" != yes ]; then
	echo "Nothing was moved. Run it again with --go."
	exit 0
fi

echo "Done. Two things left, and only you can do them:"
echo ""
echo "  1. The permissions have to be granted again — to macOS this is an"
echo "     application that has never asked. Neko opens the Permissions tab by"
echo "     itself a few seconds after it starts when something is switched on"
echo "     that it is not allowed to do."
echo "  2. The old container is still there, emptied of what mattered:"
echo "        $HOME/Library/Containers/$OLD"
echo "     Look inside before removing it. This script does not delete anything."
