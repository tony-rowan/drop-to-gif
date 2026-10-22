#!/usr/bin/env bash
# Builds a release "Drop to GIF.app" into ./build and ad-hoc signs it.
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release --arch arm64 --arch x86_64
binary="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/DropToGif"

app="build/Drop to GIF.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/DropToGif"
cp Support/Info.plist "$app/Contents/Info.plist"

codesign --force --sign - "$app"

echo "Built $app"
