#!/bin/bash

# Usage:
#   pandoc_convert                                   interactive prompts
#   pandoc_convert [-f format] [-t template] [-o output] input.md [more.md ...]

# Default template path and template
default_template_path="$HOME/.pandoc/templates/"
default_template="linear.latex"
pdf_engine="lualatex"
export OSFONTDIR="$HOME/Library/Fonts"

# Finder Quick Actions run with a minimal PATH, so add the usual tool locations
export PATH="/opt/homebrew/bin:/usr/local/bin:/Library/TeX/texbin:$PATH"

# Function to check if a URL is reachable
check_url() {
    curl --head --silent --fail --max-time 5 "$1" >/dev/null 2>&1
}

# Resolve the template file to a URL or local path (sets template_path)
resolve_template() {
    local template_file="$1" input_dir="$2"

    # Try to find the template online
    local online_template_url="https://raw.githubusercontent.com/maxblumenschein/mdtoanything/refs/heads/main/latex%20templates/$template_file"

    if check_url "$online_template_url"; then
        template_path="$online_template_url"
        return 0
    fi

    # If not found online, look for the template in the default template path
    template_path="$default_template_path$template_file"
    [ -f "$template_path" ] && return 0

    # If not found, look for the template in the input file directory
    template_path="$input_dir/$template_file"
    [ -f "$template_path" ] && return 0

    echo "Error: Template file '$template_file' not found online, in '$default_template_path', or in '$input_dir'."
    return 1
}

# Convert a single file: convert_file <input> <format> <template> [output]
convert_file() {
    local input_path="$1" output_format="$2" template_file="$3" output_path="$4"

    # Check if the input file exists
    if [ ! -f "$input_path" ]; then
        echo "Error: File '$input_path' not found."
        return 1
    fi

    # Get the absolute directory and path of the input file
    local input_dir
    input_dir=$(cd "$(dirname "$input_path")" && pwd)
    input_path="$input_dir/$(basename "$input_path")"

    # Use input path with appropriate extension if no output path is given
    if [ -z "$output_path" ]; then
        output_path="${input_path%.*}.$output_format"
    fi

    if [ "$output_format" == "pdf" ]; then
        resolve_template "${template_file:-$default_template}" "$input_dir" || return 1
    fi

    # Change the working directory to the input file directory
    cd "$input_dir" || { echo "Error: Failed to change directory to '$input_dir'"; return 1; }

    # Make the input directory visible to TeX for \input{user_variables_definition}
    export TEXINPUTS="$input_dir:$input_dir/resources:"

    local resource_path="$input_dir:$input_dir/resources"
    local pandoc_args=(-o "$output_path" --citeproc --standalone --resource-path="$resource_path")
    if [ "$output_format" == "pdf" ]; then
        pandoc_args+=(--template="$template_path" --pdf-engine="$pdf_engine")
    fi

    local status
    if command -v pandoc-crossref >/dev/null 2>&1; then
        # Run pandoc-crossref and citeproc in separate passes, so citeproc
        # resolves in-footnote citations (see examples/build)
        local crossref_json
        crossref_json="$(mktemp -t pandoc_crossref)"
        echo "Executing pandoc (pandoc-crossref + citeproc) in $input_dir"
        pandoc "$input_path" -t json --filter pandoc-crossref --resource-path="$resource_path" -o "$crossref_json" &&
            pandoc "$crossref_json" -f json "${pandoc_args[@]}"
        status=$?
        rm -f "$crossref_json"
    else
        echo "Executing pandoc in $input_dir"
        pandoc "$input_path" "${pandoc_args[@]}"
        status=$?
    fi

    # Check if pandoc succeeded
    if [ $status -eq 0 ]; then
        echo "Conversion successful! Output saved to '$output_path'."
    else
        echo "Error: Pandoc failed to convert '$input_path'."
    fi
    return $status
}

validate_format() {
    if [[ "$1" != "pdf" && "$1" != "docx" && "$1" != "icml" ]]; then
        echo "Error: Invalid output format '$1'. Supported formats are pdf, docx, icml."
        exit 1
    fi
}

# Interactive mode when called without arguments
if [ $# -eq 0 ]; then
    read -p "Enter the input file path: " input_path

    read -p "Enter the output format (pdf, docx, icml): " output_format
    validate_format "$output_format"

    read -p "Enter the output file path (leave blank to use input file path with .$output_format extension): " output_path

    if [ "$output_format" == "pdf" ]; then
        read -p "Enter the template file name (leave blank to use default: $default_template): " template_file
    fi

    convert_file "$input_path" "$output_format" "$template_file" "$output_path"
    exit $?
fi

# Non-interactive mode
output_format="pdf"
template_file=""
output_path=""
while getopts "f:t:o:" opt; do
    case $opt in
        f) output_format="$OPTARG" ;;
        t) template_file="$OPTARG" ;;
        o) output_path="$OPTARG" ;;
        *) echo "Usage: $0 [-f pdf|docx|icml] [-t template] [-o output] input.md [more.md ...]"; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

validate_format "$output_format"

if [ $# -eq 0 ]; then
    echo "Error: No input file given."
    exit 1
fi
if [ -n "$output_path" ] && [ $# -gt 1 ]; then
    echo "Error: -o can only be used with a single input file."
    exit 1
fi

failed=0
for input in "$@"; do
    # Run each conversion in a subshell so cd/exports don't leak between files
    ( convert_file "$input" "$output_format" "$template_file" "$output_path" ) || failed=$((failed + 1))
done
exit $failed
