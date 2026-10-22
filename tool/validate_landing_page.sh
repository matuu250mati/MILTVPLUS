#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from html.parser import HTMLParser
from pathlib import Path
import re
import sys

path = Path("docs/index.html")
html = path.read_text(encoding="utf-8")

class LandingPageParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.ids = []
        self.fragments = []
        self.selectors = set()
        self.translation_keys = set()
        self.script_count = 0

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        value = attrs.get("id")
        if value:
            self.ids.append(value)
        href = attrs.get("href", "")
        if href.startswith("#") and len(href) > 1:
            self.fragments.append(href[1:])
        if attrs.get("data-i18n"):
            self.translation_keys.add(attrs["data-i18n"])
        if tag == "select" and attrs.get("id") == "language-select":
            self.selectors.add("language-select")
        if tag == "script":
            self.script_count += 1

parser = LandingPageParser()
parser.feed(html)
parser.close()

duplicates = sorted({value for value in parser.ids if parser.ids.count(value) > 1})
missing = sorted(set(parser.fragments) - set(parser.ids))
if duplicates:
    print("Duplicate HTML IDs: " + ", ".join(duplicates), file=sys.stderr)
    sys.exit(1)
if missing:
    print("Broken in-page links: " + ", ".join(missing), file=sys.stderr)
    sys.exit(1)
if "language-select" not in parser.selectors:
    print("Missing international language selector", file=sys.stderr)
    sys.exit(1)
translations_start = html.find("const translations={")
translations_end = html.find("const fullTextTranslations=", translations_start)
if translations_start < 0 or translations_end < 0:
    print("Could not isolate primary locale dictionaries", file=sys.stderr)
    sys.exit(1)
translations_block = html[translations_start:translations_end]
for locale in ("es-AR", "en-US", "es-ES", "pt-BR"):
    line = next((line for line in translations_block.splitlines() if line.lstrip().startswith(f"'{locale}':{{")), "")
    if not line:
        print(f"Missing primary locale dictionary: {locale}", file=sys.stderr)
        sys.exit(1)
    translated_keys = set(re.findall(r"(?:^|,)([A-Za-z][A-Za-z0-9]*):'", line))
    missing_keys = sorted(parser.translation_keys - translated_keys)
    if missing_keys:
        print(f"Locale {locale} is missing data-i18n keys: {', '.join(missing_keys)}", file=sys.stderr)
        sys.exit(1)
for required_locale in ("'en-US':{", "'es-ES':{", "'pt-BR':{"):
    if required_locale not in html:
        print(f"Missing full-content translation dictionary: {required_locale}", file=sys.stderr)
        sys.exit(1)
for required_phrase in ("fullTextTranslations", "Frequently asked questions", "Perguntas frequentes", "Central de Opiniões"):
    if required_phrase not in html:
        print(f"Missing expected localized content: {required_phrase}", file=sys.stderr)
        sys.exit(1)
if parser.script_count != 1:
    print(f"Expected one inline script, found {parser.script_count}", file=sys.stderr)
    sys.exit(1)
if "1857055" not in html:
    print("Downloader code is missing", file=sys.stderr)
    sys.exit(1)
if "releases/latest/download/MILTVPLUS.apk" not in html:
    print("Missing stable link to the published MILTVPLUS APK asset", file=sys.stderr)
    sys.exit(1)
if "releases/latest/download/MILTVPLUS.apk.sha256" not in html:
    print("Missing SHA-256 checksum link for the published APK", file=sys.stderr)
    sys.exit(1)
scripts = re.findall(r"<script(?:\s[^>]*)?>(.*?)</script>", html, re.I | re.S)
if len(scripts) != 1:
    print("Could not isolate the landing-page JavaScript", file=sys.stderr)
    sys.exit(1)
Path("/tmp/miltvplus-landing-inline.js").write_text(scripts[0], encoding="utf-8")
print(f"Landing-page checks passed: {len(parser.ids)} IDs, {len(parser.fragments)} internal links, language selector and Downloader code present.")
PY

node --check /tmp/miltvplus-landing-inline.js
