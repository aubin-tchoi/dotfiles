#!/usr/bin/env python3
"""Apply or restore only the explicitly saved macOS preference keys."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shlex
import subprocess

ROOT = Path(__file__).resolve().parent.parent
SAVED = json.loads((ROOT / "config/macos/defaults.json").read_text())
FLAGS = {"boolean": "-bool", "integer": "-int", "float": "-float", "string": "-string"}


def defaults(*args, check=True):
    return subprocess.run(["defaults", *args], text=True, capture_output=True, check=check)


def read(domain, key):
    result = defaults("read", domain, key, check=False)
    if result.returncode:
        # A missing key is restored by deleting that individual override.
        if "does not exist" in result.stderr:
            return {"present": False}
        raise RuntimeError(f"Cannot read preference {domain} {key}: {result.stderr.strip()}")
    kind = defaults("read-type", domain, key).stdout.strip().split()[-1]
    raw = result.stdout.rstrip("\n")
    if kind == "boolean":
        value = raw in ("1", "true", "YES")
    elif kind == "integer":
        value = int(raw)
    elif kind == "float":
        value = float(raw)
    elif kind == "string":
        value = raw
    else:
        raise RuntimeError(f"Unsupported existing preference type: {domain} {key} ({kind})")
    return {"present": True, "type": kind, "value": value}


def write(entry):
    domain, key = entry["domain"], entry["key"]
    if not entry["present"]:
        if read(domain, key)["present"]:
            defaults("delete", domain, key)
        return
    value = entry["value"]
    if entry["type"] == "boolean":
        value = "true" if value else "false"
    defaults("write", domain, key, FLAGS[entry["type"]], str(value))


def apply():
    changes, previous = [], []
    for preference in SAVED:
        original = read(preference["domain"], preference["key"])
        desired = {"present": True, "type": preference["type"], "value": preference["value"]}
        if original != desired:
            previous.append({"domain": preference["domain"], "key": preference["key"], **original})
            changes.append({**preference, "present": True})
    if not changes:
        print("macOS preferences already match.")
        return
    directory = Path(os.environ.get("DOTFILES_TARGET_DIR", Path.home())) / ".local/state/dotfiles/macos"
    directory.mkdir(parents=True, exist_ok=True)
    directory.chmod(0o700)
    backup = directory / (datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ") + ".json")
    descriptor = os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w") as output:
        json.dump(previous, output, indent=2)
        output.write("\n")
    print(f"Restore with: python3 scripts/macos-defaults.py restore {shlex.quote(str(backup))}", flush=True)
    for entry in changes:
        write(entry)
    print("macOS preferences applied. Log out and back in to load all changes.")


def restore(backup):
    entries = json.loads(Path(backup).read_text())
    allowed = {(entry["domain"], entry["key"]) for entry in SAVED}
    seen = set()
    for entry in entries:
        pair = (entry["domain"], entry["key"])
        if pair not in allowed or pair in seen or type(entry["present"]) is not bool:
            raise ValueError("Backup contains an unsupported or duplicate preference.")
        seen.add(pair)
        if entry["present"]:
            kind, value = entry["type"], entry["value"]
            valid = {"boolean": type(value) is bool, "integer": type(value) is int,
                     "float": type(value) in (int, float), "string": type(value) is str}
            if not valid.get(kind, False):
                raise ValueError("Invalid preference type or value in backup.")
    for entry in entries:
        write(entry)
    print("macOS preferences restored. Log out and back in to load all changes.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("apply")
    commands.add_parser("restore").add_argument("backup")
    args = parser.parse_args()
    if subprocess.check_output(["uname", "-s"], text=True).strip() != "Darwin":
        parser.error("macOS preferences require macOS")
    if args.command == "apply":
        apply()
    else:
        restore(args.backup)
