# Markdown to PDF (or Almost Anything Else)

Using Pandoc these custom Latex templates convert Markdown files (.md) to PDF, Word (.docx), InDesign (.icml) or almost anything else.

# Setup

## Latex Template File

Copy the desired template files to the ``/templates`` folder inside the Pandoc user data directory. On *nix and macOS systems this will most likely be: ``$HOME/.pandoc``. On Windows the default user data directory likely is ``%APPDATA%\pandoc``. You can find the user data directory on your system by looking at the output of pandoc --version.  

The Latex template files use variables to insert recurring information like author name or adress. To customize with individual information change the corresponding variables in the latex template:

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

If you intend to use these or other fonts not located in the standard system folders, you need specify the location of the font files inside the latex template:

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

## Markdown Input File

Specify general information like date, title, language and desired output format of the input Markdown file using a YAML header:

```yaml
---
title: The Triangulation of Titling
author: Max Blumenschein
date: \today

lang: de

documentclass: article

output:
  pdf_document: 
    template: info.latex

bibliography: "./literature.bib"
csl: "https://raw.githubusercontent.com/maxblumenschein/slick-csl/main/me.csl"
---
```

Available YAML-variables vary from template to template. For a full list see below:

### General (info.latex, linear.latex, letter.latex)

```yaml
title: main title

author: name of author
date: date [e.g. "\today"]
adress: features full adress [true,false]

project: works like a subtitle
abstract: abstract to be printed on title page

documentclass: style of document formatting [report,article]

toc: table of content [true,false]
lof: list of figures [true,false]
lot: list of tables [true,false]

bibliography: path to bibliography-file [e.g. "example.bib"]
nocite: prints all bibliographic entries, if cited or not ['@*']
csl: citation style

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
```

### Specify Output

#### PDF

```yaml
output:
  pdf_document:
    template: info.latex
```

this will export the PDF inside the same folder as the eponymous Markdown input file. If want to define a custom name and path, use:

```yaml
output:
  custom_document:
    path: customname.pdf
      template: info.latex
```

# Word

```yaml
output:
  word_document:
```

or for custom output path and name:

```yaml
output:
  custom_document:
    path: customname.docx
```

By default Pandoc uses ``reference.docx`` located inside the Pandoc user directory. You can customize the format styles inside to adjust the typesetting of Word output.

# InDesign

```yaml
output:
  custom_document:
    path: customname.icml

pandoc_args: ["-s", "-f", "markdown", "-t", "icml", "-o", "customname.icml"]
```

You can combine ``.icml`` and PDF and Word output by adding ``pandoc_args: ["-s", "-f", "markdown", "-t", "icml", "-o", "customname.icml"]``. This will export multiple files with one export command.
