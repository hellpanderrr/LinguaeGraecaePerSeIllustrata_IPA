#!/bin/bash
# Simple script to process a single chapter

# Check if a chapter number was provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <chapter_number> [scheme]"
    echo "Example: $0 001 cla"
    exit 1
fi

# Get the chapter number
CHAPTER_NUM=$1

# Get the scheme if provided, otherwise use default
SCHEME=${2:-cla}

# Define input and output files
MD_FILE="docs/processed_src/${CHAPTER_NUM}.md"
OUTPUT_DIR="docs/simple_chapters"
TEX_FILE="${OUTPUT_DIR}/${CHAPTER_NUM}.tex"
PDF_FILE="${OUTPUT_DIR}/${CHAPTER_NUM}.pdf"

# Ensure the output directory exists
mkdir -p "$OUTPUT_DIR"

# Check if the Markdown file exists
if [ ! -f "$MD_FILE" ]; then
    echo "Error: Markdown file $MD_FILE not found"
    exit 1
fi

# Extract the title from the first line (assuming it's a # heading)
ORIGINAL_TITLE=$(head -n 1 "$MD_FILE" | sed 's/^# //')

# Replace \greekpron with \headerpron for tighter spacing in headers
FULL_TITLE=$(echo "$ORIGINAL_TITLE" | sed -E 's/\\greekpron/\\headerpron/g')

# Extract only the Greek text for bookmarks (remove \greekpron commands)
BOOKMARK_TITLE=$(echo "$ORIGINAL_TITLE" | sed -E 's/\\greekpron\[[^]]*\]\{([^}]*)\}/\1/g')
echo "Processing chapter $CHAPTER_NUM: $FULL_TITLE"

# Create a simple LaTeX file
cat > "$TEX_FILE" << EOF
\\documentclass{article}
\\usepackage{fontspec}
\\usepackage{polyglossia}
\\usepackage{array}
\\usepackage{hyperref}
\\usepackage{bookmark}
\\usepackage[margin=1.5in]{geometry}

% Configure hyperref
\\hypersetup{
  colorlinks=true,
  linkcolor=blue,
  filecolor=magenta,
  urlcolor=cyan,
  pdftitle={LGPSI},
  pdfauthor={LGPSI},
  bookmarksnumbered=true,
  bookmarksopen=true
}

% Set up languages
\\setmainlanguage{english}
\\setotherlanguage{greek}

% Set up fonts that support Greek and IPA
\\newfontfamily\\greekfont{SBLGreek.ttf}[
  Path = ../../docs/
]
\\setmainfont{SBLGreek.ttf}[
  Path = ../../docs/
]

% Include Noto Sans TTF with the correct path
\\setsansfont{NotoSans-Regular.ttf}[
  Path = ../../docs/
]

% Define pronunciation command for regular text
\\newcommand{\\greekpron}[2][]{%
  \\begin{tabular}[t]{@{}c@{}}
    \\textgreek{#2} \\\\[-3pt]
    {\\sffamily\\tiny #1}
  \\end{tabular}%
}

% Define pronunciation command for section headers (with tighter spacing)
\\newcommand{\\headerpron}[2][]{%
  \\begin{tabular}[t]{@{}c@{}}
    \\textgreek{#2} \\\\[-9pt]
    {\\sffamily\\tiny #1}
  \\end{tabular}%
}

\\begin{document}

% Set justified text alignment and remove paragraph indentation
\\setlength{\\parindent}{0pt}  % Remove paragraph indentation
\\setlength{\\parskip}{6pt}    % Add space between paragraphs

\\section[${BOOKMARK_TITLE}]{$FULL_TITLE}

EOF

# Add the content (skip the first line which is the title)
tail -n +2 "$MD_FILE" | while IFS= read -r line; do
    # Process headings
    if [[ "$line" =~ ^##[^#] ]]; then
        # Level 2 heading (##)
        original_section=$(echo "$line" | sed 's/^## //')
        # Replace \greekpron with \headerpron for tighter spacing in headers
        full_section=$(echo "$original_section" | sed -E 's/\\greekpron/\\headerpron/g')
        # Extract only the Greek text for bookmarks (remove \greekpron commands)
        bookmark_section=$(echo "$original_section" | sed -E 's/\\greekpron\[[^]]*\]\{([^}]*)\}/\1/g')
        echo -e "\\subsection[$bookmark_section]{$full_section}\n" >> "$TEX_FILE"
    elif [[ "$line" =~ ^###[^#] ]]; then
        # Level 3 heading (###)
        original_subsection=$(echo "$line" | sed 's/^### //')
        # Replace \greekpron with \headerpron for tighter spacing in headers
        full_subsection=$(echo "$original_subsection" | sed -E 's/\\greekpron/\\headerpron/g')
        # Extract only the Greek text for bookmarks (remove \greekpron commands)
        bookmark_subsection=$(echo "$original_subsection" | sed -E 's/\\greekpron\[[^]]*\]\{([^}]*)\}/\1/g')
        echo -e "\\subsubsection[$bookmark_subsection]{$full_subsection}\n" >> "$TEX_FILE"
    elif [[ "$line" =~ ^####[^#] ]]; then
        # Level 4 heading (####)
        original_subsubsection=$(echo "$line" | sed 's/^#### //')
        # Replace \greekpron with \headerpron for tighter spacing in headers
        full_subsubsection=$(echo "$original_subsubsection" | sed -E 's/\\greekpron/\\headerpron/g')
        # Extract only the Greek text for bookmarks (remove \greekpron commands)
        bookmark_subsubsection=$(echo "$original_subsubsection" | sed -E 's/\\greekpron\[[^]]*\]\{([^}]*)\}/\1/g')
        echo -e "\\paragraph[$bookmark_subsubsection]{$full_subsubsection}\n" >> "$TEX_FILE"
    elif [[ "$line" =~ ^#[^#] ]]; then
        # Single # at the beginning of a line (not a heading, but a comment)
        # Convert to LaTeX comment
        comment=$(echo "$line" | sed 's/^# //')
        echo -e "% $comment" >> "$TEX_FILE"
    else
        # Regular line
        echo "$line" >> "$TEX_FILE"
    fi
done

# Close the document
echo "" >> "$TEX_FILE"
echo "\\end{document}" >> "$TEX_FILE"

# Compile to PDF
echo "Compiling $TEX_FILE to PDF..."
cd "$OUTPUT_DIR"
xelatex -interaction=nonstopmode "$(basename "$TEX_FILE")"
xelatex -interaction=nonstopmode "$(basename "$TEX_FILE")"  # Second run for bookmarks
cd ../..

# Check if PDF was generated
if [ -f "$PDF_FILE" ]; then
    echo "Generated $PDF_FILE"
else
    echo "ERROR: Failed to generate $PDF_FILE"
fi
