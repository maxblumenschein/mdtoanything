#!/bin/bash

# Install the mdtoanything templates for Zed as snippets tpl-<name>
# (Cmd-N, type tpl-letter, Tab through the fields). A copy of the templates is
# kept in ~/.config/zed/mdtoanything so setup.sh can tell whether they are up
# to date. Re-run after changing the templates.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$HOME/.config/zed/mdtoanything"

rm -rf "$TARGET"
mkdir -p "$TARGET"

cp -R "$SCRIPT_DIR/templates" "$TARGET/"

python3 "$SCRIPT_DIR/zed_config.py" install "$TARGET/templates" || exit 1

echo "Installed the Zed templates."
echo "Snippet: Cmd-N, type tpl-<name>, Enter, then Tab through the fields."
