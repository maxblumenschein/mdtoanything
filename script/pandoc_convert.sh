#!/bin/bash

# Usage:
#   pandoc_convert                                   interactive prompts
#   pandoc_convert [-f format] [-t template] [-o output] input.md [more.md ...]

# Default template path and template
default_template_path="$HOME/.pandoc/templates/"
default_template="linear.latex"
pdf_engine="lualatex"

# Folder where active fonts are linked for LuaTeX (fonts activated by font managers)
font_link_dir="$HOME/Library/Caches/mdtoanything/fonts"

# Finder Quick Actions run with a minimal PATH, so add the usual tool locations
export PATH="/opt/homebrew/bin:/usr/local/bin:/Library/TeX/texbin:$PATH"

# Function to check if a URL is reachable
check_url() {
    curl --head --silent --fail --max-time 5 "$1" >/dev/null 2>&1
}

# Link the fonts macOS reports as active into $font_link_dir. LuaTeX only scans
# the standard font folders, so fonts activated in place by a font manager are
# invisible to it; their folders often can't be listed either (e.g. iCloud Drive)
link_active_fonts() {
    command -v osascript >/dev/null 2>&1 || return 0
    rm -rf "$font_link_dir"
    mkdir -p "$font_link_dir" || return 0

    osascript -l JavaScript -e '
        ObjC.import("CoreText");
        const urls = ObjC.castRefToObject($.CTFontManagerCopyAvailableFontURLs());
        const home = $.NSHomeDirectory().js;
        const std = ["/System/Library/Fonts/", "/Library/Fonts/", home + "/Library/Fonts/"];
        const paths = new Set();
        for (let i = 0; i < urls.count; i++) {
            const p = urls.objectAtIndex(i).path.js;
            if (!std.some(s => p.startsWith(s))) paths.add(p);
        }
        [...paths].join("\n")' 2>/dev/null |
        while IFS= read -r font; do
            [ -n "$font" ] && ln -sf "$font" "$font_link_dir/"
        done
}

link_active_fonts
export OSFONTDIR="$HOME/Library/Fonts:$font_link_dir"

# Output helpers; colors only in a terminal, so captured output stays plain
start_dir="$PWD"
if [ -t 1 ]; then
    bold=$(tput bold) dim=$(tput dim) reset=$(tput sgr0) green=$(tput setaf 2) red=$(tput setaf 1)
fi
success() { echo "${green}✓${reset} $1"; }
error() { echo "${red}✗${reset} $1"; }

