#!/bin/sh
# Builds Neko.app without Xcode (Command Line Tools are enough).
#   ./build.sh            -> build/Neko.app
#   ./build.sh install    -> also copies it to ~/Applications/Neko.app
set -e

APP=build/Neko.app
SDK=$(xcrun --show-sdk-path)

# A quarantine flag on the source tree (it is inherited by everything a browser
# downloads) makes Gatekeeper report the built app as damaged and kill it.
if xattr "$PWD" 2>/dev/null | grep -q com.apple.quarantine; then
	echo "warning: $PWD is quarantined, the app will not launch from here."
	echo "         fix with: xattr -dr com.apple.quarantine \"$PWD\""
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

sed -e 's/${PRODUCT_NAME}/Neko/g' -e 's/${EXECUTABLE_NAME}/Neko/g' \
	Info.plist > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# --noqtn/--noextattr: never carry a download quarantine into the bundle.
ditto --noextattr --noqtn Resources "$APP/Contents/Resources"

clang -arch arm64 -arch x86_64 -fno-objc-arc -O2 \
	-isysroot "$SDK" -mmacosx-version-min=10.13 \
	-Wno-deprecated-declarations \
	-framework Cocoa -framework ServiceManagement -framework Carbon \
	-framework Security -framework AVFoundation -weak_framework Speech \
	-o "$APP/Contents/MacOS/Neko" \
	src/main.m src/MyView.m src/MyPanel.m src/NekoCharacter.m src/NekoController.m \
	src/NekoAnswerProvider.m src/NekoShortcutProvider.m src/NekoModelProvider.m \
	src/NekoHotKey.m src/NekoListener.m src/NekoBubble.m src/NekoAsk.m

xattr -cr "$APP"
codesign --sign - --entitlements Neko.entitlements --force "$APP"
codesign --verify --strict "$APP"
echo "built $APP"

if [ "$1" = install ]; then
	DEST=$HOME/Applications/Neko.app
	mkdir -p "$HOME/Applications"
	rm -rf "$DEST"
	ditto --noextattr --noqtn "$APP" "$DEST"
	xattr -cr "$DEST"
	codesign --sign - --entitlements Neko.entitlements --force "$DEST"
	echo "installed $DEST"
fi
