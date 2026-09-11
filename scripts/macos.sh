#!/bin/bash
# Sourced by install.sh; context variables come from that entry point.
# shellcheck disable=SC2154

install_macos_packages() {
  if ! xcode-select -p >/dev/null 2>&1; then
    xcode-select --install || true
    fail "Finish installing Apple's Command Line Tools, then rerun this command."
  fi

  local brew_bin
  if ! brew_bin="$(find_brew)"; then
    step "Installing Homebrew"
    sudo -v
    NONINTERACTIVE=1 download_and_run https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
    brew_bin="$(find_brew)" || fail "Homebrew installation did not complete."
  fi
  eval "$("$brew_bin" shellenv)"
  export HOMEBREW_NO_AUTO_UPDATE=1
  install_bundle "$brew_bin" Brewfile
  if [[ "$profile" == full ]]; then
    install_bundle "$brew_bin" Brewfile.full
  fi
}

install_bundle() {
  local brew_bin="$1" manifest="$dotfiles_dir/$2"
  if "$brew_bin" bundle check --no-upgrade --file="$manifest" >/dev/null 2>&1; then
    printf 'Packages already installed: %s\n' "$2"
  else
    "$brew_bin" bundle install --no-upgrade --file="$manifest"
  fi
}
