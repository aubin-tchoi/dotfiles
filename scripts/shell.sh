#!/bin/bash
# Sourced by install.sh; context variables come from that entry point.
# shellcheck disable=SC2154

install_shell() {
  local zsh_dir="$target_dir/.oh-my-zsh" name url expected
  clone_once https://github.com/ohmyzsh/ohmyzsh "$zsh_dir" oh-my-zsh.sh
  while read -r name url expected; do
    clone_once "$url" "$zsh_dir/custom/plugins/$name" "$expected"
  done < "$dotfiles_dir/scripts/plugins.txt"
  clone_once https://github.com/romkatv/powerlevel10k "$zsh_dir/custom/themes/powerlevel10k" powerlevel10k.zsh-theme
}

install_runtimes() (
  export NVM_DIR="$target_dir/.nvm"
  clone_once https://github.com/nvm-sh/nvm "$NVM_DIR" nvm.sh --branch v0.40.7
  # nvm is an upstream shell library that does not support nounset.
  set +u
  # shellcheck disable=SC1091
  source "$NVM_DIR/nvm.sh" --no-use
  if [[ "$(nvm version default)" == N/A ]]; then
    nvm install --lts
    nvm alias default 'lts/*'
  fi
  nvm use --silent default
  if ! command -v bun >/dev/null 2>&1; then
    npm install --global --prefix "$target_dir/.local" bun
  fi
  if [[ "$platform" == Linux ]] && ! command -v diff-so-fancy >/dev/null 2>&1; then
    npm install --global --prefix "$target_dir/.local" diff-so-fancy
  fi
  if [[ "$platform" == Linux && "$profile" == full ]] && ! command -v poetry >/dev/null 2>&1; then
    pipx install poetry
  fi
)
