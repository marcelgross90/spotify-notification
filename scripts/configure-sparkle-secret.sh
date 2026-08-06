#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
key_tool="$project_root/.build/artifacts/sparkle/Sparkle/bin/generate_keys"
temporary_key="$(mktemp)"

trap 'rm -f "$temporary_key"' EXIT

if ! command -v gh >/dev/null 2>&1; then
    echo "GitHub CLI is required: https://cli.github.com/" >&2
    exit 1
fi

"$key_tool" \
    --account de.marcelgross.SpotifyNotification \
    -x "$temporary_key"

gh secret set SPARKLE_PRIVATE_KEY \
    --repo marcelgross90/spotify-notification \
    < "$temporary_key"

echo "Configured the SPARKLE_PRIVATE_KEY repository secret."
