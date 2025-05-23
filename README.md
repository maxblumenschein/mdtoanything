# Markdown to PDF (or Almost Anything Else)

Using Pandoc and custom Latex templates to convert Markdown files (.md) to PDF, Word (.docx), InDesign (.icml) or almost anything else.

# Setup

## User Defined Variables

The template files use variables to insert recurring information like author name or address. By default the variables are defined by ``user_variables_definition.tex`` inside the Pandoc ``/templates`` folder.

Change the corresponding variables to your individual data:

```latex
% define variables %
\def\name{Albert Einstein}
\def\institution{ETH Zürich}
\def\department{Institut für Teilchenphysik und Astrophysik}
\def\street{Otto-​Stern-Weg 5}
\def\city{Zürich}
\def\zipcode{CH-8093}
\def\phone{+41 78 881 86 11}
\def\email{albert.einstein@phys.ethz.ch}
```

### Inside Input Directory

``custom_author: true`` inside the [YAML header of the input file](#markdown-input-file) overwrites the path for user variables to the input directory, i.e. the Markdown file. This allows the definition of custom variables for special usecases, or if you want to have the variables stay with the input file in general.

### Inside Tex Directory

The variables can also be defined with a custom package inside your tex directory. This makes the user variables independent of your input directory.

#### Installation

1. **Copy** the folder ``/user_variables_definition`` inside ``/latex templates`` to your tex directory (under ``texmf/`` or ``texmf-local/``): ``tex/latex/``[^1]

2. **Update** your TeX index. For TeX Live, run: ``texhash``

3. **Add**/uncomment ``\usepackage{user_variables_definition}`` and **remove**/comment ``$if(custom_author)$\input{user_variables_definition}$else$\input{\string~/AppData/Roaming/pandoc/templates/user_variables_definition.tex}%Windows$endif$`` in the selected Latex template.

[^1]: see [LaTeX/Installing Extra Packages](https://en.wikibooks.org/wiki/LaTeX/Installing_Extra_Packages) for general information on installing custom packages.

## Fonts

Custom high-quality fonts are used for typesetting:
1. ``info.latex``:
    - ABC Diatype
    - ABC Diatype Mono
2. ``linear.latex``:
    - Söhne
    - LL Bradford
    - LL Bradford Mono
3. ``letter.latex``:
    - ABC Social
    - ABC Social Extended

Pandoc assumes these fonts to be installed on your system:

- macOS: ``/Library/Fonts/``
- Windows: ``C:\\Windows\Fonts``

### Custom Font Paths

If you intend to use these or other fonts not located in the standard system folders, you need to specify the location of the font files inside the latex template:

```latex
% define path-variables %
\def\fontpath{/windows/fonts}
```

Then include the custom font path inside the font settings:

```latex
\setmainfont[
Path = \fontpath,
ItalicFont = ABCDiatype-RegularItalic.otf,
BoldFont = ABCDiatype-Bold.otf,
BoldItalicFont  = ABCDiatype-BoldItalic.otf]
{ABCDiatype-Regular.otf}
```

## Latex Template File

For offline-functionality copy the desired template files to the ``/templates`` folder inside the Pandoc user data directory. On *nix and macOS systems this will most likely be: ``$HOME/.pandoc``. On Windows the default user data directory likely is ``$HOME\AppData\Roaming\pandoc``. You can find the user data directory on your system by looking at the output of ``pandoc --version``.

## Markdown Input File

Specify general information like date, title, language in the input Markdown file using a YAML header:

```yaml
---
title: The Triangulation of Titling
author: Max Blumenschein
date: \today

lang: de

documentclass: article

bibliography: "./literature.bib"
csl: "https://raw.githubusercontent.com/maxblumenschein/slick-csl/main/me.csl"
---
```

Available YAML-variables vary from template to template. For a full list see below:

### General (info.latex, linear.latex, letter.latex)

```yaml
title: main title

custom_author: user defined variables inside input directory [true,false]

date: date [e.g. "\today"]
address: features full address [true,false]

project: works like a subtitle
abstract: abstract to be printed on title page

documentclass: style of document formatting [report,article]

toc: table of content [true,false]
lof: list of figures [true,false]
lot: list of tables [true,false]
apx: attach file to output document ["path/to/file"]

bibliography: path to bibliography-file [e.g. "example.bib"]
nocite: prints all bibliographic entries, if cited or not ['@*']
csl: citation style
cref: latex cross-referencing [true,false]
```

### linear.latex

```yaml
titlepage: inserts a page break after the titlepage [true,false]
```

### letter.latex

```yaml
to: addressee
[e.g. " |
  | NASA Headquarters
  | 300 E Street SW
  | Washington, D.C."]
invoice: include bank account information before complimentary close [true,false]
reference: reference code [e.g. "Nr. 2023.12.0004"]
cv: inserts author info and changes layout accordingly [true,false]
skills: inserts author´s skills info [e.g. "English C1"]
```

## Scripting

The Bash script ``pandoc_convert.sh`` inside ``/script`` converts from and to the common formats ``.pdf``, ``.docx`` and ``.icml``. It allows easy control over file conversion for various formats while automating common Pandoc tasks and setting necessary arguments.
It prompts the user for a input file path, output path (defaulting to the input path if left blank), output format and desired template (if needed).

### Setup

1. Setup default default template path, template (e.g. ``linear.latex``) and pdf-engine (e.g. lualatex) of ``pandoc_convert.sh``.

2. To make the script executable, run the following command:

```bash
chmod +x pandoc_convert.sh
```

3.  Optionally, move the script to a location in your system's PATH (e.g., /usr/local/bin) so it can be run from anywhere:

```bash
sudo mv pandoc_convert.sh /usr/local/bin/pandoc_convert
```

4. Run the script from the terminal:

```
pandoc_convert
```
