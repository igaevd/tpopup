#!/bin/bash
# Builds tpopup and installs it into /Applications, replacing any existing copy.
# No DMG, no staging — straight onto this machine.
#
# Usage:  ./deploy.sh
# Result: /Applications/tpopup.app
set -euo pipefail

APP_NAME="tpopup"
BUNDLE_ID="com.idmitry.tpopup"
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

STAGING_DIR="${PROJECT_DIR}/.build-install"
APP_BUNDLE="${STAGING_DIR}/${APP_NAME}.app"
INSTALL_PATH="/Applications/${APP_NAME}.app"

ICON_SRC="${PROJECT_DIR}/resources/AppIcon.icns"
PROMPT_SRC="${PROJECT_DIR}/resources/translation-ai-prompt.md"
PLIST_SRC="${PROJECT_DIR}/BundleResources/Info.plist"

cd "${PROJECT_DIR}"

echo "▶ Cleaning previous build…"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

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

cp "${BIN_PATH}"   "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "${PLIST_SRC}"  "${APP_BUNDLE}/Contents/Info.plist"
cp "${ICON_SRC}"   "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
cp "${PROMPT_SRC}" "${APP_BUNDLE}/Contents/Resources/translation-ai-prompt.md"

strip -S -x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
printf 'APPL????' > "${APP_BUNDLE}/Contents/PkgInfo"

echo "▶ Ad-hoc code-signing…"
codesign --force --deep --sign - \
    --identifier "${BUNDLE_ID}" \
    --options runtime \
    "${APP_BUNDLE}"

# A running instance would lock the binary in place, so stop it first.
if pgrep -f "${INSTALL_PATH}/Contents/MacOS/${APP_NAME}" >/dev/null; then
    echo "▶ Stopping running instance…"
    pkill -f "${INSTALL_PATH}/Contents/MacOS/${APP_NAME}" || true
    # Give launchd a moment to release the file.
    for _ in 1 2 3 4 5; do
        pgrep -f "${INSTALL_PATH}/Contents/MacOS/${APP_NAME}" >/dev/null || break
        sleep 0.2
    done
fi

echo "▶ Installing to ${INSTALL_PATH}…"
SUDO=""
if [[ -e "${INSTALL_PATH}" && ! -w "${INSTALL_PATH}" ]]; then
    SUDO="sudo"
fi
if [[ ! -w "/Applications" ]]; then
    SUDO="sudo"
fi

${SUDO} rm -rf "${INSTALL_PATH}"
${SUDO} cp -R "${APP_BUNDLE}" "${INSTALL_PATH}"

# Clear any quarantine attribute (shouldn't be set on a locally-built bundle, but be safe).
${SUDO} xattr -dr com.apple.quarantine "${INSTALL_PATH}" 2>/dev/null || true

rm -rf "${STAGING_DIR}"

echo ""
echo "✓ Installed ${INSTALL_PATH}"
