#!/bin/zsh
# 앱을 빌드한다.
#   ./build.sh            빌드해서 /Applications 에 설치하고 실행한다.
#   ./build.sh --package  빌드해서 배포용 dist/Easyfilm-<버전>.zip 을 만든다. 설치는 하지 않는다.
set -euo pipefail
cd "${0:A:h}"

APP_NAME="Easyfilm"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"
HELPER="$APP/Contents/Helpers/Easyfilm Helper.app"
INSTALL_DIR="/Applications"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)

# 인텔 맥과 Apple Silicon 맥 모두에서 돌도록 두 번 빌드해 하나로 합친다.
build_universal() {
  local output="$1"; shift
  for arch in arm64 x86_64; do
    swiftc -O -swift-version 5 -target "$arch-apple-macos14.0" -o "$BUILD_DIR/$arch" "$@"
  done
  lipo -create -output "$output" "$BUILD_DIR/arm64" "$BUILD_DIR/x86_64"
  rm "$BUILD_DIR/arm64" "$BUILD_DIR/x86_64"
}

rm -rf "$BUILD_DIR"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$HELPER/Contents/MacOS" "$HELPER/Contents/Resources"

# 본 앱과 도우미를 따로 빌드한다.
build_universal "$APP/Contents/MacOS/Easyfilm" Sources/App/*.swift Sources/Shared/*.swift
build_universal "$HELPER/Contents/MacOS/EasyfilmHelper" Sources/Helper/*.swift Sources/Shared/*.swift
cp Resources/Info.plist "$APP/Contents/"
cp Resources/Helper-Info.plist "$HELPER/Contents/Info.plist"

# 아이콘 파일이 없을 때만 새로 만든다.
if [[ ! -f Resources/AppIcon.icns ]]; then
  ICONSET="$BUILD_DIR/AppIcon.iconset"
  mkdir -p "$ICONSET"
  swift tools/make_icon.swift "$BUILD_DIR/icon.png"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$BUILD_DIR/icon.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$BUILD_DIR/icon.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
  rm -rf "$ICONSET" "$BUILD_DIR/icon.png"
fi

# 아이콘과 언어 파일(한국어, 영어, 일본어)은 본 앱과 도우미 모두에 넣는다.
for bundle in "$APP" "$HELPER"; do
  cp Resources/AppIcon.icns "$bundle/Contents/Resources/"
  cp -R Resources/*.lproj "$bundle/Contents/Resources/"
done

# 개인 서명 인증서가 있으면 그것으로 서명한다. 그래야 새 버전을 깔아도 손쉬운 사용 권한이 유지된다.
# 안쪽 도우미를 먼저 서명하고 바깥 앱을 서명한다.
SIGN_ID="0w0-dot Code Signing"
security find-identity -p codesigning | grep -qF "$SIGN_ID" || SIGN_ID="-"
codesign --force --sign "$SIGN_ID" "$HELPER"
codesign --force --sign "$SIGN_ID" "$APP"

if [[ "${1:-}" == "--package" ]]; then
  mkdir -p dist
  ZIP="dist/$APP_NAME-$VERSION.zip"
  rm -f "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"
  rm -rf "$BUILD_DIR"
  echo "배포 파일: $ZIP"
  shasum -a 256 "$ZIP"
  exit 0
fi

# 실행 중이면 끄고 새 버전으로 바꾼 뒤 다시 켠다. 도우미는 앱이 켜질 때 새 버전으로 다시 뜬다.
pkill -x Easyfilm || true
rm -rf "$INSTALL_DIR/$APP_NAME.app"
ditto "$APP" "$INSTALL_DIR/$APP_NAME.app"
rm -rf "$BUILD_DIR"
open "$INSTALL_DIR/$APP_NAME.app"

echo "설치 완료: $INSTALL_DIR/$APP_NAME.app"
