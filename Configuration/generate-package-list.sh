#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
OUTPUT_PATH="${1:-$PROJECT_ROOT/Haptics/Resources}"

if ! command -v swift-package-list >/dev/null 2>&1; then
    echo "warning: swift-package-list not installed" >&2
    exit 0
fi

mkdir -p "$OUTPUT_PATH"

swift-package-list "$PROJECT_ROOT/Haptics.xcodeproj" \
    --output-type settings-bundle \
    --output-path "$OUTPUT_PATH" \
    --requires-license
