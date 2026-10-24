#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="${1:-$project_dir/dist}"
cache_dir="${WINDOWCAT_BUILD_DIR:-$project_dir/.build}"
mkdir -p "$output_dir" "$cache_dir/module-cache"
export CLANG_MODULE_CACHE_PATH="$cache_dir/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$cache_dir/module-cache"
asset="$project_dir/Sources/WindowCat/Resources/Elthen/Cat.png"
if [[ ! -f "$asset" ]]; then
  echo "Missing licensed cat artwork. Follow docs/BUILD.md to obtain Cat.png from Elthen." >&2
  exit 1
fi
swift build --package-path "$project_dir" --scratch-path "$cache_dir" --disable-sandbox -c release
bin_dir="$(swift build --package-path "$project_dir" --scratch-path "$cache_dir" --disable-sandbox -c release --show-bin-path)"
app_dir="$output_dir/windowcat.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$bin_dir/WindowCat" "$app_dir/Contents/MacOS/WindowCat"
ditto "$project_dir/Sources/WindowCat/Resources" "$app_dir/Contents/Resources"
swift "$project_dir/scripts/make-icon.swift" "$asset" "$cache_dir/AppIcon.iconset"
iconutil -c icns "$cache_dir/AppIcon.iconset" -o "$app_dir/Contents/Resources/AppIcon.icns"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.windowcat.desktop</string>
  <key>CFBundleName</key><string>windowcat</string>
  <key>CFBundleDisplayName</key><string>windowcat</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>ja</string><string>zh-Hans</string></array>
  <key>CFBundleExecutable</key><string>WindowCat</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
codesign --force --sign - --identifier local.windowcat.desktop "$app_dir"
codesign --verify --strict "$app_dir"
echo "Built: $app_dir"
