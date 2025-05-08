#!/usr/bin/env bash
#set -euo pipefail

# Usage: ./scripts/ebook_pron.sh [--scheme SCHEME]
#   --scheme SCHEME: Use specified pronunciation scheme (cla, koi1, koi2, byz1, byz2)

# Parse command line arguments
SCHEME="cla"  # Default to Classical Greek pronunciation

while [[ $# -gt 0 ]]; do
  case $1 in
    --scheme)
      if [[ $# -gt 1 ]]; then
        SCHEME="$2"
        echo "Using pronunciation scheme: $SCHEME"
        shift 2
      else
        echo "Error: --scheme requires an argument"
        exit 1
      fi
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: ./scripts/ebook_pron.sh [--scheme SCHEME]"
      exit 1
      ;;
  esac
done

# Ensure docs directory
mkdir -p docs

# Convert Markdown to HTML, inject pronunciation, then generate EPUB
pandoc -s --toc --template=templates/default.html src/title.txt src/*.md | python3 scripts/md_to_html_with_ipa.py --interlinear --scheme "$SCHEME" | pandoc -s -f html -t epub3 --css=scripts/ebook.css -M toc-title="Table of Contents" -o docs/lgpsi_pron.epub --epub-embed-font=docs/NotoSansDisplay_Condensed-Regular.ttf
