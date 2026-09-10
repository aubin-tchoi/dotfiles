#!/bin/bash
set -euo pipefail

dotfiles_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
target_dir="${1:-$HOME}"

link_config() {
  local source="$dotfiles_dir/$1"
  local target="$target_dir/.$1"
  local backup

  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    return
  fi

  mkdir -p "$(dirname "$target")"
  if [[ -e "$target" || -L "$target" ]]; then
    backup="$target.backup.$(date +%Y%m%d%H%M%S).$$"
    mv "$target" "$backup"
    echo "Backed up $target to $backup"
  fi
  ln -s "$source" "$target"
  echo "Linked $target"
}

for name in gitconfig gitignore zshrc zprofile p10k.zsh tmux.conf \
  config/htop/htoprc \
  config/kitty/kitty.conf config/kitty/current-theme.conf \
  config/kitty/GruvBox_DarkHard.conf \
  config/zed/settings.json config/zed/keymap.json \
  config/zellij/config.kdl config/ghostty/config \
  config/ghostty/themes/catppuccin-frappe config/ghostty/themes/catppuccin-latte \
  config/ghostty/themes/catppuccin-macchiato config/ghostty/themes/catppuccin-mocha; do
  link_config "$name"
done

if [[ "$(uname -s)" == Linux ]]; then
  link_config config/terminator/config
fi