# Path for display: relative to the start folder if inside it, else with ~
show_path() {
    local p="${1#"$start_dir"/}"
    [[ "$p" == "$HOME"/* ]] && p="~${p#"$HOME"}"
    echo "$p"
}

# Shell-quote arguments so a printed command can be copied and run
quote_args() {
    local arg out=()
    for arg in "$@"; do
        if [[ "$arg" == "$HOME"/* ]]; then
            out+=("~/$(printf '%q' "${arg#"$HOME"/}")")
        else
            out+=("$(printf '%q' "$arg")")
        fi
    done
    echo "${out[*]}"
}

# Print the pandoc command on its own line, set off by blank lines, so it can
# be selected (triple-click) and copied to run the conversion again
show_command() {
    echo
    echo "${dim}Raw pandoc command (copy to run it again):${reset}"
    echo "${bold}$1${reset}"
    echo
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

    error "Template not found: $template_file (looked online, in $(show_path "$default_template_path") and in $(show_path "$input_dir"))"
    return 1
}

# Convert a single file: convert_file <input> <format> <template> [output]
convert_file() {
    local input_path="$1" output_format="$2" template_file="$3" output_path="$4"

    # Check if the input file exists
    if [ ! -f "$input_path" ]; then
        error "File not found: $(show_path "$input_path")"
        return 1
    fi

    # Get the absolute directory and file name of the input file
    local input_dir input_name
    input_dir=$(cd "$(dirname "$input_path")" && pwd)
    input_name=$(basename "$input_path")

    # Use input path with appropriate extension if no output path is given;
    # a relative output path is relative to the current folder
    if [ -z "$output_path" ]; then
        output_path="$input_dir/${input_name%.*}.$output_format"
    elif [[ "$output_path" != /* ]]; then
        output_path="$PWD/$output_path"
    fi

    if [ "$output_format" == "pdf" ]; then
        resolve_template "${template_file:-$default_template}" "$input_dir" || return 1
    fi

    # Run pandoc in the input directory, so the command uses relative paths
    local cd_prefix=""
    [ "$input_dir" != "$PWD" ] && cd_prefix="cd $(quote_args "$input_dir") && "
    cd "$input_dir" || { error "Could not open folder: $(show_path "$input_dir")"; return 1; }

    # Make the input directory visible to TeX for \input{user_variables_definition}
    export TEXINPUTS="$input_dir:$input_dir/resources:"

    local resource_path=".:resources"
    local pandoc_args=(-o "${output_path#"$input_dir"/}" --citeproc --standalone --resource-path="$resource_path")
    if [ "$output_format" == "pdf" ]; then
        pandoc_args+=(--template="$template_path" --pdf-engine="$pdf_engine")
    fi

    local status
    if command -v pandoc-crossref >/dev/null 2>&1; then
        # Run pandoc-crossref and citeproc in separate passes, so citeproc
        # resolves in-footnote citations (see examples/build). pandoc-crossref
        # needs the target format, otherwise it numbers captions itself
        local crossref_format="$output_format"
        [ "$output_format" == "pdf" ] && crossref_format="latex"
        local to_json=(pandoc "$input_name" -t json --resource-path="$resource_path")
        local crossref=(pandoc-crossref --pipe "$crossref_format")
        local from_json=(pandoc -f json "${pandoc_args[@]}")
        show_command "$cd_prefix$(quote_args "${to_json[@]}") | $(quote_args "${crossref[@]}") | $(quote_args "${from_json[@]}")"
        (set -o pipefail; "${to_json[@]}" | "${crossref[@]}" | "${from_json[@]}")
        status=$?
    else
        local command=(pandoc "$input_name" "${pandoc_args[@]}")
        show_command "$cd_prefix$(quote_args "${command[@]}")"
        "${command[@]}"
        status=$?
    fi

    # Check if pandoc succeeded
    if [ $status -eq 0 ]; then
        success "Saved $(show_path "$output_path")"
    else
        error "pandoc failed for $(show_path "$input_dir/$input_name")"
        echo "${dim}If a font \"cannot be found\", install or activate it in your font manager, then run again.${reset}"
    fi
    return $status
}

validate_format() {
    if [[ "$1" != "pdf" && "$1" != "docx" && "$1" != "icml" ]]; then
        error "Unknown format: $1 (use pdf, docx or icml)"
        exit 1
    fi
}

# Stop here when sourced (setup.sh reuses the settings and functions above,
# so don't define names it has too, like ask, ok or fail, above this line)
return 0 2>/dev/null

# Menu picker: choose <prompt> <default> <options...>; prints the chosen option.
# ↑/↓ or Tab/Shift-Tab move, Return selects. The menu is drawn on stderr
choose() {
    local prompt="$1" default="$2"; shift 2
    local options=("$@") n=$# i=0 k key
    for ((k = 0; k < n; k++)); do [ "${options[k]}" == "$default" ] && i=$k; done

    tput civis >&2
    echo "$prompt: ${dim}(↑/↓ Tab, Return)${reset}" >&2
    while true; do
        for ((k = 0; k < n; k++)); do
            if [ $k -eq $i ]; then
                printf '  \e[7m> %s \e[0m\n' "${options[k]}" >&2
            else
                printf '    %s\n' "${options[k]}" >&2
            fi
        done
        IFS= read -rsn1 key
        case "$key" in
            "") break ;;
            $'\t') i=$(((i + 1) % n)) ;;
            $'\e')
                read -rsn2 key
                case "$key" in
                    "[A" | "[Z") i=$(((i + n - 1) % n)) ;;
                    "[B") i=$(((i + 1) % n)) ;;
                esac ;;
        esac
        printf '\e[%dA' "$n" >&2
    done

    # Collapse the menu into a single answered line
    printf '\e[%dA\e[J%s: %s\n' $((n + 1)) "$prompt" "${options[i]}" >&2
    tput cnorm >&2
    echo "${options[i]}"
}

# Text prompt: ask <variable> <prompt> [default]. Tab completes paths, Return
# takes the default; the line is then rewritten as "<prompt>: <answer>"
ask() {
    local answer
    read -e -p "$2${3:+ [$(show_path "$3")]}: " answer
    answer="${answer:-$3}"
    printf '\e[1A\e[K%s: %s\n' "$2" "$(show_path "$answer")" >&2
    printf -v "$1" '%s' "${answer/#\~/$HOME}"
}

# Interactive mode when called without arguments
if [ $# -eq 0 ]; then
    # Show the cursor again if a menu is cancelled with Ctrl-C
    trap 'tput cnorm' EXIT

    # Return takes the newest Markdown file in the current folder
    default_input=$(ls -t ./*.md 2>/dev/null | head -n 1)
    ask input_path "Input file" "${default_input#./}"

    output_format=$(choose "Output format" pdf pdf docx icml)

    if [ "$output_format" == "pdf" ]; then
        # Templates installed by setup.sh or next to the input file
        templates=()
        while IFS= read -r t; do
            templates+=("$t")
        done < <(for t in "$default_template_path"*.latex "$(dirname "$input_path")"/*.latex; do
            [ -f "$t" ] && basename "$t"
        done | sort -u)

        if [ ${#templates[@]} -gt 0 ]; then
            template_file=$(choose "Template" "$default_template" "${templates[@]}")
        else
            ask template_file "Template" "$default_template"
        fi
    fi

    ask output_path "Output file" "${input_path%.*}.$output_format"

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
        *) echo "Usage: $(basename "$0") [-f pdf|docx|icml] [-t template] [-o output] input.md [more.md ...]"; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

validate_format "$output_format"

if [ $# -eq 0 ]; then
    error "No input file given"
    exit 1
fi
if [ -n "$output_path" ] && [ $# -gt 1 ]; then
    error "-o only works with a single input file"
    exit 1
fi

failed=0
for input in "$@"; do
    # Run each conversion in a subshell so cd/exports don't leak between files
    ( convert_file "$input" "$output_format" "$template_file" "$output_path" ) || failed=$((failed + 1))
done
exit $failed
