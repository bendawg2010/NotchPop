#!/bin/bash
# Build NotchPop.dmg — the polished drag-to-Applications installer.
#
# This packages NotchPop.app into a DMG with:
#   • A symlink to /Applications inside the disk image
#   • Window in icon view, sized for an obvious left→right drag
#   • App icon on the left, Applications icon on the right
#   • A custom background image hinting at the drag gesture
#
# The user opens the DMG → Finder shows our window → they drag the
# app onto /Applications → done. Same experience as Discord, Firefox,
# any other unsigned-but-polished Mac app distributed outside the
# App Store.

set -euo pipefail
cd "$(dirname "$0")/.."

APP="$(find build -type d -name 'NotchPop.app' -path '*Build/Products/Release/*' | head -1)"
if [ -z "$APP" ]; then
  echo "Build the app first via ./scripts/build.sh"
  exit 1
fi

VOLNAME="NotchPop"
DMG_OUT="$(pwd)/NotchPop.dmg"
STAGING="$(mktemp -d -t notchpop-dmg)"
WORK_DIR="$(mktemp -d -t notchpop-dmg-work)"
trap "rm -rf '$STAGING' '$WORK_DIR'" EXIT

# ---- 1. Stage contents -----------------------------------------------
echo "→ Staging at $STAGING"
cp -R "$APP" "$STAGING/NotchPop.app"
ln -s /Applications "$STAGING/Applications"

# Ship a tiny background hint as a hidden folder
mkdir -p "$STAGING/.background"
if [ -f "scripts/dmg-background.png" ]; then
  cp scripts/dmg-background.png "$STAGING/.background/background.png"
fi

# ---- 2. Build a writable DMG to mount + decorate ---------------------
# Output the writable DMG into a SEPARATE work dir so we don't try to
# pack the DMG file into itself when reading from the staging tree.
WRITABLE_DMG="$WORK_DIR/notchpop-rw.dmg"
STAGE_KB=$(du -sk "$STAGING" | awk '{print $1}')
SIZE_KB=$((STAGE_KB + 16384))   # +16 MB headroom for HFS+ overhead
echo "→ Creating writable DMG (staging $STAGE_KB KB, image $SIZE_KB KB)"
hdiutil create -srcfolder "$STAGING" \
  -volname "$VOLNAME" \
  -fs HFS+ \
  -format UDRW \
  -size "${SIZE_KB}k" \
  "$WRITABLE_DMG" >/dev/null

# ---- 3. Mount, decorate, unmount -------------------------------------
echo "→ Mounting + decorating"
ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "$WRITABLE_DMG")"
# Extract just the /Volumes/... path. hdiutil's tabular output makes
# line-based parsing fragile, so grep -oE pulls the path directly.
MOUNT_DIR="$(printf '%s\n' "$ATTACH_OUTPUT" | grep -oE '/Volumes/[A-Za-z0-9_.-]+' | head -1)"

if [ -z "$MOUNT_DIR" ] || [ ! -d "$MOUNT_DIR" ]; then
  echo "Failed to detect mount point in hdiutil output:"
  printf '%s\n' "$ATTACH_OUTPUT"
  exit 1
fi
echo "  mounted at $MOUNT_DIR"

# AppleScript: set icon view, custom window size, position icons
osascript <<EOF
tell application "Finder"
  tell disk "$VOLNAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 760, 480}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    if (exists file ".background:background.png") then
      set background picture of viewOptions to file ".background:background.png"
    end if
    set position of item "NotchPop.app" of container window to {150, 180}
    set position of item "Applications" of container window to {410, 180}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF

# Set the volume icon (use the app's own icon)
sync
chmod -Rf go-w "$MOUNT_DIR" || true
hdiutil detach "$MOUNT_DIR" -force >/dev/null

# ---- 4. Convert writable → read-only compressed -----------------------
echo "→ Compressing DMG"
rm -f "$DMG_OUT"
hdiutil convert "$WRITABLE_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_OUT" >/dev/null

echo ""
echo "✓ Built:"
ls -lh "$DMG_OUT"
echo ""
echo "Open it: open '$DMG_OUT'"
