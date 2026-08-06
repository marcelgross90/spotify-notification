#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
configuration="${1:-release}"
build_path="$project_root/.build"
derived_data_path="$build_path/xcode"
app_path="$project_root/dist/Spotify Notification.app"
contents_path="$app_path/Contents"
frameworks_path="$contents_path/Frameworks"
resources_path="$contents_path/Resources"

case "$configuration" in
    release) xcode_configuration="Release" ;;
    debug) xcode_configuration="Debug" ;;
    *)
        print -u2 "package-app: unsupported configuration '$configuration' (expected 'debug' or 'release')."
        exit 1
        ;;
esac

log() {
    print -u2 "package-app: $1"
}

require_path() {
    if [[ ! -e "$1" ]]; then
        print -u2 "package-app: expected build product is missing: $1"
        exit 1
    fi
}

rm -rf "$app_path"

# The app is built with xcodebuild instead of `swift build` on purpose.
#
# SwiftPM's command-line resource accessor resolves Bundle.module to
# "<Bundle.main.bundleURL>/<Target>_<Target>.bundle". For a packaged .app,
# Bundle.main.bundleURL is the bundle root next to Contents, and macOS refuses to
# code sign a bundle that carries anything besides Contents there ("unsealed
# contents present in the bundle root"). Xcode's accessor instead checks
# Bundle.main.resourceURL first, so dependency resource bundles such as
# KeyboardShortcuts_KeyboardShortcuts.bundle resolve from Contents/Resources and
# the app stays signable.
log "building $xcode_configuration configuration with xcodebuild"
cd "$project_root"
xcodebuild \
    -scheme SpotifyNotification \
    -configuration "$xcode_configuration" \
    -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath "$derived_data_path" \
    -quiet \
    build

products_path="$derived_data_path/Build/Products/$xcode_configuration"
source_packages_path="$derived_data_path/SourcePackages"
binary_path="$products_path/SpotifyNotification"
sparkle_framework="$products_path/Sparkle.framework"
# Required, not optional: without this bundle the app hits a fatal error in
# KeyboardShortcuts' generated Bundle.module accessor the first time it reads one
# of its localized strings.
keyboard_shortcuts_bundle="$products_path/KeyboardShortcuts_KeyboardShortcuts.bundle"
sparkle_license="$source_packages_path/artifacts/sparkle/Sparkle/LICENSE"
keyboard_shortcuts_license="$source_packages_path/checkouts/KeyboardShortcuts/license"

require_path "$binary_path"
require_path "$sparkle_framework"
require_path "$keyboard_shortcuts_bundle"
require_path "$sparkle_license"
require_path "$keyboard_shortcuts_license"

log "assembling $app_path"
mkdir -p "$contents_path/MacOS" "$resources_path" "$frameworks_path"
cp "$binary_path" "$contents_path/MacOS/SpotifyNotification"
cp "$project_root/App/Info.plist" "$contents_path/Info.plist"
cp "$project_root/App/AppIcon.icns" "$resources_path/AppIcon.icns"
ditto "$project_root/App/Resources" "$resources_path"
ditto "$sparkle_framework" "$frameworks_path/Sparkle.framework"
ditto "$keyboard_shortcuts_bundle" \
    "$resources_path/KeyboardShortcuts_KeyboardShortcuts.bundle"
mkdir -p "$resources_path/Licenses"
cp "$sparkle_license" "$resources_path/Licenses/Sparkle.txt"
cp "$keyboard_shortcuts_license" "$resources_path/Licenses/KeyboardShortcuts.txt"

install_name_tool \
    -add_rpath "@executable_path/../Frameworks" \
    "$contents_path/MacOS/SpotifyNotification"

log "signing with an ad-hoc signature"
codesign --force --deep --sign - "$app_path"

# Catch a resource bundle that did not land where Bundle.module looks for it, and
# any stray file in the bundle root that would invalidate the signature, before the
# app ever reaches a user.
log "verifying bundle layout and signature"
require_path "$resources_path/KeyboardShortcuts_KeyboardShortcuts.bundle/Contents/Info.plist"
codesign --verify --deep --strict "$app_path"

log "done"
echo "$app_path"
