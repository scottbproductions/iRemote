#!/bin/sh
# UM fork: build, sign with the stable local identity, install to /Applications.
# A stable signature keeps the Accessibility grant across rebuilds (an
# ad-hoc signature is pinned to one build's cdhash, so every rebuild lost it).
set -eu
cd "$(dirname "$0")/.."
D="$HOME/.config/um-codesign"; KC="$D/um-codesign.keychain-db"
ID="FB139240514124AF4E0B507CDEF522BBFB151F25"   # "UM Local Code Signing"
DD="$HOME/.claude-tmp/iRemote-DD"
APP="$DD/Build/Products/Release/iRemote.app"
xcodegen generate >/dev/null 2>&1 || "$HOME/.claude-tmp/xcodegen-dl/xcodegen/bin/xcodegen" generate >/dev/null
DEVELOPER_DIR=/Applications/Xcode-15.2.0.app/Contents/Developer \
  xcodebuild -project iRemote.xcodeproj -scheme iRemote -configuration Release -derivedDataPath "$DD" build >/tmp/iremote-build.log 2>&1 \
  || { tail -20 /tmp/iremote-build.log; exit 1; }
codesign -d --entitlements :- "$APP" > /tmp/iremote-ent.plist 2>/dev/null
security unlock-keychain -p "$(cat "$D/keychain.pw")" "$KC"
ORIG=$(security list-keychains -d user | tr -d '"' | xargs)
security list-keychains -d user -s $ORIG "$KC"
trap 'security list-keychains -d user -s $ORIG' EXIT
codesign --force --deep --options runtime --timestamp=none --entitlements /tmp/iremote-ent.plist -s "$ID" "$APP"
codesign --verify --deep "$APP"
osascript -e 'tell application id "io.github.jono-shaw.iRemote" to quit' 2>/dev/null || true
sleep 1
rm -rf /Applications/iRemote.app
ditto "$APP" /Applications/iRemote.app
open /Applications/iRemote.app
echo "installed: $(codesign -dr - /Applications/iRemote.app 2>&1 | tail -1)"
