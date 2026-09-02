#!/bin/sh
# Runs the measurements this project's claims rest on.
#
#   tests/run.sh          -> every harness
#   tests/run.sh rate     -> only the ones whose name matches
#   tests/run.sh --slow   -> also the ones that take minutes (a model, a wait)
#
# Each harness is built as a second executable inside build/Neko.app so that the
# bundle's own resources and localizations are what it sees — several of these
# measure Italian strings, and a harness outside the bundle silently gets
# English. arm64 only: the tests run on the machine that builds them.
set -e
cd "$(dirname "$0")/.."

APP=build/Neko.app
[ -x "$APP/Contents/MacOS/Neko" ] || { echo "build it first: ./build.sh"; exit 1; }

SDK=$(xcrun --show-sdk-path)
LLAMA_CACHE="$HOME/Library/Caches/neko-llama/b10581"
SLOW=no
MATCH=""
for ARG in "$@"; do
	case "$ARG" in
		--slow) SLOW=yes ;;
		*) MATCH="$MATCH $ARG" ;;
	esac
done

# Everything but main.m: a harness brings its own.
SOURCES=$(sed -n '/^SOURCES="/,/"$/p' build.sh | tr '\n' ' ' \
	| sed -e 's/^SOURCES="//' -e 's/"//g' -e 's|src/main.m||')

OBJECTS=$(mktemp -d /tmp/neko-tests.XXXXXX)
# A diary of its own. Three harnesses write notes, and they used to write them in
# the real one: that is how "zzq-test" ended up being said out loud, written down
# as "test zqqmark", and carried into every prompt for a week. See NekoMemory.h.
MEMORY=$(mktemp -d /tmp/neko-diary.XXXXXX)

