#!/bin/bash
# Cut a NotchPop release end-to-end:
#   1. Bump CFBundleShortVersionString in App/Info.plist
#   2. Build NotchPop.app  (./scripts/build.sh)
#   3. Build NotchPop.dmg  (./scripts/build-dmg.sh)
#   4. Sign DMG with Sparkle's EdDSA private key (in macOS Keychain)
#   5. Prepend a fresh <item> to website/appcast.xml
#   6. Print a `gh release create` command + a `wrangler pages deploy`
#      command — orchestrator runs those after reviewing the appcast diff
#
# Usage:
#   ./scripts/release.sh 1.5.1 "What's new in this release (HTML allowed)"
#
# Why split the publish step out? Reviewing appcast.xml + the DMG
# signature manually is good practice — once it's deployed, every
# NotchPop user's app downloads it. A typo in the version or a wrong
# URL bricks auto-updates for everyone.

set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-}"
NOTES_HTML="${2:-Bug fixes and improvements.}"

if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version> [release-notes-html]"
  echo "Example: $0 1.5.1 \"Music probe fix + auto-update\""
  exit 1
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must be MAJOR.MINOR.PATCH (e.g. 1.5.1)"
  exit 1
fi

# ---- Bump Info.plist version --------------------------------------
PLIST="App/Info.plist"
echo "→ Setting CFBundleShortVersionString = $VERSION"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"

# ---- Build the app + DMG ------------------------------------------
echo "→ Building NotchPop.app"
./scripts/build.sh > /dev/null

echo "→ Packaging NotchPop.dmg"
./scripts/build-dmg.sh > /dev/null

DMG="$(pwd)/NotchPop.dmg"
DMG_SIZE=$(stat -f%z "$DMG")

# ---- Sign the DMG with Sparkle's EdDSA private key ----------------
echo "→ Signing DMG with EdDSA"
SIGN_OUT="$(./scripts/sparkle/bin/sign_update "$DMG")"
# sign_update prints something like:
#   sparkle:edSignature="ABC123..." length="123456"
# Pull just the edSignature value out of the quoted attribute.
EDSIG="$(printf '%s\n' "$SIGN_OUT" | sed -nE 's/.*sparkle:edSignature="([^"]+)".*/\1/p')"
if [ -z "$EDSIG" ]; then
  echo "Failed to extract edSignature from sign_update output:"
  echo "$SIGN_OUT"
  exit 1
fi
echo "  edSignature = ${EDSIG:0:20}…"
echo "  size        = $DMG_SIZE bytes"

# ---- Prepend a fresh <item> to the appcast ------------------------
APPCAST="website/appcast.xml"
PUB_DATE="$(date -u +"%a, %d %b %Y %H:%M:%S +0000")"

NEW_ITEM=$(cat <<EOF
    <item>
      <title>v$VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[
        $NOTES_HTML
      ]]></description>
      <enclosure
        url="https://github.com/bendawg2010/NotchPop/releases/download/v$VERSION/NotchPop.dmg"
        sparkle:version="$VERSION"
        sparkle:shortVersionString="$VERSION"
        length="$DMG_SIZE"
        type="application/octet-stream"
        sparkle:edSignature="$EDSIG" />
    </item>

EOF
)

# Insert NEW_ITEM right after the channel's <description>...</description>
# closing tag. Done in pure bash to avoid awk's "newline in string" gripe
# with multiline -v values.
TMP_ITEM=$(mktemp)
TMP_OUT=$(mktemp)
printf '%s\n' "$NEW_ITEM" > "$TMP_ITEM"

INSERTED=0
while IFS= read -r line; do
  printf '%s\n' "$line" >> "$TMP_OUT"
  if [ $INSERTED -eq 0 ] && echo "$line" | grep -q '</description>'; then
    cat "$TMP_ITEM" >> "$TMP_OUT"
    INSERTED=1
  fi
done < "$APPCAST"

if [ $INSERTED -ne 1 ]; then
  echo "Failed to find <description> in $APPCAST — appcast structure unexpected"
  rm -f "$TMP_ITEM" "$TMP_OUT"
  exit 1
fi

mv "$TMP_OUT" "$APPCAST"
rm -f "$TMP_ITEM"

echo ""
echo "✓ Release prepped:"
echo "  Version:       $VERSION"
echo "  DMG:           $DMG ($DMG_SIZE bytes)"
echo "  Appcast:       $APPCAST (entry prepended)"
echo "  edSignature:   $EDSIG"
echo ""
echo "Next steps:"
echo "  1) Review the appcast diff:    git diff website/appcast.xml"
echo "  2) Create the GitHub release:  gh release create v$VERSION '$DMG' --title 'v$VERSION' --notes-file <(echo \"\$NOTES\")"
echo "  3) Deploy the website:         (cd website && npx wrangler pages deploy . --project-name=notchpop --branch=main --commit-dirty=true)"
echo "  4) Commit + push:              git add -A && git commit -m 'v$VERSION' && git push"
