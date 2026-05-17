#!/bin/bash
# Builds tpopup as a release .app bundle and packages it into a DMG that opens
# with an "Applications" symlink for the standard drag-to-install flow, plus a
# plain zip of the .app for hosts that prefer a flat archive.
#
# Usage:  ./pack.sh
# Output: dist/tpopup-<version>.dmg
#         dist/tpopup-<version>.zip
set -euo pipefail

APP_NAME="tpopup"
BUNDLE_ID="com.idmitry.tpopup"
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

DIST_DIR="${PROJECT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
DMG_STAGING="${DIST_DIR}/dmg-staging"

ICON_SRC="${PROJECT_DIR}/resources/AppIcon.icns"
TRANSLATION_PROMPT_SRC="${PROJECT_DIR}/resources/translation-ai-prompt.md"
GRAMMAR_PROMPT_SRC="${PROJECT_DIR}/resources/grammar-ai-prompt.md"
PLIST_SRC="${PROJECT_DIR}/BundleResources/Info.plist"

# Single source of truth — pull the version straight from Info.plist so it never
# drifts from what macOS shows in the About panel.
APP_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${PLIST_SRC}")"
DMG_FILE="${DIST_DIR}/${APP_NAME}-${APP_VERSION}.dmg"
ZIP_FILE="${DIST_DIR}/${APP_NAME}-${APP_VERSION}.zip"

cd "${PROJECT_DIR}"

echo "▶ Cleaning previous build…"
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

echo "▶ Building universal release binary (arm64 + x86_64)…"
swift build -c release --arch arm64 --arch x86_64
BIN_PATH="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/${APP_NAME}"

if [[ ! -f "${BIN_PATH}" ]]; then
    echo "✗ Build did not produce a binary at ${BIN_PATH}" >&2
    exit 1
fi

echo "▶ Assembling ${APP_NAME}.app bundle…"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BIN_PATH}"               "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "${PLIST_SRC}"              "${APP_BUNDLE}/Contents/Info.plist"
cp "${ICON_SRC}"               "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
cp "${TRANSLATION_PROMPT_SRC}" "${APP_BUNDLE}/Contents/Resources/translation-ai-prompt.md"
cp "${GRAMMAR_PROMPT_SRC}"     "${APP_BUNDLE}/Contents/Resources/grammar-ai-prompt.md"

# Strip debug info so the shipped binary doesn't carry dSYMs or source paths.
strip -S -x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true

# Stamp PkgInfo (Finder uses this to recognise an .app).
printf 'APPL????' > "${APP_BUNDLE}/Contents/PkgInfo"

echo "▶ Ad-hoc code-signing…"
codesign --force --deep --sign - \
    --identifier "${BUNDLE_ID}" \
    --options runtime \
    "${APP_BUNDLE}"

echo "▶ Verifying bundle…"
codesign --verify --verbose=2 "${APP_BUNDLE}"

echo "▶ Building DMG…"
rm -rf "${DMG_STAGING}"
mkdir -p "${DMG_STAGING}"
cp -R "${APP_BUNDLE}" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"

# Temporary read-write DMG so we can tune the window layout, then convert to compressed read-only.
TMP_DMG="${DIST_DIR}/${APP_NAME}-tmp.dmg"
rm -f "${TMP_DMG}" "${DMG_FILE}"

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_STAGING}" \
    -ov \
    -fs HFS+ \
    -format UDRW \
    "${TMP_DMG}" >/dev/null

# Compress to final read-only image.
hdiutil convert "${TMP_DMG}" \
    -format UDZO -imagekey zlib-level=9 \
    -o "${DMG_FILE}" >/dev/null

rm -f "${TMP_DMG}"
rm -rf "${DMG_STAGING}"

echo "▶ Building zip archive…"
# `ditto` preserves resource forks, symlinks, and code-signing metadata that a
# plain `zip` would mangle. `--keepParent` makes the archive unpack to
# `tpopup.app/` instead of dumping its contents at the destination root.
rm -f "${ZIP_FILE}"
ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${ZIP_FILE}"

echo ""
echo "✓ Built ${APP_BUNDLE}"
echo "✓ Packaged ${DMG_FILE}"
echo "✓ Packaged ${ZIP_FILE}"
echo ""
echo "Open the DMG and drag ${APP_NAME}.app into Applications to install."
