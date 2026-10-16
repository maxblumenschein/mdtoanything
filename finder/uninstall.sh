#!/bin/bash

# Remove the "Convert Markdown" Finder Quick Action

rm -rf "$HOME/Library/Services/Convert Markdown.workflow"
defaults delete com.mdtoanything.quickaction 2>/dev/null
/System/Library/CoreServices/pbs -update

echo "Removed the 'Convert Markdown' Quick Action."
