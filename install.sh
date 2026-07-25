#!/bin/sh
# CleanKit installer / updater — downloads the latest release DMG, verifies its
# SHA-256 checksum, installs it to /Applications, and launches it. Re-run any
# time to update to the newest release.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/azharbinanwar/CleanKit/main/install.sh | sh
set -e

REPO="azharbinanwar/CleanKit"
APP="/Applications/CleanKit.app"
BASE_URL="https://github.com/$REPO/releases/latest/download"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Downloading latest CleanKit..."
curl -fL --progress-bar "$BASE_URL/CleanKit.dmg" -o "$TMP/CleanKit.dmg"

echo "Verifying checksum..."
curl -fsSL "$BASE_URL/CleanKit.dmg.sha256" -o "$TMP/CleanKit.dmg.sha256"
(cd "$TMP" && shasum -a 256 -c CleanKit.dmg.sha256 >/dev/null) || {
  echo "Error: checksum verification failed — the download may be corrupted. Aborting." >&2
  exit 1
}
echo "Checksum OK."

echo "Mounting DMG..."
MOUNT=$(hdiutil attach "$TMP/CleanKit.dmg" -nobrowse -noautoopen | grep -o '/Volumes/.*' | tail -1)

if [ ! -d "$MOUNT/CleanKit.app" ]; then
  hdiutil detach "$MOUNT" -quiet 2>/dev/null || true
  echo "Error: CleanKit.app not found in the DMG." >&2
  exit 1
fi

# Quit a running copy so the swap succeeds.
osascript -e 'tell application "CleanKit" to quit' >/dev/null 2>&1 || true

echo "Installing to /Applications..."
rm -rf "$APP"
cp -R "$MOUNT/CleanKit.app" /Applications/
hdiutil detach "$MOUNT" -quiet

# CleanKit is open source and ad-hoc signed (not notarized), so macOS marks the
# download as quarantined and Gatekeeper blocks the first launch. Clearing the
# quarantine flag on the verified, freshly-installed app lets it open normally.
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

echo "✅ CleanKit installed."
open "$APP"
