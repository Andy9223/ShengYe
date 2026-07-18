#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
OUTPUT_DIR=${1:-"${PROJECT_DIR}/dist"}
APP_DIR="${OUTPUT_DIR}/声页.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
    "${PROJECT_DIR}/Resources/Info.plist")
ARM_BUILD_DIR="${PROJECT_DIR}/.build-release-arm64"
INTEL_BUILD_DIR="${PROJECT_DIR}/.build-release-x86_64"
PACKAGE_DIR="${PROJECT_DIR}/.build-release-package"
ICONSET_DIR="${PACKAGE_DIR}/AppIcon.iconset"
ICON_SOURCE="${PROJECT_DIR}/Resources/AppIcon.png"
ICON_FILE="${PACKAGE_DIR}/AppIcon.icns"
ZIP_FILE="${OUTPUT_DIR}/VoicePage-v${VERSION}-macOS-universal.zip"
DMG_FILE="${OUTPUT_DIR}/VoicePage-v${VERSION}-macOS-universal.dmg"

mkdir -p "${OUTPUT_DIR}"
cd "${PROJECT_DIR}"
swift build \
    -c release \
    --arch arm64 \
    --product VoicePage \
    --scratch-path "${ARM_BUILD_DIR}"
swift build \
    -c release \
    --arch x86_64 \
    --product VoicePage \
    --scratch-path "${INTEL_BUILD_DIR}"

ARM_BIN=$(swift build \
    -c release \
    --arch arm64 \
    --product VoicePage \
    --scratch-path "${ARM_BUILD_DIR}" \
    --show-bin-path)
INTEL_BIN=$(swift build \
    -c release \
    --arch x86_64 \
    --product VoicePage \
    --scratch-path "${INTEL_BUILD_DIR}" \
    --show-bin-path)

rm -rf "${PACKAGE_DIR}"
mkdir -p "${ICONSET_DIR}"
sips -z 16 16 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null
sips -z 32 32 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null
sips -z 64 64 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null
sips -z 256 256 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null
sips -z 512 512 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null
sips -z 1024 1024 "${ICON_SOURCE}" --out "${ICONSET_DIR}/icon_512x512@2x.png" >/dev/null
iconutil -c icns "${ICONSET_DIR}" -o "${ICON_FILE}"

rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"
lipo -create \
    "${ARM_BIN}/VoicePage" \
    "${INTEL_BIN}/VoicePage" \
    -output "${APP_DIR}/Contents/MacOS/VoicePage"
cp "${PROJECT_DIR}/Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"
cp "${ICON_FILE}" "${APP_DIR}/Contents/Resources/AppIcon.icns"

codesign --force --deep --sign - "${APP_DIR}"

rm -f "${OUTPUT_DIR}/VoicePage-macOS.zip" "${ZIP_FILE}" "${DMG_FILE}"
ditto -c -k --sequesterRsrc --keepParent "${APP_DIR}" "${ZIP_FILE}"

DMG_STAGE="${PACKAGE_DIR}/dmg"
mkdir -p "${DMG_STAGE}"
ditto "${APP_DIR}" "${DMG_STAGE}/声页.app"
ln -s /Applications "${DMG_STAGE}/Applications"
hdiutil create \
    -volname "声页 ${VERSION}" \
    -srcfolder "${DMG_STAGE}" \
    -ov \
    -format UDZO \
    "${DMG_FILE}" >/dev/null

echo "App: ${APP_DIR}"
echo "ZIP: ${ZIP_FILE}"
echo "DMG: ${DMG_FILE}"
lipo -archs "${APP_DIR}/Contents/MacOS/VoicePage"
