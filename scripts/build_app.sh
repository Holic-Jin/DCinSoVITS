#!/bin/bash
# DCinSoVITS.app 빌드 — Made by HolicJin
# 사용법: scripts/build_app.sh   → dist/DCinSoVITS.app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/DCinSoVITS.app"
VERSION="1.0.0"

cd "$ROOT/app"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/DCinSoVITS"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/engine"
cp "$BIN" "$APP/Contents/MacOS/DCinSoVITS"
strip -x "$APP/Contents/MacOS/DCinSoVITS"

# 엔진은 소스만 포함 (런타임·모델은 첫 실행 시 설치)
rsync -a --exclude '__pycache__' --exclude '*.pyc' \
  "$ROOT/engine/dcin_engine" "$ROOT/engine/setup.sh" "$ROOT/engine/requirements-engine.txt" \
  "$APP/Contents/Resources/engine/"
cp "$ROOT/DISCLAIMER.txt" "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>DCinSoVITS</string>
  <key>CFBundleDisplayName</key><string>DCinSoVITS</string>
  <key>CFBundleIdentifier</key><string>com.holicjin.DCinSoVITS</string>
  <key>CFBundleExecutable</key><string>DCinSoVITS</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>© HolicJin. 본 프로그램은 동영상을 포함하지 않으며, 작성된 데이터의 이용 책임은 사용자 본인에게 있습니다.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "Built: $APP ($(du -sh "$APP" | cut -f1))"
