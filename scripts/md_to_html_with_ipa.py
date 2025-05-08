#!/usr/bin/env python3
import subprocess, glob, os
import unicodedata
import re
import json
from html.parser import HTMLParser
import sys
import argparse

scheme_map = {
            'cla': "cla.cla.IPA",# "5th BCE Attic",
            'koi1': "koi1.koi1.IPA",# "1st CE Egyptian",
            'koi2': "koi2.koi2.IPA",# "4th CE Koine",
            'byz1': "byz1.byz1.IPA",# "10th CE Byzantine",
            'byz2': "byz2.byz2.IPA",# "15th CE Constantinopolitan",
}

# CLI flags
parser = argparse.ArgumentParser(description='Inject Greek pronunciation')
parser.add_argument('--interlinear', action='store_true', help='Use interlinear layout under each word')
# Add to existing argparse setup
parser.add_argument('--scheme', 
                    choices=scheme_map.keys(),
                    default='cla',
                    help='Pronunciation scheme: cla (Classical), koi1 (Early Koine), koi2 (Late Koine), byz1 (Middle Byzantine), byz2 (Late Byzantine)')
args, _ = parser.parse_known_args()
INTER_MODE = args.interlinear
SCHEME = scheme_map[args.scheme]

def normalize(text):
    return unicodedata.normalize('NFC', text)

# Add pattern for Greek words
greek_word_re = re.compile(r"[\u0370-\u03FF\u1F00-\u1FFF\u0300-\u036F]+(?:['ʼ᾽᾿-][\u0370-\u03FF\u1F00-\u1FFF\u0300-\u036F]+)*")

def extract_greek_words(text):
    """Extract complete Greek words including diacritics and apostrophes"""
    words = set(greek_word_re.findall(text))
    return sorted(words, key=lambda w: (-len(w), w.casefold()))

# Persistent pronunciation cache
CACHE_FILE = 'scripts/pron_cache.json'

def load_cache():
    if os.path.exists(CACHE_FILE):
        with open(CACHE_FILE, 'r', encoding='utf8') as f:
            try:
                return json.load(f)
            except json.JSONDecodeError:
                return {}
    return {}

def save_cache(cache):
    with open(CACHE_FILE, 'w', encoding='utf8') as f:
        json.dump(cache, f, ensure_ascii=False)

# Initialize cache
pron_cache = load_cache()




def get_pronunciation(w, scheme="cla"):
    key = str((w,scheme))
    if key in pron_cache:
        return pron_cache[key]
    if not any(c.isalpha() for c in w):
        return ''
    try:
        proc = subprocess.run(
            ['lua', 'scripts/lua/grc-pron_wasm_local.lua',scheme],
            input=w.encode('utf-8'),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
            timeout=5
        )
        pron = proc.stdout.decode('utf8').split('=========')[-1].strip()
        pron_cache[key] = pron
        save_cache(pron_cache)
    except subprocess.TimeoutExpired:
        print(f"Timeout processing word: {w}")
        pron = "[Timeout]"
    except subprocess.CalledProcessError as e:
        print(f"Error processing word '{w}': {e.stderr.decode('utf8').strip()}")
        pron = "[Error]"
    return pron

class RubyInjector(HTMLParser):
    def __init__(self):
        super().__init__()
        self.output = []
        self.tag_stack = []  # Use a stack to track current tag

    def handle_starttag(self, tag, attrs):
        self.tag_stack.append(tag)
        attrs_str = ''.join(f' {k}="{v}"' for k, v in attrs)
        self.output.append(f'<{tag}{attrs_str}>')

    def handle_endtag(self, tag):
        if self.tag_stack and self.tag_stack[-1] == tag:
            self.tag_stack.pop()
        self.output.append(f'</{tag}>')

    def handle_startendtag(self, tag, attrs):
        attrs_str = ''.join(f' {k}="{v}"' for k, v in attrs)
        self.output.append(f'<{tag}{attrs_str}/>')

    def handle_data(self, data):
        current_tag = self.tag_stack[-1] if self.tag_stack else ''
        if current_tag.lower() in ['script', 'style']:
            self.output.append(data)
            return
        if any('GREEK' in unicodedata.name(c, '') for c in data if c.strip()):
            new_parts = []
            last = 0
            for m in greek_word_re.finditer(data):
                w = m.group(0)
                base = re.sub(r'[!?.,;:]', '', w)
                pron = get_pronunciation(base, SCHEME)
                new_parts.append(data[last:m.start()])
                if INTER_MODE:
                    # Only headings h1-h6 get not_in_toc, everything else gets interlinear
                    if current_tag.lower() in ['h1', 'h2', 'h3', 'h4', 'h5', 'h6']:
                        new_parts.append(f'<span class="il_word">{w}<span class="il_translation not_in_toc"></span></span>')
                    else:
                        new_parts.append(f'<span class="il_word">{w}<span class="il_translation">{pron}</span></span>')
                else:
                    # inline ruby annotation
                    new_parts.append(
                        f'<ruby style="ruby-position:under;-webkit-ruby-position:after">'
                        f'{w}'
                        f'<rt>{pron}</rt>'
                        f'</ruby>'
                    )
                last = m.end()
            new_parts.append(data[last:])
            data = ''.join(new_parts)
        self.output.append(data)

    def handle_entityref(self, name):
        self.output.append(f'&{name};')

    def handle_charref(self, name):
        self.output.append(f'&#{name};')

# Allow processing HTML from stdin for pipelines
if not sys.stdin.isatty():
    html = sys.stdin.read()
    # Strip existing ruby/rt tags
    html = re.sub(r'</?ruby[^>]*>', '', html)
    html = re.sub(r'<rt>.*?</rt>', '', html)
    html = normalize(html)
    # Inject annotations and interlinear spans
    parser = RubyInjector()
    parser.feed(html)
    try:
        sys.stdout.write(''.join(parser.output))
    except BrokenPipeError:
        # downstream closed pipe (e.g., pandoc), exit silently
        pass
    sys.exit(0)

# Ensure output dir exists
os.makedirs('docs', exist_ok=True)
# Process each markdown file
for md in glob.glob('src/*.md'):
    base = os.path.splitext(os.path.basename(md))[0]
    out = f'docs/{base}.html'
    print(f"Building {out} from {md}")
    # Render initial HTML
    subprocess.check_call([
        'pandoc', '-s', '--template=templates/default_pron.html', '-o', out,
        'src/title.txt', md
    ])
    # Read HTML
    with open(out, 'r', encoding='utf8') as f:
        html = f.read()
    # Strip existing ruby/rt tags
    
    html = re.sub(r'</?ruby[^>]*>', '', html)
    html = re.sub(r'<rt>.*?</rt>', '', html)
    html = re.sub(r'<rb>.*?</rb>', '', html)
    html = normalize(html)

    # Always perform inline ruby injection when writing HTML files
    parser = RubyInjector()
    parser.feed(html)
    html = ''.join(parser.output)

    # Write back
    with open(out, 'w', encoding='utf8') as f:
        f.write(html)
    print(f"Written {out}")
