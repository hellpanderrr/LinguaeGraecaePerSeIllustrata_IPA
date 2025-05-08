#!/bin/bash
# Process all chapters using the simple_chapter.sh script
# Usage: ./scripts/pdf_pron.sh [--debug] [--scheme SCHEME]
#   --debug: Keep temporary single chapter files and folder after combining
#   --scheme SCHEME: Use specified pronunciation scheme (cla, koi1, koi2, byz1, byz2)

# Parse command line arguments
DEBUG_MODE=false
SCHEME="cla"  # Default to Classical Greek pronunciation

while [[ $# -gt 0 ]]; do
  case $1 in
    --debug)
      DEBUG_MODE=true
      echo "Debug mode enabled: Temporary files will be preserved"
      shift
      ;;
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
      echo "Usage: ./scripts/pdf_pron.sh [--debug] [--scheme SCHEME]"
      exit 1
      ;;
  esac
done

# Ensure the output directory exists
OUTPUT_DIR="docs/simple_chapters"
mkdir -p "$OUTPUT_DIR"

# Process Markdown files to add transcription
echo "Processing Markdown files with md_to_tex_with_ipa.py using scheme $SCHEME..."
python3 scripts/md_to_tex_with_ipa.py -o docs/processed_src --scheme "$SCHEME"

# Get a list of all processed Markdown files
MD_FILES=($(ls -v docs/processed_src/*.md))
echo "Found ${#MD_FILES[@]} Markdown files to process"

# Process each chapter
for md_file in "${MD_FILES[@]}"; do
    # Extract the chapter number from the filename
    chapter_num=$(basename "$md_file" .md)
    echo "Processing chapter $chapter_num..."

    # Run the simple_chapter.sh script for this chapter with the selected scheme
    bash scripts/simple_chapter.sh "$chapter_num" "$SCHEME"
done

# Combine all PDFs into a single file using pdftk to preserve bookmarks
echo "Combining PDFs..."

# Create a list of PDF files to combine
PDF_LIST=""
for pdf in "${OUTPUT_DIR}"/*.pdf; do
    if [ -f "$pdf" ] && [[ "$pdf" != *"combine_pdfs.pdf"* ]]; then
        PDF_LIST="$PDF_LIST $pdf"
        echo "Adding $pdf to combined PDF"
    fi
done

# Check if Ghostscript is installed
if command -v gs >/dev/null 2>&1; then
    echo "Using Ghostscript to combine PDFs"
    # Create a list of PDF files for Ghostscript
    GS_PDF_LIST=""
    for pdf in $PDF_LIST; do
        GS_PDF_LIST="$GS_PDF_LIST -f $pdf"
    done

    # Use Ghostscript to combine PDFs
    gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -dPDFSETTINGS=/prepress -sOutputFile="${OUTPUT_DIR}/combined_gs.pdf" $GS_PDF_LIST

    # Copy the combined PDF to the docs directory
    cp "${OUTPUT_DIR}/combined_gs.pdf" docs/lgpsi_pron.pdf
    echo "Combined PDFs into docs/lgpsi_pron.pdf using Ghostscript"
elif command -v qpdf >/dev/null 2>&1; then
    echo "Using qpdf to combine PDFs with preserved bookmarks"
    # Use qpdf to combine PDFs (this preserves bookmarks)
    qpdf --empty --pages $PDF_LIST -- "${OUTPUT_DIR}/combined_with_bookmarks.pdf"

    # Copy the combined PDF to the docs directory
    cp "${OUTPUT_DIR}/combined_with_bookmarks.pdf" docs/lgpsi_pron.pdf
    echo "Combined PDFs into docs/lgpsi_pron.pdf with preserved bookmarks"
elif command -v pdftk >/dev/null 2>&1; then
    echo "Using pdftk to combine PDFs with preserved bookmarks"
    # Use pdftk to combine PDFs (this preserves bookmarks)
    pdftk $PDF_LIST cat output "${OUTPUT_DIR}/combined_with_bookmarks.pdf"

    # Copy the combined PDF to the docs directory
    cp "${OUTPUT_DIR}/combined_with_bookmarks.pdf" docs/lgpsi_pron.pdf
    echo "Combined PDFs into docs/lgpsi_pron.pdf with preserved bookmarks"
else
    echo "No PDF tools found (Ghostscript, qpdf, pdftk), falling back to pdfunite"
    # Use pdfunite as a fallback (doesn't preserve bookmarks)
    pdfunite $PDF_LIST docs/lgpsi_pron.pdf
    echo "Combined PDFs into docs/lgpsi_pron.pdf (bookmarks not preserved)"
fi

echo "Done. Final PDF is at docs/lgpsi_pron.pdf"

# Clean up temporary files if not in debug mode
if [ "$DEBUG_MODE" = false ]; then
    echo "Cleaning up temporary files..."
    # Remove individual chapter PDFs and TEX files
    rm -f "${OUTPUT_DIR}"/*.pdf "${OUTPUT_DIR}"/*.tex "${OUTPUT_DIR}"/*.aux "${OUTPUT_DIR}"/*.log "${OUTPUT_DIR}"/*.out
    # Remove the temporary directory if it's empty
    rmdir --ignore-fail-on-non-empty "$OUTPUT_DIR"
    echo "Temporary files cleaned up"
else
    echo "Debug mode: Temporary files preserved in $OUTPUT_DIR"
fi
