#!/usr/bin/env bash
# List Koha Weblate languages with translated_percent above a threshold (default 66).
# API: https://translate.koha-community.org/api/projects/koha/languages/

set -euo pipefail

THRESHOLD="${1:-66}"
BASE_URL="https://translate.koha-community.org/api/projects/koha/languages/"

python3 - "$THRESHOLD" "$BASE_URL" <<'PY'
import json
import sys
import urllib.request

threshold = float(sys.argv[1])
url = sys.argv[2]
rows = []

while url:
    with urllib.request.urlopen(url) as resp:
        data = json.load(resp)
    if isinstance(data, list):
        rows.extend(data)
        break
    rows.extend(data.get("results", []))
    url = data.get("next")

for lang in sorted(rows, key=lambda x: x.get("code", "")):
    pct = lang.get("translated_percent", 0) or 0
    if pct > threshold:
        code = lang.get("code", "")
        name = lang.get("name", "")
        print(f"{code}\t{pct:.1f}%\t{name}")
PY
