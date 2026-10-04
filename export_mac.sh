#!/bin/sh
# Builds a fresh double-clickable Mac app: build/mac/The Prismatic Descent.app
# Usage: ./export_mac.sh        (add "open" to open the folder afterwards: ./export_mac.sh open)
set -e
cd "$(dirname "$0")"
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
mkdir -p build/mac
rm -rf "build/mac/The Prismatic Descent.app" build/mac/PrismaticDescent.zip
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "macOS" build/mac/PrismaticDescent.zip
ditto -x -k build/mac/PrismaticDescent.zip build/mac
APP=$(ls -d build/mac/*.app | head -1)
mv "$APP" "build/mac/The Prismatic Descent.app" 2>/dev/null || true
rm -f build/mac/PrismaticDescent.zip
# Re-sign the finished bundle (ad-hoc, free, local) so macOS sees one consistent signature.
codesign --force --deep --sign - "build/mac/The Prismatic Descent.app" >/dev/null 2>&1 || echo "note: ad-hoc signing skipped"
echo "Built: $(pwd)/build/mac/The Prismatic Descent.app"
[ "$1" = "open" ] && open build/mac
exit 0
