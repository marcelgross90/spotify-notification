#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
configuration="${1:-release}"
build_path="$project_root/.build"
app_path="$project_root/dist/Spotify Notification.app"
contents_path="$app_path/Contents"

swift build \
    --package-path "$project_root" \
    --scratch-path "$build_path" \
    --configuration "$configuration"

binary_path="$(swift build \
    --package-path "$project_root" \
    --scratch-path "$build_path" \
    --configuration "$configuration" \
    --show-bin-path)/SpotifyNotification"

mkdir -p "$contents_path/MacOS" "$contents_path/Resources"
cp "$binary_path" "$contents_path/MacOS/SpotifyNotification"
cp "$project_root/App/Info.plist" "$contents_path/Info.plist"
cp "$project_root/App/AppIcon.icns" "$contents_path/Resources/AppIcon.icns"
ditto "$project_root/App/Resources" "$contents_path/Resources"

codesign --force --deep --sign - "$app_path"

echo "$app_path"
