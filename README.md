# Linguae Graecae Per Se Illustrata (with IPA)

LGPSI: An open, expansive Greek-reading composition project

## Build an epub file

This requires [pandoc][1].

    $ bash scripts/ebook.sh

## Build PDF file

This requires [pandoc][1], xelatex, and the [SBL Greek font][2].

    $ bash scripts/pdf.sh

[1]: https://pandoc.org/
[2]: https://www.sbl-site.org/educational/BiblicalFonts_SBLGreek.aspx


## Transcription

Transcription is generated using Wiktionary Module [grc-pron](https://en.wiktionary.org/wiki/Module:grc-pron). The Lua script [grc-pron_wasm_local.lua](scripts/lua/grc-pron_wasm_local.lua) is a local copy of the [grc-pron](https://en.wiktionary.org/wiki/Module:grc-pron) module that can be run offline.

The same five dialects are supported:

- cla - Classical Greek (5th BCE Attic)
- koi1 - Early Koine (1st CE Egyptian)
- koi2 - Late Koine (4th CE)
- byz1 - Middle Byzantine (10th CE)
- byz2 - Late Byzantine (15th CE Constantinopolitan)

## Build PDF file with IPA

This requires pandoc, xelatex and Ghostscript, lua>=5.4, python>=3.7

```bash
# Build with Classical Greek pronunciation (default)
$ bash scripts/pdf_pron.sh

# Build with a specific pronunciation scheme
$ bash scripts/pdf_pron.sh --scheme koi1

# To preserve temporary files for debugging:
$ bash scripts/pdf_pron.sh --debug
```

The final PDF will be at docs/lgpsi_pron.pdf

## Build HTML file with IPA

This requires pandoc, lua>=5.4, python>=3.7

```bash
# Build with Classical Greek pronunciation (default)
$ bash scripts/html_pron.sh

# Build with a specific pronunciation scheme
$ bash scripts/html_pron.sh --scheme byz1
```

The final HTML will be at docs/*.html

## Build EPUB file with IPA

This requires pandoc, lua>=5.4, python>=3.7

```bash
# Build with Classical Greek pronunciation (default)
$ bash scripts/ebook_pron.sh

# Build with a specific pronunciation scheme
$ bash scripts/ebook_pron.sh --scheme koi2
```

The final EPUB will be at docs/lgpsi_pron.epub




