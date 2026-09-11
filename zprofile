# Homebrew must be on PATH before shell plugins load (Apple Silicon or Intel).
if [[ -z "${HOMEBREW_PREFIX:-}" ]]; then
  for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    if [[ -x "$brew_bin" ]]; then
      eval "$("$brew_bin" shellenv)"
      break
    fi
  done
  unset brew_bin
fi

typeset -U path
path=("$HOME/.local/bin" "$HOME/.bun/bin" $path)
[[ ! -d "$HOME/Library/Application Support/JetBrains/Toolbox/scripts" ]] || path+=("$HOME/Library/Application Support/JetBrains/Toolbox/scripts")
[[ ! -f "$HOME/.orbstack/shell/init.zsh" ]] || source "$HOME/.orbstack/shell/init.zsh"
