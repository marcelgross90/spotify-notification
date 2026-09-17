#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
configuration="${1:-release}"
build_path="$project_root/.build"
app_path="$project_root/dist/Spotify Notification.app"
contents_path="$app_path/Contents"
frameworks_path="$contents_path/Frameworks"

rm -rf "$app_path"

swift package \
    --package-path "$project_root" \
    --scratch-path "$build_path" \
    resolve

keyboard_shortcuts_checkout="$build_path/checkouts/KeyboardShortcuts"
keyboard_shortcuts_utilities="$keyboard_shortcuts_checkout/Sources/KeyboardShortcuts/Utilities.swift"
keyboard_shortcuts_patch="$project_root/patches/KeyboardShortcuts-installed-resource-bundle.patch"
if ! grep -q "keyboardShortcutsResourceBundle" "$keyboard_shortcuts_utilities"; then
    chmod u+w "$keyboard_shortcuts_utilities"
    git -C "$keyboard_shortcuts_checkout" apply \
        --unidiff-zero \
        "$keyboard_shortcuts_patch"
fi

swift build \
    --package-path "$project_root" \
    --scratch-path "$build_path" \
    --configuration "$configuration"

products_path="$(swift build \
    --package-path "$project_root" \
    --scratch-path "$build_path" \
    --configuration "$configuration" \
    --show-bin-path)"
binary_path="$products_path/SpotifyNotification"

mkdir -p "$contents_path/MacOS" "$contents_path/Resources" "$frameworks_path"
cp "$binary_path" "$contents_path/MacOS/SpotifyNotification"
cp "$project_root/App/Info.plist" "$contents_path/Info.plist"
cp "$project_root/App/AppIcon.icns" "$contents_path/Resources/AppIcon.icns"
ditto "$project_root/App/Resources" "$contents_path/Resources"
ditto "$products_path/Sparkle.framework" \
    "$frameworks_path/Sparkle.framework"
keyboard_shortcuts_bundle="$products_path/KeyboardShortcuts_KeyboardShortcuts.bundle"
if [[ ! -d "$keyboard_shortcuts_bundle" ]]; then
    echo "Missing KeyboardShortcuts resource bundle at $keyboard_shortcuts_bundle" >&2
    exit 1
fi
ditto "$keyboard_shortcuts_bundle" \
    "$contents_path/Resources/KeyboardShortcuts_KeyboardShortcuts.bundle"
mkdir -p "$contents_path/Resources/Licenses"
cp "$build_path/artifacts/sparkle/Sparkle/LICENSE" \
    "$contents_path/Resources/Licenses/Sparkle.txt"
cp "$build_path/checkouts/KeyboardShortcuts/license" \
    "$contents_path/Resources/Licenses/KeyboardShortcuts.txt"

install_name_tool \
    -add_rpath "@executable_path/../Frameworks" \
    "$contents_path/MacOS/SpotifyNotification"

codesign --force --deep --sign - "$app_path"

SPOTIFY_NOTIFICATION_VERIFY_SHORTCUT_RESOURCES=1 \
    "$contents_path/MacOS/SpotifyNotification"

echo "$app_path"
