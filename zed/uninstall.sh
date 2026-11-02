#!/bin/bash

# Remove the mdtoanything snippets from Zed; other snippets are kept.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

python3 "$SCRIPT_DIR/zed_config.py" uninstall || exit 1
rm -rf "$HOME/.config/zed/mdtoanything"

echo "Removed the Zed templates."
