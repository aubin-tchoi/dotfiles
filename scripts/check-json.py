#!/usr/bin/env python3
"""Validate the saved JSONC without changing strings containing comment markers."""
import json
from pathlib import Path
import re


def parse_jsonc(text):
    tokens = r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*[\s\S]*?\*/'
    text = re.sub(tokens, lambda m: m[0] if m[0].startswith('"') else ' ', text)
    text = re.sub(r'"(?:\\.|[^"\\])*"|,\s*(?=[}\]])',
                  lambda m: m[0] if m[0].startswith('"') else '', text)
    return json.loads(text)


if __name__ == "__main__":
    root = Path(__file__).resolve().parent.parent
    for file in (root / "config/zed").glob("*.json"):
        parse_jsonc(file.read_text())
    json.loads((root / "config/raycast/extensions.json").read_text())
