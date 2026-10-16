#!/bin/bash

# Finder Quick Action: convert the selected Markdown files with pandoc_convert.sh.
# Called by "Convert Markdown.workflow" with the selected file paths as arguments.
# install.sh copies it into the workflow bundle next to pandoc_convert.sh and templates.txt.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONVERT="$SCRIPT_DIR/pandoc_convert.sh"
PREFS="com.mdtoanything.quickaction"

[ $# -eq 0 ] && exit 0

# Show a list picker; prints the choice, or nothing if cancelled.
# Finder shows the dialog: it is frontmost when the Quick Action runs, so the
# dialog gets keyboard focus right away.
choose() {
    local prompt="$1" default="$2"; shift 2
    osascript - "$prompt" "$default" "$@" <<'EOF'
on run argv
    set {thePrompt, theDefault} to {item 1 of argv, item 2 of argv}
    set theItems to items 3 thru -1 of argv
    if theItems does not contain theDefault then set theDefault to item 1 of theItems
    tell application "Finder"
        activate
        set theChoice to choose from list theItems with title "Convert Markdown" with prompt thePrompt default items {theDefault}
    end tell
    if theChoice is false then return ""
    return item 1 of theChoice
end run
EOF
}

# One list for format and template: "PDF – <template>" per template (names
# listed by install.sh), then the other formats
options=()
while IFS= read -r t; do
    options+=("PDF – $t")
done <"$SCRIPT_DIR/templates.txt"
options+=("Word (.docx)" "InDesign (.icml)")

last_choice=$(defaults read "$PREFS" choice 2>/dev/null || echo "PDF – linear")
choice=$(choose "Convert to:" "$last_choice" "${options[@]}")
[ -z "$choice" ] && exit 0
defaults write "$PREFS" choice "$choice"

template=""
case "$choice" in
    "PDF – "*) format="pdf"; template="${choice#PDF – }.latex" ;;
    "Word (.docx)") format="docx" ;;
    "InDesign (.icml)") format="icml" ;;
esac

count=$#
osascript -e "display notification \"Converting $count file(s) to $format…\" with title \"Convert Markdown\""

# Capture output in a temp file that is removed when the script exits
output=$(mktemp -t mdtoanything)
trap 'rm -f "$output"' EXIT

if "$CONVERT" -f "$format" ${template:+-t "$template"} "$@" >"$output" 2>&1; then
    osascript -e "display notification \"Converted $count file(s) to $format.\" with title \"Convert Markdown\""
else
    failed=$?
    choice=$(osascript - "$failed of $count file(s) failed to convert." "$(tail -n 15 "$output")" <<'EOF'
on run argv
    tell application "Finder"
        activate
        set theResult to display dialog (item 1 of argv) & return & return & (item 2 of argv) with title "Convert Markdown" buttons {"Copy Error", "OK"} default button "OK" with icon caution
    end tell
    return button returned of theResult
end run
EOF
)
    [ "$choice" == "Copy Error" ] && pbcopy <"$output"
fi
