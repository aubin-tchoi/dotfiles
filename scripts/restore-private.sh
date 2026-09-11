#!/bin/bash
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
[[ $# -eq 1 ]] || fail "Usage: bash scripts/restore-private.sh PRIVATE_DIRECTORY"
exec python3 "$dotfiles_dir/scripts/restore-private.py" "$1" "$target_dir"
