#!/bin/bash

# Mikrus Toolbox - File Sync Helper
# Easy wrapper around rsync for uploading/downloading files.
# Usage: 
#   ./sync.sh up <local_path> <remote_path>
#   ./sync.sh down <remote_path> <local_path>

MIKRUS_HOST="mikrus"

DIRECTION=$1
SRC=$2
DEST=$3

print_usage() {
    echo "Usage:"
    echo "  Upload:   $0 up   <local_path> <remote_path>"
    echo "  Download: $0 down <remote_path> <local_path>"
    echo ""
    echo "Example:"
    echo "  $0 up ./my-website /var/www/html"
    exit 1
}

if [ -z "$DIRECTION" ] || [ -z "$SRC" ] || [ -z "$DEST" ]; then
    print_usage
fi

echo "🔄 Syncing ($DIRECTION)..."

if [ "$DIRECTION" == "up" ]; then
    # Upload: Local -> Remote
    if [ ! -e "$SRC" ]; then
        echo "❌ Local source '$SRC' does not exist."
        exit 1
    fi
    # -a: archive mode (permissions, dates)
    # -v: verbose
    # -z: compress
    # -P: progress bar
    rsync -avzP "$SRC" "$MIKRUS_HOST:$DEST"

elif [ "$DIRECTION" == "down" ]; then
    # Download: Remote -> Local
    rsync -avzP "$MIKRUS_HOST:$SRC" "$DEST"

else
    echo "❌ Invalid direction. Use 'up' or 'down'."
    print_usage
fi

echo "✅ Sync completed."
