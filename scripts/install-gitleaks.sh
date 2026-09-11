#!/bin/bash
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
export PATH="$target_dir/.local/bin:$PATH"
command -v gitleaks >/dev/null 2>&1 && exit 0

version=8.30.1
case "$platform" in Darwin) os=darwin ;; Linux) os=linux ;; *) fail "Unsupported scanner platform." ;; esac
case "$(uname -m)" in arm64|aarch64) arch=arm64 ;; x86_64|amd64) arch=x64 ;; *) fail "Unsupported scanner architecture." ;; esac
archive="gitleaks_${version}_${os}_${arch}.tar.gz"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
base="https://github.com/gitleaks/gitleaks/releases/download/v$version"
for file in "$archive" "gitleaks_${version}_checksums.txt"; do
  curl --fail --silent --show-error --location --retry 3 --connect-timeout 15 --max-time 300 "$base/$file" -o "$temporary/$file"
done
# Verify the release checksum, and extract only the executable.
python3 - "$temporary" "$archive" "$version" <<'PY'
import hashlib
from pathlib import Path
import sys
import tarfile

directory, archive, version = sys.argv[1:]
directory = Path(directory)
checksums = dict(line.split()[::-1] for line in (directory / f"gitleaks_{version}_checksums.txt").read_text().splitlines() if line.strip())
payload = directory / archive
if hashlib.sha256(payload.read_bytes()).hexdigest() != checksums[archive]:
    raise SystemExit("Gitleaks checksum verification failed")
with tarfile.open(payload) as bundle:
    member = bundle.getmember("gitleaks")
    if not member.isfile():
        raise SystemExit("Invalid Gitleaks executable")
    (directory / "gitleaks").write_bytes(bundle.extractfile(member).read())
PY
mkdir -p "$target_dir/.local/bin"
install -m 755 "$temporary/gitleaks" "$target_dir/.local/bin/gitleaks"
