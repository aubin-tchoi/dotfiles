#!/bin/bash
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
profile="${1:-core}"
requirements_missing=0
ok() { printf 'OK    %s\n' "$*"; }
need() { printf 'NEEDS %s\n' "$*"; requirements_missing=$((requirements_missing + 1)); }
export PATH="$target_dir/.local/bin:$target_dir/.bun/bin:$PATH"
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1

if [[ "$platform" == Darwin ]]; then
  if brew_bin="$(find_brew)"; then
    eval "$("$brew_bin" shellenv)"
    manifests=(Brewfile)
    [[ "$profile" != full ]] || manifests+=(Brewfile.full)
    for manifest in "${manifests[@]}"; do
      if "$brew_bin" bundle check --no-upgrade --verbose --file="$dotfiles_dir/$manifest"; then
        ok "$manifest packages"
      else
        need "$manifest packages; rerun the installer with the same profile"
      fi
    done
  else
    need "Homebrew"
  fi
elif [[ "$platform" == Linux ]]; then
  # shellcheck source=scripts/ubuntu.sh
  source "$dotfiles_dir/scripts/ubuntu.sh"
  while IFS= read -r package; do
    [[ -z "$package" || "$package" == \#* ]] && continue
    status="$(dpkg-query -W -f='${Status}' "$package" 2>/dev/null || true)"
    [[ "$status" == 'install ok installed' ]] || need "Ubuntu package: $package"
  done < <(ubuntu_packages)
fi

for name in git curl zsh bat diff-so-fancy direnv fzf gh git-lfs gitleaks htop jq python3 rg tmux tree bun; do
  if command -v "$name" >/dev/null 2>&1; then ok "$name"; else need "$name"; fi
done
if [[ "$platform" == Linux && "$profile" == full ]]; then
  if command -v poetry >/dev/null 2>&1; then ok "poetry"; else need "poetry"; fi
fi

zsh_dir="$target_dir/.oh-my-zsh"
for file in "$zsh_dir/oh-my-zsh.sh" "$zsh_dir/custom/themes/powerlevel10k/powerlevel10k.zsh-theme"; do
  if [[ -f "$file" ]]; then ok "$file"; else need "$file"; fi
done
while read -r name _url expected; do
  if [[ -f "$zsh_dir/custom/plugins/$name/$expected" ]]; then ok "$name"; else need "Shell plugin: $name"; fi
done < "$dotfiles_dir/scripts/plugins.txt"

# Load only nvm's library, never the user's shell or private overrides.
node_path=""
if [[ -s "$target_dir/.nvm/nvm.sh" ]]; then
  node_path="$(NVM_DIR="$target_dir/.nvm" bash -c 'source "$NVM_DIR/nvm.sh" --no-use; nvm which default' 2>/dev/null || true)"
fi
if [[ -x "$node_path" ]]; then ok "Default Node: $node_path"; else need "Node LTS and an nvm default alias"; fi

while IFS=$'\t' read -r source target; do
  if [[ -L "$target" && "$target" -ef "$source" ]]; then
    ok "$target"
  else
    need "Configuration link: $target"
  fi
done < <(config_links)

if command -v zsh >/dev/null 2>&1; then
  for file in zshrc zprofile p10k.zsh; do
    if zsh -n "$dotfiles_dir/$file"; then ok "$file syntax"; else need "$file syntax"; fi
  done
fi
if command -v python3 >/dev/null 2>&1; then
  if python3 "$dotfiles_dir/scripts/check-json.py"; then ok "JSON settings syntax"; else need "JSON settings syntax"; fi
fi
for name in .zshrc.local .gitconfig.local .gitignore.local; do
  if [[ -f "$target_dir/$name" ]]; then
    printf 'LOCAL %s exists (contents not inspected)\n' "$name"
  else
    printf 'LOCAL %s absent (optional private restore)\n' "$name"
  fi
done
printf '\nSign-ins, Raycast import, default login shell, and app permissions need a manual check.\n'
if [[ "$requirements_missing" -gt 0 ]]; then
  printf '%s requirement(s) need attention.\n' "$requirements_missing"
  exit 1
fi
printf 'All automated checks passed.\n'
