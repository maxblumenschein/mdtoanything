#!/bin/bash

# Setup wizard: guides through everything needed to convert Markdown files with
# pandoc_convert.sh or the Finder Quick Action on a fresh Mac.
# Run it with: bash setup.sh
# Every step checks first and only offers to change what is missing, so it is
# safe to run again at any time.

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES_DIR="$REPO_DIR/latex templates"
EXAMPLES_DIR="$REPO_DIR/examples"
CONVERT="$REPO_DIR/script/pandoc_convert.sh"
PANDOC_TEMPLATES="$HOME/.pandoc/templates"

# LaTeX packages for BasicTeX (MacTeX already includes everything)
TL_PACKAGES="adjustbox collectbox appendix babel-german babel-english hyphen-german
booktabs caption cleveref enumitem environ eso-pic etoolbox fancyhdr float fontspec
footmisc geometry hyperref iflang koma-script lastpage lm luaotfload mdframed
microtype needspace pdfcol pdfpages pgf pgfplots ragged2e setspace soul tcolorbox
textpos titlesec titling tocloft trimspaces ulem url wrapfig xcolor xpatch zref"

# Output helpers
bold=$(tput bold 2>/dev/null) dim=$(tput dim 2>/dev/null) reset=$(tput sgr0 2>/dev/null)
green=$(tput setaf 2 2>/dev/null) red=$(tput setaf 1 2>/dev/null) yellow=$(tput setaf 3 2>/dev/null)

step_no=0
step() { step_no=$((step_no + 1)); echo; echo "${bold}[$step_no/8] $1${reset}"; }
ok() { echo "  ${green}✓${reset} $1"; }
fail() { echo "  ${red}✗${reset} $1"; }
warn() { echo "  ${yellow}!${reset} $1"; }
info() { echo "  ${dim}$1${reset}"; }

# ask "question" [y|n]: returns 0 for yes; the second argument is the default
ask() {
    local default="${2:-y}" hint="[Y/n]" answer
    [ "$default" == "n" ] && hint="[y/N]"
    read -r -p "  $1 $hint " answer
    answer="${answer:-$default}"
    [[ "$answer" == [Yy]* ]]
}

pause() { read -r -p "  ${1:-Press Return to continue…} " _; }

# Make tools installed during this run available right away
refresh_path() {
    [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
    [ -x /usr/local/bin/brew ] && eval "$(/usr/local/bin/brew shellenv)"
    export PATH="/Library/TeX/texbin:$PATH"
}

# Font files a template loads (ignores commented lines)
template_fonts() {
    grep -v '^[[:space:]]*%' "$1" | grep -o '[^][{}=, %]*\.\(otf\|ttf\)' | sort -u
}

# Is a font file where LuaTeX looks? The active fonts were linked by
# link_active_fonts from pandoc_convert.sh
font_found() {
    local d
    for d in "$HOME/Library/Fonts" /Library/Fonts /System/Library/Fonts "$font_link_dir"; do
        [ -e "$d/$1" ] && return 0
        [ -n "$(find "$d" -name "$1" -print -quit 2>/dev/null)" ] && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------

clear 2>/dev/null
echo "${bold}mdtoanything setup${reset}"
echo
echo "This wizard sets up everything needed to convert Markdown files to PDF,"
echo "Word and InDesign, from the Terminal or with a right-click in Finder:"
echo
echo "  1. Homebrew (installs the other tools)   5. Fonts used by the templates"
echo "  2. Pandoc (the converter)                6. The pandoc_convert command"
echo "  3. LaTeX (typesets the PDFs)             7. The Finder Quick Action"
echo "  4. Templates and your personal details   8. A test conversion"
echo
echo "Nothing is changed without asking first. Some steps ask for your Mac password."
echo
ask "Start?" || exit 0

if [ "$(uname)" != "Darwin" ]; then
    fail "This wizard is for macOS. See README.md for setting up other systems."
    exit 1
fi
refresh_path

# 1. Homebrew ----------------------------------------------------------------
step "Homebrew"
if command -v brew >/dev/null 2>&1; then
    ok "Homebrew is installed."
else
    info "Homebrew is the standard way to install command line tools on a Mac (brew.sh)."
    if ask "Install Homebrew now?"; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        refresh_path
    fi
    if ! command -v brew >/dev/null 2>&1; then
        fail "Homebrew is required for the next steps. Install it from https://brew.sh and run this wizard again."
        exit 1
    fi
    ok "Homebrew is installed."
fi

# New Terminal windows need Homebrew on their PATH too
if ! grep -qs "brew shellenv" "$HOME/.zprofile"; then
    if ask "Make Homebrew tools available in new Terminal windows (adds one line to ~/.zprofile)?"; then
        echo "eval \"\$($(command -v brew) shellenv)\"" >>"$HOME/.zprofile"
        ok "Added Homebrew to ~/.zprofile."
    fi
fi

# 2. Pandoc ------------------------------------------------------------------
step "Pandoc"
for tool in pandoc pandoc-crossref; do
    if command -v "$tool" >/dev/null 2>&1; then
        ok "$tool is installed."
    elif ask "Install $tool?"; then
        brew install "$tool" && ok "$tool is installed." || fail "Installing $tool failed."
    fi
done
if ! command -v pandoc >/dev/null 2>&1; then
    fail "Pandoc is required. Run this wizard again to install it."
    exit 1
fi

# 3. LaTeX -------------------------------------------------------------------
step "LaTeX"
if command -v lualatex >/dev/null 2>&1; then
    ok "LaTeX (lualatex) is installed."
else
    info "PDFs are typeset with LaTeX. Choose a distribution:"
    info "  1) MacTeX   – everything included, about 6 GB download (recommended)"
    info "  2) BasicTeX – about 300 MB, then only the packages the templates need"
    info "  3) Skip     – Word and InDesign conversion still work"
    read -r -p "  Choice [1]: " tex_choice
    case "${tex_choice:-1}" in
        1) brew install --cask mactex-no-gui ;;
        2) brew install --cask basictex ;;
    esac
    refresh_path
    command -v lualatex >/dev/null 2>&1 && ok "LaTeX (lualatex) is installed."
