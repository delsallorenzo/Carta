#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/.build-release"
DIST_DIR="${ROOT_DIR}/dist"
ICON_SOURCE="${ROOT_DIR}/Assets/icon.png"
ICON_DIR="${DIST_DIR}/AppIcon.iconset"
ICON_ICNS="${DIST_DIR}/AppIcon.icns"
APP_DIR="${DIST_DIR}/Carta.app"
DMG_DIR="${DIST_DIR}/dmg"
DMG_PATH="${DIST_DIR}/Carta.dmg"

rm -rf "${BUILD_DIR}" "${APP_DIR}" "${ICON_DIR}" "${ICON_ICNS}" "${DMG_DIR}" "${DMG_PATH}"
mkdir -p "${DIST_DIR}" "${ICON_DIR}"

if [[ ! -f "${ICON_SOURCE}" ]]; then
  echo "Missing icon source: ${ICON_SOURCE}" >&2
  exit 1
fi

CLANG_MODULE_CACHE_PATH=/tmp/carta-module-cache swift build -c release --build-path "${BUILD_DIR}"

sips -z 16 16 "${ICON_SOURCE}" --out "${ICON_DIR}/icon_16x16.png" >/dev/null
sips -z 32 32 "${ICON_SOURCE}" --out "${ICON_DIR}/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "${ICON_SOURCE}" --out "${ICON_DIR}/icon_32x32.png" >/dev/null
sips -z 64 64 "${ICON_SOURCE}" --out "${ICON_DIR}/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "${ICON_SOURCE}" --out "${ICON_DIR}/icon_128x128.png" >/dev/null
sips -z 256 256 "${ICON_SOURCE}" --out "${ICON_DIR}/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "${ICON_SOURCE}" --out "${ICON_DIR}/icon_256x256.png" >/dev/null
sips -z 512 512 "${ICON_SOURCE}" --out "${ICON_DIR}/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "${ICON_SOURCE}" --out "${ICON_DIR}/icon_512x512.png" >/dev/null
cp "${ICON_SOURCE}" "${ICON_DIR}/icon_512x512@2x.png"

iconutil -c icns "${ICON_DIR}" -o "${ICON_ICNS}"

mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${BUILD_DIR}/release/Carta" "${APP_DIR}/Contents/MacOS/Carta"
cp "${ICON_ICNS}" "${APP_DIR}/Contents/Resources/AppIcon.icns"

cat > "${APP_DIR}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Carta</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.carta.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Carta</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.2.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

chmod +x "${APP_DIR}/Contents/MacOS/Carta"
codesign --force --deep --sign - "${APP_DIR}" >/dev/null 2>&1 || true

mkdir -p "${DMG_DIR}"
cp -R "${APP_DIR}" "${DMG_DIR}/"
ln -s /Applications "${DMG_DIR}/Applications"

hdiutil create \
  -volname "Carta" \
  -srcfolder "${DMG_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}" >/dev/null

echo "Created:"
echo "  ${APP_DIR}"
echo "  ${DMG_PATH}"
