#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
/usr/bin/xcrun swift build -c release --product RecapMac
binary_dir=$(/usr/bin/xcrun swift build -c release --show-bin-path)
# Assemble and sign outside Documents/iCloud FileProvider metadata updates.
stage_dir=$(mktemp -d "${TMPDIR:-/tmp}/recap-app.XXXXXX")
trap 'rm -rf "$stage_dir"' EXIT
app_dir="$stage_dir/Recap.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/RecapMac" "$app_dir/Contents/MacOS/RecapMac"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
icon_dir="$PWD/artifacts/Recap.iconset"
mkdir -p "$icon_dir"
for size in 16 32 128 256 512; do
    /usr/bin/sips -z "$size" "$size" Resources/Recap.png --out "$icon_dir/icon_${size}x${size}.png" >/dev/null
    doubled=$((size * 2))
    /usr/bin/sips -z "$doubled" "$doubled" Resources/Recap.png --out "$icon_dir/icon_${size}x${size}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$icon_dir" -o "$app_dir/Contents/Resources/Recap.icns"
cp ../../LICENSE "$app_dir/Contents/Resources/Owl-LICENSE.txt"
cp ../../NOTICE "$app_dir/Contents/Resources/NOTICE.txt"
for resource in "$binary_dir"/*.bundle; do
    if [ -d "$resource" ]; then /usr/bin/ditto --norsrc --noextattr "$resource" "$app_dir/Contents/Resources/$(basename "$resource")"; fi
done
mkdir -p "$app_dir/Contents/Resources/Licenses"
for dependency in "$PWD/.build/checkouts/"*; do
    for license in LICENSE LICENSE.txt LICENSE.md LICENCE; do
        if [ -f "$dependency/$license" ]; then
            cp "$dependency/$license" "$app_dir/Contents/Resources/Licenses/$(basename "$dependency").txt"
            break
        fi
    done
done
# Generated bundles under Documents can inherit Finder metadata. Strip it only
# from this build product, as required by codesign (Apple QA1940).
/usr/bin/xattr -cr "$app_dir"
/usr/bin/codesign --force --deep --sign - "$app_dir"
/usr/bin/codesign --verify --deep --strict "$app_dir"
mkdir -p "$PWD/artifacts"
build_products_dir="$HOME/Library/Developer/Recap/Builds"
mkdir -p "$build_products_dir"
rm -rf "$build_products_dir/Recap.app"
/usr/bin/ditto --norsrc --noextattr "$app_dir" "$build_products_dir/Recap.app"
/usr/bin/codesign --verify --deep --strict "$build_products_dir/Recap.app"
printf '%s\n' "$build_products_dir/Recap.app" > "$PWD/artifacts/app-path.txt"
/usr/bin/ditto -c -k --keepParent "$build_products_dir/Recap.app" "$PWD/artifacts/Recap-macOS-arm64.zip"
printf '%s\n' "$build_products_dir/Recap.app"
