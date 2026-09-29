"""Checks every locale against en.json: same keys, same {placeholders}.

Usage: python3 scripts/validate_locales.py
"""
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent.parent / "content" / "locales"
PLACEHOLDER = re.compile(r"\{(\w+)\}")

source = json.loads((HERE / "en.json").read_text())
failed = False

for path in sorted(HERE.glob("*.json")):
    if path.name == "en.json":
        continue
    data = json.loads(path.read_text())
    missing = [k for k in source if k not in data]
    extra = [k for k in data if k not in source]
    bad = [
        k for k in source
        if k in data and set(PLACEHOLDER.findall(source[k])) != set(PLACEHOLDER.findall(data[k]))
    ]
    status = "ok" if not (missing or extra or bad) else "FAIL"
    failed |= status == "FAIL"
    print(f"{path.name:14} {len(data):4} keys  {status}"
          + (f"  missing={missing[:5]}" if missing else "")
          + (f"  extra={extra[:5]}" if extra else "")
          + (f"  placeholders={bad[:5]}" if bad else ""))

sys.exit(1 if failed else 0)
