#!/bin/bash
#
# Run every Scanly test bundle against an iOS Simulator destination.
# Drives three schemes — the app target plus each local package — so
# the package tests don't have to be wired into the app scheme to be
# picked up by CI / a one-line manual invocation.
#
# Usage: ./scripts/test.sh                    # auto-picks first iPhone sim
#        ./scripts/test.sh "iPhone 17 Pro"    # explicit device name

set -euo pipefail

cd "$(dirname "$0")/.."

if [ $# -ge 1 ]; then
    SIMULATOR="$1"
else
    SIMULATOR=$(xcrun simctl list devices available \
        | grep -E "iPhone.*\(" \
        | head -1 \
        | sed 's/^[[:space:]]*//' \
        | sed 's/ (.*$//')
fi

if [ -z "$SIMULATOR" ]; then
    echo "error: no iPhone simulator found" >&2
    exit 1
fi

DESTINATION="platform=iOS Simulator,name=$SIMULATOR"

echo "==> Running on '$SIMULATOR'"
echo

echo "==> Scanly (app target)"
xcodebuild test \
    -project Scanly.xcodeproj \
    -scheme Scanly \
    -destination "$DESTINATION" \
    CODE_SIGNING_ALLOWED=NO

echo
echo "==> ScanlyEngine"
( cd ScanlyEngine && xcodebuild test \
    -scheme ScanlyEngine \
    -destination "$DESTINATION" \
    CODE_SIGNING_ALLOWED=NO )

echo
echo "==> ScanlyUI"
( cd ScanlyUI && xcodebuild test \
    -scheme ScanlyUI \
    -destination "$DESTINATION" \
    CODE_SIGNING_ALLOWED=NO )

echo
echo "==> All test bundles passed"
