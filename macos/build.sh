#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/build/Auto Session Start.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -O -swift-version 5 -target "$(uname -m)-apple-macosx13.0" -module-cache-path "$PWD/build/ModuleCache" GreetingScheduler/*.swift -o "$APP/Contents/MacOS/AutoSessionStart"
cp GreetingScheduler/Resources/AppIcon.icns "$APP/Contents/Resources/"
cp GreetingScheduler/Resources/runner.sh "$APP/Contents/Resources/"
cp GreetingScheduler/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "$APP"