fi

if command -v lualatex >/dev/null 2>&1; then
    # Check that every package the templates use is available
    missing_sty=""
    for sty in $(grep -ho '\\usepackage\(\[[^]]*\]\)\?{[^}]*}' "$TEMPLATES_DIR"/*.latex |
        sed 's/.*{\(.*\)}/\1/' | tr ',' '\n' | sort -u); do
        [ "$sty" == "user_variables_definition" ] && continue
        kpsewhich "$sty.sty" >/dev/null 2>&1 || missing_sty="$missing_sty $sty"
    done
    if [ -z "$missing_sty" ]; then
        ok "All LaTeX packages used by the templates are available."
    else
        warn "Missing LaTeX packages:$missing_sty"
        if ask "Install the packages the templates need (with tlmgr, asks for your password)?"; then
            sudo tlmgr update --self
            # shellcheck disable=SC2086
            sudo tlmgr install $TL_PACKAGES
        fi
        still_missing=""
        for sty in $missing_sty; do
            kpsewhich "$sty.sty" >/dev/null 2>&1 || still_missing="$still_missing $sty"
        done
        if [ -z "$still_missing" ]; then
            ok "All LaTeX packages used by the templates are available."
        else
            fail "Still missing:$still_missing"
            info "Find the package containing a file with: tlmgr search --global --file <name>.sty"
        fi
    fi
fi

# 4. Templates and personal details ------------------------------------------
step "Templates and personal details"
mkdir -p "$PANDOC_TEMPLATES"

# Templates are loaded from GitHub when online; a local copy works offline
outdated=""
for t in "$TEMPLATES_DIR"/*.latex; do
    cmp -s "$t" "$PANDOC_TEMPLATES/$(basename "$t")" || outdated="$outdated $(basename "$t")"
done
if [ -z "$outdated" ]; then
    ok "Templates for offline use are up to date in ~/.pandoc/templates."
elif ask "Copy the templates to ~/.pandoc/templates for offline use (new or changed:$outdated)?"; then
    cp "$TEMPLATES_DIR"/*.latex "$PANDOC_TEMPLATES/" && ok "Templates copied."
fi

# Your name, address etc. used by letters and documents
variables="$PANDOC_TEMPLATES/user_variables_definition.tex"
if [ ! -f "$variables" ]; then
    cp "$TEMPLATES_DIR/user_variables_definition.tex" "$variables"
    ok "Created your personal details file: ~/.pandoc/templates/user_variables_definition.tex"
else
    ok "Your personal details file exists: ~/.pandoc/templates/user_variables_definition.tex"
fi
if grep -q "Albert Einstein" "$variables"; then
    warn "It still contains the example details (Albert Einstein)."
fi
if ask "Open it in TextEdit to enter your name, address and bank details?" "$(grep -q 'Albert Einstein' "$variables" && echo y || echo n)"; then
    open -e "$variables"
    info "Replace the values between the braces, e.g. \\def\\name{Your Name}, then save."
    pause "Press Return when you have saved the file…"
fi

# 5. Fonts -------------------------------------------------------------------
step "Fonts"
info "The templates use commercial fonts that are not included. Install them in"
info "~/Library/Fonts (double-click a font file → Install), or activate them in your font manager."

# Load the font linking from pandoc_convert.sh (links active fonts, sets font_link_dir)
# shellcheck source=script/pandoc_convert.sh
. "$CONVERT"

usable_templates=""
while true; do
    link_active_fonts
    usable_templates="" any_missing=""
    for t in "$TEMPLATES_DIR"/*.latex; do
        name=$(basename "$t" .latex) missing=""
        for f in $(template_fonts "$t"); do
            font_found "$f" || missing="$missing $f"
        done
        if [ -z "$missing" ]; then
            ok "$name: all fonts found"
            usable_templates="$usable_templates $name"
        else
            fail "$name: missing$missing"
            any_missing=1
        fi
    done
    [ -z "$any_missing" ] && break
    info "Fonts must have exactly these file names. Install or activate them, then check again."
    ask "Check fonts again?" || break
done

# 6. pandoc_convert command --------------------------------------------------
step "The pandoc_convert command"
# Update an existing copy on the PATH, otherwise install into Homebrew's bin folder.
# A copy (not a link) keeps working when this folder is moved or deleted
command_path="$(command -v pandoc_convert 2>/dev/null)"
[ -z "$command_path" ] && command_path="$(brew --prefix)/bin/pandoc_convert"
if cmp -s "$command_path" "$CONVERT"; then
    ok "pandoc_convert is installed and up to date ($command_path)."
elif ask "$([ -e "$command_path" ] && echo "Update" || echo "Install") the pandoc_convert Terminal command ($command_path)?"; then
    rm -f "$command_path"
    cp "$CONVERT" "$command_path" && chmod +x "$command_path" &&
        ok "Installed. Try: pandoc_convert -f pdf -t letter.latex file.md"
    info "Run this wizard again after updating the repo to update the command."
fi

# 7. Finder Quick Action -----------------------------------------------------
step "The Finder Quick Action"
info "Adds right-click → Quick Actions → Convert Markdown… for .md files in Finder."
workflow="$HOME/Library/Services/Convert Markdown.workflow"
installed_script="$workflow/Contents/Resources/pandoc_convert.sh"
if [ -f "$installed_script" ] && cmp -s "$installed_script" "$CONVERT"; then
    ok "The Quick Action is installed and up to date."
elif ask "$([ -d "$workflow" ] && echo "Update" || echo "Install") the Finder Quick Action?"; then
    "$REPO_DIR/finder/install.sh" >/dev/null && ok "Quick Action installed."
    info "The first time you use it, macOS asks to let it control Finder and to access"
    info "your files (and possibly iCloud Drive for fonts). Allow these."
fi

# 8. Test conversion ---------------------------------------------------------
step "Test conversion"
test_dir="$HOME/Desktop/mdtoanything test"
if ask "Convert the examples to check everything works (saved to ~/Desktop/mdtoanything test)?"; then
    mkdir -p "$test_dir"
    log=$(mktemp -t mdtoanything_setup)
    trap 'rm -f "$log"' EXIT

    # convert_test <label> <format> <example> [template]
    convert_test() {
        local out="$test_dir/$1.$2"
        if "$CONVERT" -f "$2" ${4:+-t "$4.latex"} -o "$out" "$EXAMPLES_DIR/$3" >"$log" 2>&1; then
            ok "$1"
        else
            fail "$1"
            grep -E '^!|cannot be found|Error' "$log" | grep -v '^Error: Pandoc failed' | head -3 | sed 's/^/      /'
        fi
    }

    convert_test "word" docx text_example.md
    if command -v lualatex >/dev/null 2>&1; then
        for t in $usable_templates; do
            case "$t" in
                letter) example=letter_example.md ;;
                label*) example=label_example.md ;;
                *) example=text_example.md ;;
            esac
            convert_test "$t" pdf "$example" "$t"
        done
        for t in "$TEMPLATES_DIR"/*.latex; do
            name=$(basename "$t" .latex)
            [[ " $usable_templates " == *" $name "* ]] || warn "$name: skipped, fonts missing"
        done
    else
        warn "PDF: skipped, LaTeX is not installed"
    fi
    open "$test_dir"
fi

echo
echo "${bold}Done.${reset} Convert files with:"
echo "  • Finder: right-click .md files → Quick Actions → Convert Markdown…"
echo "  • Terminal: pandoc_convert (asks for everything) or pandoc_convert -f pdf -t letter.latex file.md"
echo "Run this wizard again any time to check or repair the setup."
