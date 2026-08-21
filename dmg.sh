#!/bin/sh
# Builds dist/Neko-<version>.dmg, the disk image users drag the app out of.
#
#   ./dmg.sh                 build the app if needed, then package it
#   ./dmg.sh --sign "Developer ID Application: Name (TEAMID)"
#
# The window layout is arranged by scripting Finder, which needs permission to
# control it. If that is refused or unavailable the image is still produced,
# just without the arranged icons, so the script never fails over decoration.
set -e

APP=build/Neko.app
STAGE_NAME=Neko
BACKGROUND_PNG=packaging/dmg-background.png
BACKGROUND_TIFF=packaging/dmg-background.tiff
OUT_DIR=dist

WINDOW_WIDTH=640
WINDOW_HEIGHT=400
ICON_SIZE=96
# Measured from the clear circles in packaging/dmg-background.png: each is
# 126pt across, centred here. Move the art, move these.
APP_ICON_X=156
APP_ICON_Y=216
DROP_ICON_X=487
DROP_ICON_Y=217

IDENTITY=
while [ $# -gt 0 ]; do
	case $1 in
		--sign) IDENTITY=$2; shift 2 ;;
		*) echo "usage: $0 [--sign IDENTITY]" >&2; exit 2 ;;
	esac
done

# Always rebuild: skipping it when build/Neko.app happens to exist means
# packaging whatever was there before, down to its version number.
./build.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
VOLUME="Neko $VERSION"
DMG="$OUT_DIR/Neko-$VERSION.dmg"
mkdir -p "$OUT_DIR"
rm -f "$DMG"

STAGE=$(mktemp -d /tmp/neko-dmg.XXXXXX)
SCRATCH=$(mktemp -d /tmp/neko-dmg-build.XXXXXX)
RW_DMG=$SCRATCH/rw.dmg
DEVICE=

cleanup() {
	[ -n "$DEVICE" ] && hdiutil detach "$DEVICE" -quiet -force 2>/dev/null || true
	rm -rf "$STAGE" "$SCRATCH"
}
trap cleanup EXIT

# ditto rather than cp: never carry a download quarantine flag into the image,
# it would make Gatekeeper call the copied app damaged.
ditto --noextattr --noqtn "$APP" "$STAGE/$STAGE_NAME.app"
ln -s /Applications "$STAGE/Applications"

# A two representation TIFF wins when present: that is how one file serves both
# a normal and a Retina display.
if [ -f "$BACKGROUND_TIFF" ]; then
	BACKGROUND=$BACKGROUND_TIFF
	BACKGROUND_NAME=background.tiff
elif [ -f "$BACKGROUND_PNG" ]; then
	BACKGROUND=$BACKGROUND_PNG
	BACKGROUND_NAME=background.png
else
	BACKGROUND=
	BACKGROUND_NAME=
	echo "note: no $BACKGROUND_PNG or $BACKGROUND_TIFF, packaging without a background"
fi

# A PNG drawn for Retina is twice the window in pixels, so on its own it would
# only fill the window on a Retina display. Pair it with a downscaled copy in a
# two representation TIFF and one file serves both.
if [ "$BACKGROUND_NAME" = background.png ] && command -v tiffutil >/dev/null; then
	BG_WIDTH=$(sips -g pixelWidth "$BACKGROUND" | awk '/pixelWidth/ { print $2 }')
	if [ "${BG_WIDTH:-0}" -ge $(( WINDOW_WIDTH * 2 )) ]; then
		sips -z $(( WINDOW_HEIGHT )) $(( WINDOW_WIDTH )) "$BACKGROUND" \
			--out "$SCRATCH/background-1x.png" >/dev/null
		if tiffutil -cathidpicheck "$SCRATCH/background-1x.png" "$BACKGROUND" \
			-out "$SCRATCH/background.tiff" >/dev/null 2>&1; then
			BACKGROUND=$SCRATCH/background.tiff
			BACKGROUND_NAME=background.tiff
			echo "paired the ${BG_WIDTH}px background with a 1x copy for Retina"
		fi
	fi
