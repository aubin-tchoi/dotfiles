#!/bin/bash
# Sourced by install.sh; context variables come from that entry point.
# shellcheck disable=SC2154

ubuntu_packages() {
  cat "$dotfiles_dir/packages/ubuntu.txt"
  if [[ "$profile" == full ]]; then
    cat "$dotfiles_dir/packages/ubuntu-full.txt"
  fi
}

install_ubuntu_packages() {
  local release_file="${DOTFILES_OS_RELEASE_FILE:-/etc/os-release}"
  [[ -f "$release_file" ]] || fail "Cannot identify this Linux distribution."
  # shellcheck disable=SC1090
  source "$release_file"
  [[ "${ID:-}" == ubuntu || "${ID_LIKE:-}" == *ubuntu* ]] || fail "The Linux installer supports Ubuntu and its derivatives."

  local package status
  local missing=()
  while IFS= read -r package; do
    [[ -z "$package" || "$package" == \#* ]] && continue
    status="$(dpkg-query -W -f='${Status}' "$package" 2>/dev/null || true)"
    [[ "$status" == 'install ok installed' ]] || missing+=("$package")
  done < <(ubuntu_packages)
  if [[ ${#missing[@]} -gt 0 ]]; then
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends "${missing[@]}"
  fi
  # Ubuntu calls the executable batcat. Keep the compatibility link in user space.
  if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    mkdir -p "$target_dir/.local/bin"
    ln -s "$(command -v batcat)" "$target_dir/.local/bin/bat"
  fi
}
