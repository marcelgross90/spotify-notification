#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
configuration="${1:-release}"
build_path="$project_root/.build"
app_path="$project_root/dist/Spotify Notification.app"
contents_path="$app_path/Contents"
frameworks_path="$contents_path/Frameworks"

rm -rf "$app_path"

swift build \
    --package-path "$project_root" \
    --scratch-path "$build_path" \
    --configuration "$configuration"

keyboard_shortcuts_accessor="$build_path/arm64-apple-macosx/$configuration/KeyboardShortcuts.build/DerivedSources/resource_bundle_accessor.swift"
if [[ -f "$keyboard_shortcuts_accessor" ]] && \
    grep -q "Bundle.main.bundleURL" "$keyboard_shortcuts_accessor"; then
    sed -i '' \
        's/Bundle.main.bundleURL/Bundle.main.resourceURL!/' \
        "$keyboard_shortcuts_accessor"
    touch "$keyboard_shortcuts_accessor"
    swift build \
        --package-path "$project_root" \
        --scratch-path "$build_path" \
        --configuration "$configuration"
fi

binary_path="$(swift build \
    --package-path "$project_root" \
    --scratch-path "$build_path" \
    --configuration "$configuration" \
    --show-bin-path)/SpotifyNotification"

mkdir -p "$contents_path/MacOS" "$contents_path/Resources" "$frameworks_path"
cp "$binary_path" "$contents_path/MacOS/SpotifyNotification"
cp "$project_root/App/Info.plist" "$contents_path/Info.plist"
cp "$project_root/App/AppIcon.icns" "$contents_path/Resources/AppIcon.icns"
ditto "$project_root/App/Resources" "$contents_path/Resources"
ditto "$build_path/arm64-apple-macosx/$configuration/Sparkle.framework" \
    "$frameworks_path/Sparkle.framework"
keyboard_shortcuts_bundle="$build_path/arm64-apple-macosx/$configuration/KeyboardShortcuts_KeyboardShortcuts.bundle"
if [[ -d "$keyboard_shortcuts_bundle" ]]; then
    ditto "$keyboard_shortcuts_bundle" \
        "$contents_path/Resources/KeyboardShortcuts_KeyboardShortcuts.bundle"
fi
mkdir -p "$contents_path/Resources/Licenses"
cp "$build_path/artifacts/sparkle/Sparkle/LICENSE" \
    "$contents_path/Resources/Licenses/Sparkle.txt"
cp "$build_path/checkouts/KeyboardShortcuts/license" \
    "$contents_path/Resources/Licenses/KeyboardShortcuts.txt"

install_name_tool \
    -add_rpath "@executable_path/../Frameworks" \
    "$contents_path/MacOS/SpotifyNotification"

codesign --force --deep --sign - "$app_path"

echo "$app_path"