fi

if [ -n "$BACKGROUND" ]; then
	mkdir "$STAGE/.background"
	ditto --noextattr --noqtn "$BACKGROUND" "$STAGE/.background/$BACKGROUND_NAME"
fi

# HFS+ because that is what Finder can arrange, plus 20MB of slack so the
# read-write stage has room for the .DS_Store Finder writes.
SIZE=$(( $(du -sm "$STAGE" | cut -f1) + 20 ))
hdiutil create -quiet -srcfolder "$STAGE" -volname "$VOLUME" \
	-fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size "${SIZE}m" "$RW_DMG"

# hdiutil warns that it is deprecated in favour of `diskutil image`, which only
# exists on very recent macOS. hdiutil still works everywhere, so it stays.
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" 2>/dev/null |
	awk '/^\/dev\// { print $1; exit }')
MOUNT="/Volumes/$VOLUME"

layout() {
	osascript - "$VOLUME" "$WINDOW_WIDTH" "$WINDOW_HEIGHT" "$ICON_SIZE" \
		"$APP_ICON_X" "$APP_ICON_Y" "$DROP_ICON_X" "$DROP_ICON_Y" "$STAGE_NAME" \
		"$BACKGROUND_NAME" <<'APPLESCRIPT'
on run argv
	set volumeName to item 1 of argv
	set windowWidth to (item 2 of argv) as integer
	set windowHeight to (item 3 of argv) as integer
	set iconSize to (item 4 of argv) as integer
	set appX to (item 5 of argv) as integer
	set appY to (item 6 of argv) as integer
	set dropX to (item 7 of argv) as integer
	set dropY to (item 8 of argv) as integer
	set appName to (item 9 of argv) & ".app"
	set backgroundName to item 10 of argv

	tell application "Finder"
		tell disk volumeName
			open
			set current view of container window to icon view
			set toolbar visible of container window to false
			set statusbar visible of container window to false
			set the bounds of container window to {200, 120, 200 + windowWidth, 120 + windowHeight}
			set viewOptions to the icon view options of container window
			set arrangement of viewOptions to not arranged
			set icon size of viewOptions to iconSize
			if backgroundName is not "" then
				try
					set background picture of viewOptions to file (".background:" & backgroundName)
				end try
			end if
			set position of item appName of container window to {appX, appY}
			set position of item "Applications" of container window to {dropX, dropY}
			close
			open
			update without registering applications
			delay 2
			close
		end tell
	end tell
end run
APPLESCRIPT
}

if layout >/dev/null 2>&1; then
	echo "arranged the window with Finder"
else
	echo "note: could not script Finder, packaging without an arranged window"
	echo "      (grant the terminal permission to control Finder in"
	echo "       System Settings > Privacy & Security > Automation)"
fi

# Make the volume read-only-friendly and let Finder flush its .DS_Store.
chmod -Rf go-w "$MOUNT" 2>/dev/null || true
sync

hdiutil detach "$DEVICE" -quiet
DEVICE=

hdiutil convert "$RW_DMG" -quiet -format UDZO -imagekey zlib-level=9 -o "$DMG"

if [ -n "$IDENTITY" ]; then
	codesign --sign "$IDENTITY" --timestamp "$DMG"
	echo "signed with $IDENTITY"
fi

hdiutil verify -quiet "$DMG"
echo "built $DMG ($(du -h "$DMG" | cut -f1))"

cat <<'NOTE'

Distribution note: an ad-hoc signed app inside a downloaded image is refused by
Gatekeeper as damaged. To hand this to someone else, build with
--sign "Developer ID Application: ..." and notarise:

    xcrun notarytool submit dist/Neko-<version>.dmg --apple-id ... --team-id ... --wait
    xcrun stapler staple dist/Neko-<version>.dmg
NOTE
