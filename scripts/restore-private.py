#!/usr/bin/env python3
"""Restore explicit private files without logging their contents."""
from datetime import datetime, timezone
import os
from pathlib import Path
import shutil
import sys
import tempfile


def restore(source, target):
    source, target = Path(source).resolve(), Path(target).resolve()
    repository = Path(__file__).resolve().parent.parent
    if source == repository or repository in source.parents:
        raise SystemExit("Keep the private backup outside this repository.")
    if target == repository or repository in target.parents:
        raise SystemExit("Private files cannot be restored into this repository.")
    destinations = {
        ".zshrc.local": target / ".zshrc.local",
        ".gitconfig.local": target / ".gitconfig.local",
        ".gitignore.local": target / ".gitignore.local",
        "raycast.rayconfig": target / ".local/state/dotfiles/private/raycast.rayconfig",
    }
    files = [(source / name, path) for name, path in destinations.items() if (source / name).exists() or (source / name).is_symlink()]
    if not files:
        raise SystemExit("No supported private backup files found.")
    # Validate everything before making changes. Never follow a backup's symlinks.
    for original, destination in files:
        resolved_parent = destination.parent.resolve()
        if resolved_parent == repository or repository in resolved_parent.parents:
            raise SystemExit("A private destination directory points into this repository.")
        if not original.is_file() or original.is_symlink():
            raise SystemExit(f"Private backup must be a regular file: {original.name}")
        if destination.exists() and destination.is_dir():
            raise SystemExit(f"Destination is a directory: {destination}")
        if destination.resolve() == original:
            raise SystemExit("The backup and destination must be different files.")
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S%f")
    for original, destination in files:
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.name == "raycast.rayconfig":
            destination.parent.chmod(0o700)
        if destination.is_file() and not destination.is_symlink() and destination.read_bytes() == original.read_bytes():
            destination.chmod(0o600)
            continue
        if destination.exists() or destination.is_symlink():
            backup = destination.with_name(f"{destination.name}.backup.{stamp}")
            if backup.exists() or backup.is_symlink():
                raise SystemExit(f"Backup already exists: {backup}")
            destination.rename(backup)
            if not backup.is_symlink():
                backup.chmod(0o600)
        fd, temporary = tempfile.mkstemp(prefix=".restore-", dir=destination.parent)
        try:
            with os.fdopen(fd, "wb") as output, original.open("rb") as input_file:
                shutil.copyfileobj(input_file, output)
            os.replace(temporary, destination)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
        print(f"Restored {destination}")


if __name__ == "__main__":
    restore(*sys.argv[1:])
