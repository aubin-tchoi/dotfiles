#!/bin/bash
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
target_dir="${1:-$target_dir}"

# Validate the entire manifest before replacing any existing configuration.
links="$(config_links)"
while IFS=$'\t' read -r source target; do
  [[ -f "$source" ]] || fail "Missing configuration: $source"
done <<< "$links"

while IFS=$'\t' read -r source target; do
  [[ -L "$target" && "$target" -ef "$source" ]] && continue
  mkdir -p "$(dirname "$target")"
  if [[ -e "$target" || -L "$target" ]]; then
    backup="$target.backup.$(date +%Y%m%d%H%M%S).$$"
    [[ ! -e "$backup" && ! -L "$backup" ]] || fail "Backup already exists: $backup"
    mv "$target" "$backup"
    printf 'Backed up %s to %s\n' "$target" "$backup"
  fi
  ln -s "$source" "$target"
  printf 'Linked %s\n' "$target"
done <<< "$links"
