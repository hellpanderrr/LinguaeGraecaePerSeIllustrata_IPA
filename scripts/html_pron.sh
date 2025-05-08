#!/usr/bin/env bash
#set -euo pipefail

# Usage: ./scripts/html_pron.sh [--scheme SCHEME]
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
      echo "Usage: ./scripts/html_pron.sh [--scheme SCHEME]"
      exit 1
      ;;
  esac
done

# Ensure docs directory
mkdir -p docs

# Run the Python script with the selected scheme
python3 scripts/md_to_html_with_ipa.py --scheme "$SCHEME"
