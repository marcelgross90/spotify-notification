#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
resources_path="$project_root/App/Resources"
reference_file="$resources_path/en.lproj/Localizable.strings"
temporary_path="$(mktemp -d)"

trap 'rm -rf "$temporary_path"' EXIT

extract_keys() {
    sed -n 's/^"\([^"]*\)"[[:space:]]*=.*/\1/p' "$1" | sort
}

extract_keys "$reference_file" > "$temporary_path/reference-keys"

for strings_file in "$resources_path"/*.lproj/*.strings; do
    plutil -lint "$strings_file" >/dev/null
done

for localization_file in "$resources_path"/*.lproj/Localizable.strings; do
    extract_keys "$localization_file" > "$temporary_path/localization-keys"
    if ! diff -u "$temporary_path/reference-keys" "$temporary_path/localization-keys"; then
        echo "Localization keys differ in $localization_file" >&2
        exit 1
    fi
done

echo "Validated localization files."
