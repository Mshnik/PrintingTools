#!/bin/bash

# Check for correct arguments
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <source_dir> <dest_dir> [extension_filter]"
    echo "Example: $0 ./data ./backup \"*.png\""
    exit 1
fi

# Use perl or standard shell logic if realpath isn't available
SRC_DIR=$(cd "$1" && pwd)
DEST_DIR=$(mkdir -p "$2" && cd "$2" && pwd)
FILTER=${3:-"*.png"}

echo "Searching for files matching: $FILTER"

# -R: Relative mode (preserves the path structure)
# -r: Recursive
# -m: Prune empty directories (prevents empty folders if no PNGs are inside)
# --include: Only include files matching our filter
# --exclude: Ignore everything else
rsync -Rrm --include="$FILTER" --include='*/' --exclude='*' "$SRC_DIR/./" "$DEST_DIR"

echo "Success! Filtered files copied to $DEST_DIR"
