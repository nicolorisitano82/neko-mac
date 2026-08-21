#!/bin/sh
# Builds Neko.app without Xcode (Command Line Tools are enough).
#   ./build.sh            -> build/Neko.app
#   ./build.sh install    -> also copies it to ~/Applications/Neko.app
set -e

APP=build/Neko.app
SDK=$(xcrun --show-sdk-path)
SCRATCH=$(mktemp -d /tmp/neko-build.XXXXXX)
trap 'rm -rf "$SCRATCH"' EXIT

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

# One architecture at a time, because the Swift half can only target one at a
# time, and lipo puts them back together. Swift is here for a single file:
# FoundationModels ships no headers, so Apple's on-device model can only be
# reached from Swift.
SOURCES="src/main.m src/MyView.m src/MyPanel.m src/NekoCharacter.m src/NekoController.m
	src/NekoAnswerProvider.m src/NekoShortcutProvider.m src/NekoModelProvider.m
	src/NekoAppleProvider.m src/NekoHotKey.m src/NekoListener.m src/NekoBubble.m
	src/NekoAsk.m"
FRAMEWORKS="-framework Cocoa -framework ServiceManagement -framework Carbon
	-framework Security -framework AVFoundation
	-Xlinker -weak_framework -Xlinker Speech"
DEPLOYMENT=11.0
SLICES=""

for ARCH in arm64 x86_64; do
	SLICE=$SCRATCH/$ARCH
	mkdir -p "$SLICE"
	for SOURCE in $SOURCES; do
		clang -arch "$ARCH" -fno-objc-arc -fblocks -O2 -isysroot "$SDK" \
			-mmacosx-version-min=$DEPLOYMENT -Wno-deprecated-declarations \
			-c "$SOURCE" -o "$SLICE/$(basename "$SOURCE" .m).o"
	done
	if [ "$ARCH" = arm64 ]; then
		# -parse-as-library: without it a lone Swift file is treated as a script
		# and brings its own main().
		swiftc -target "$ARCH-apple-macos$DEPLOYMENT" -sdk "$SDK" -O -parse-as-library \
			-c src/NekoAppleModel.swift -o "$SLICE/NekoAppleModel.o"
		# Linked by swiftc, which knows where the Swift runtime lives.
		swiftc -target "$ARCH-apple-macos$DEPLOYMENT" -sdk "$SDK" \
			"$SLICE"/*.o $FRAMEWORKS -framework FoundationModels -o "$SLICE/Neko"
	else
		# No Swift in the Intel slice: the Command Line Tools ship the Swift
		# compatibility libraries for arm64 only. Nothing is lost — Apple
		# Intelligence needs Apple silicon anyway — and the provider already
		# reports itself unavailable when the class is missing.
		clang -arch "$ARCH" -isysroot "$SDK" -mmacosx-version-min=$DEPLOYMENT \
			"$SLICE"/*.o $FRAMEWORKS -o "$SLICE/Neko"
	fi
	SLICES="$SLICES $SLICE/Neko"
done

lipo -create $SLICES -output "$APP/Contents/MacOS/Neko"

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
