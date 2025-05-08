#!/usr/bin/env python3
import re
import os
import glob
import argparse
import shutil
import subprocess
import json
import unicodedata

# Define scheme mapping
scheme_map = {
    'cla': "cla.cla.IPA",  # "5th BCE Attic",
    'koi1': "koi1.koi1.IPA",  # "1st CE Egyptian",
    'koi2': "koi2.koi2.IPA",  # "4th CE Koine",
    'byz1': "byz1.byz1.IPA",  # "10th CE Byzantine",
    'byz2': "byz2.byz2.IPA",  # "15th CE Constantinopolitan",
}

# Persistent pronunciation cache
CACHE_FILE = 'scripts/pron_cache.json'
SCHEME = "cla.cla.IPA"  # Default to Classical Greek pronunciation scheme

def load_cache():
    """Load the pronunciation cache from disk."""
    if os.path.exists(CACHE_FILE):
        with open(CACHE_FILE, 'r', encoding='utf8') as f:
            try:
                return json.load(f)
            except json.JSONDecodeError:
                return {}
    return {}

def save_cache(cache):
    """Save the pronunciation cache to disk."""
    with open(CACHE_FILE, 'w', encoding='utf8') as f:
        json.dump(cache, f, ensure_ascii=False)

# Initialize cache
pron_cache = load_cache()

def get_transcription(greek_word):
    """
    Get transcription for a Greek word using the Lua script.

    This function calls the Lua script to get accurate IPA transcriptions.
    It also caches results to avoid repeated calls for the same word.
    """
    # Clean the word (remove punctuation)
    base = re.sub(r'[!?.,;:]', '', greek_word)

    # Check if we have this word in the cache
    key = str((base, SCHEME))
    if key in pron_cache:
        return pron_cache[key]

    # Skip words without any alphabetic characters
    if not any(c.isalpha() for c in base):
        return ''

    # Special handling for words with diaeresis (ϊ, ϋ)
    # Make sure they're treated as a single word
    if 'ϊ' in base or 'ϋ' in base:
        print(f"Processing word with diaeresis: {base}")

    try:
        # Call the Lua script to get the pronunciation
        proc = subprocess.run(
            ['lua', 'scripts/lua/grc-pron_wasm_local.lua', SCHEME],
            input=base.encode('utf-8'),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
            timeout=5
        )
        # Extract the pronunciation from the output
        pron = proc.stdout.decode('utf8').split('=========')[-1].strip()

        # Cache the result
        pron_cache[key] = pron
        save_cache(pron_cache)

        return pron
    except subprocess.TimeoutExpired:
        print(f"Timeout processing word: {base}")
        return "[Timeout]"
    except subprocess.CalledProcessError as e:
        print(f"Error processing word '{base}': {e.stderr.decode('utf8').strip()}")
        # Fall back to a simple transcription if the Lua script fails
        return base

def process_file(input_file, output_file):
    """
    Process a Markdown file to add transcription under Greek words.
    """
    # Read the input file
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Improved pattern for Greek words that handles diaeresis correctly
    # This pattern matches complete Greek words including those with diaeresis
    greek_pattern = r'[Α-Ωα-ωἀ-ᾼ῀-῾]+(?:ϊ|ϋ)?[Α-Ωα-ωἀ-ᾼ῀-῾]*'

    # First, find all Greek words in the content
    greek_words = re.finditer(greek_pattern, content)

    # Sort matches by position in reverse order (to avoid offset issues when replacing)
    matches = sorted(greek_words, key=lambda m: m.start(), reverse=True)

    processed_content = content

    # Replace each Greek word with the LaTeX command
    for match in matches:
        start, end = match.span()
        greek_word = match.group(0)

        # Check if this is a complete word (not part of a larger word)
        # This helps with words like "Ῥωμαϊκή" that might be split incorrectly
        is_complete_word = True
        if start > 0 and processed_content[start-1].isalpha():
            is_complete_word = False
        if end < len(processed_content) and processed_content[end].isalpha():
            is_complete_word = False

        if is_complete_word:
            # Get the transcription for this Greek word
            transcription = get_transcription(greek_word)

            # Replace the word with the LaTeX command
            replacement = f"\\greekpron[{transcription}]{{{greek_word}}}"
            processed_content = processed_content[:start] + replacement + processed_content[end:]

    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(processed_content)

def main():
    """
    Main function.
    """
    parser = argparse.ArgumentParser(description='Add transcription under Greek words in Markdown files.')
    parser.add_argument('--input-dir', '-i', default='src', help='Input directory containing Markdown files')
    parser.add_argument('--output-dir', '-o', default='processed_src', help='Output directory for processed files')
    parser.add_argument('--scheme',
                    choices=scheme_map.keys(),
                    default='cla',
                    help='Pronunciation scheme: cla (Classical), koi1 (Early Koine), koi2 (Late Koine), byz1 (Middle Byzantine), byz2 (Late Byzantine)')

    args = parser.parse_args()

    # Set the global SCHEME variable based on the command-line argument
    global SCHEME
    SCHEME = scheme_map[args.scheme]
    print(f"Using pronunciation scheme: {args.scheme} ({SCHEME})")

    os.makedirs(args.output_dir, exist_ok=True)

    # Process each Markdown file in the input directory
    for md_file in glob.glob(os.path.join(args.input_dir, '*.md')):
        base_name = os.path.basename(md_file)

        output_file = os.path.join(args.output_dir, base_name)

        print(f"Processing {md_file}...")
        process_file(md_file, output_file)

    # Copy the title file if it exists
    title_file = os.path.join(args.input_dir, 'title.txt')
    if os.path.exists(title_file):
        shutil.copy(title_file, os.path.join(args.output_dir, 'title.txt'))

    print(f"Done. Processed files are in {args.output_dir}")

if __name__ == "__main__":
    main()
