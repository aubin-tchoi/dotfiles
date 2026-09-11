#!/bin/bash

dotfiles_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# An isolated target is used by the tests; HOME is never changed.
target_dir="${DOTFILES_TARGET_DIR:-$HOME}"
platform="$(uname -s)"

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

find_brew() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return
  fi
  local candidate
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  return 1
}

download_and_run() (
  local url="$1" installer
  shift
  installer="$(mktemp)"
  trap 'rm -f "$installer"' EXIT
  curl --fail --silent --show-error --location --retry 3 --connect-timeout 15 --max-time 300 "$url" -o "$installer"
  bash "$installer" "$@"
)

config_links() {
  local name
  while IFS= read -r name; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    printf '%s\t%s\n' "$dotfiles_dir/$name" "$target_dir/.$name"
  done < "$dotfiles_dir/scripts/config-files.txt"
  if [[ "$platform" == Darwin ]]; then
    printf '%s\t%s\n' "$dotfiles_dir/config/ghostty/config" "$target_dir/Library/Application Support/com.mitchellh.ghostty/config"
  elif [[ "$platform" == Linux ]]; then
    printf '%s\t%s\n' "$dotfiles_dir/config/terminator/config" "$target_dir/.config/terminator/config"
  fi
}

clone_once() {
  local url="$1" destination="$2" expected="$3"
  shift 3
  [[ -f "$destination/$expected" ]] && return
  [[ ! -e "$destination" && ! -L "$destination" ]] || fail "Incomplete installation at $destination; move it aside and rerun."
  mkdir -p "$(dirname "$destination")"
  # Clone beside the destination so an interrupted download can be retried.
  local temporary
  temporary="$(mktemp -d "$destination.install.XXXXXX")"
  if git clone --depth=1 "$@" "$url" "$temporary"; then
    [[ -f "$temporary/$expected" ]] || fail "The download is missing $expected: $temporary"
    mv "$temporary" "$destination"
  else
    rm -rf "$temporary"
    fail "Could not install $destination; rerun to retry."
  fi
}