# And a models directory the harnesses can actually see. They run unsandboxed and
# look in ~/Library/Application Support; the application looks inside its
# container, so the arm of tests/think.m that asks every installed model a
# question — the one check that would have caught a <think> block reaching a
# speech bubble — found nothing to ask and measured nothing.
#
# Hard links, not copies and not symlinks. Not copies because a model is two or
# three gigabytes. Not symlinks because -attributesOfItemAtPath: does not follow
# one, so the store measured the length of a path instead of the length of a
# model, called it an unfinished download, and reported no models again. A hard
# link is the same bytes under a second name, and removing it leaves the
# original alone.
MODELS=$(mktemp -d /tmp/neko-models.XXXXXX)
for WHERE in "$HOME/Library/Application Support/Neko/Models" \
             "$HOME/Library/Containers/com.nekomac.neko/Data/Library/Application Support/Neko/Models"; do
	[ -d "$WHERE" ] || continue
	for GGUF in "$WHERE"/*.gguf; do
		[ -e "$GGUF" ] || continue
		ln -f "$GGUF" "$MODELS/$(basename "$GGUF")" 2>/dev/null \
			|| ln -sf "$GGUF" "$MODELS/$(basename "$GGUF")"
	done
done
FOUND=$(ls "$MODELS" 2>/dev/null | wc -l | tr -d ' ')
echo "$FOUND model(s) linked for the slow arms"
trap 'rm -rf "$OBJECTS" "$MEMORY" "$MODELS"; rm -f "$APP/Contents/MacOS/neko-test"' EXIT

echo "compiling the app once for all of them…"
for SOURCE in $SOURCES; do
	clang -arch arm64 -fno-objc-arc -fblocks -O0 -isysroot "$SDK" \
		-mmacosx-version-min=11.0 -Wno-deprecated-declarations \
		-c "$SOURCE" -o "$OBJECTS/$(basename "$SOURCE" .m).o"
done
clang++ -arch arm64 -fno-objc-arc -x objective-c++ -std=c++17 -O2 -isysroot "$SDK" \
	-mmacosx-version-min=11.0 -Isrc -I"$LLAMA_CACHE/src/include" \
	-I"$LLAMA_CACHE/src/ggml/include" \
	-c src/NekoLlamaEngine.mm -o "$OBJECTS/NekoLlamaEngine.o"
swiftc -target arm64-apple-macos11.0 -sdk "$SDK" -O -parse-as-library \
	-c src/NekoAppleModel.swift -o "$OBJECTS/NekoAppleModel.o"
LLAMA_LINK=$(find "$LLAMA_CACHE/build" -name 'libllama.a' -o -name 'libggml*.a' | tr '\n' ' ')

FAILED=""
for HARNESS in tests/*.m; do
	NAME=$(basename "$HARNESS" .m)
	[ "$NAME" = "line" ] && continue          # its own bundle, below
	if [ -n "$MATCH" ]; then
		echo "$MATCH" | tr ' ' '\n' | grep -qx "$NAME" || continue
	fi

	clang -arch arm64 -fno-objc-arc -fblocks -O0 -isysroot "$SDK" -Isrc -Itests \
		-mmacosx-version-min=11.0 -Wno-deprecated-declarations \
		-c "$HARNESS" -o "$OBJECTS/harness.o"
	swiftc -target arm64-apple-macos11.0 -sdk "$SDK" \
		"$OBJECTS"/*.o $LLAMA_LINK -lc++ \
		-framework Metal -framework MetalKit -framework Accelerate \
		-framework Cocoa -framework ServiceManagement -framework Carbon \
		-framework Security -framework AVFoundation -framework NaturalLanguage \
		-framework IOKit -framework CoreLocation -framework FoundationModels \
		-framework CoreAudio \
		-Xlinker -weak_framework -Xlinker Speech \
		-o "$APP/Contents/MacOS/neko-test" || {
		# Not 2>/dev/null. A link error used to disappear here and the script
		# simply stopped, printing nothing after "compiling" — which reads as a
		# hang rather than as the missing framework it was.
		echo "could not link $NAME — see the error above" >&2
		FAILED="$FAILED $NAME"
		continue
	}
	codesign --sign - --force "$APP/Contents/MacOS/neko-test" 2>/dev/null

	echo ""
	echo "=============== $NAME ==============="
	SLOW_ARG=""
	[ "$SLOW" = yes ] && SLOW_ARG="-slow 1"
	# Settings arrive as arguments: NSUserDefaults reads those before anything
	# saved, so a test says what it needs without touching what the user chose.
	if "$APP/Contents/MacOS/neko-test" $SLOW_ARG \
		-NekoAskEnabled 1 -NekoAskFollowUp 1 -NekoAskProvider apple \
		-NekoMemoryDirectory "$MEMORY" -NekoModelsDirectory "$MODELS" 2>/dev/null; then
		:
	else
		FAILED="$FAILED $NAME"
	fi
	rm -f "$APP/Contents/MacOS/neko-test"
done

# The typed line has to be measured from a real application bundle: LaunchServices
# will not activate anything else, and without activation nothing is ever key.
if [ -z "$MATCH" ] || echo "$MATCH" | tr ' ' '\n' | grep -qx line; then
	echo ""
	echo "=============== line ==============="
	LINEAPP="$OBJECTS/LineTest.app"
	mkdir -p "$LINEAPP/Contents/MacOS"
	cat > "$LINEAPP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>LineTest</string>
<key>CFBundleIdentifier</key><string>com.nekomac.linetest</string>
<key>CFBundleName</key><string>LineTest</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
	clang -arch arm64 -fno-objc-arc -fblocks -O0 -isysroot "$SDK" -Isrc -Itests \
		-mmacosx-version-min=11.0 tests/line.m src/NekoLine.m \
		-framework Cocoa -o "$LINEAPP/Contents/MacOS/LineTest"
	codesign --sign - --force "$LINEAPP" 2>/dev/null
	REPORT="$HOME/Library/Caches/neko-linetest.txt"
	rm -f "$REPORT"
	open "$LINEAPP"
	SPENT=0
	while [ ! -f "$REPORT" ] && [ "$SPENT" -lt 20 ]; do sleep 1; SPENT=$((SPENT + 1)); done
	if [ -f "$REPORT" ]; then
		cat "$REPORT"
		grep -q "^FAIL" "$REPORT" && FAILED="$FAILED line"
	else
		echo "---   nothing came back: this one needs a logged-in session"
	fi
fi

echo ""
if [ -n "$FAILED" ]; then
	echo "failed:$FAILED"
	exit 1
fi
echo "all of them passed"
