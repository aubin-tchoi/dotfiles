# dotfiles

## Purpose

Personal macOS and Linux settings for Kitty, Zed, Ghostty, Zellij, tmux, htop,
Git, zsh, and Powerlevel10k. The macOS Brewfile records installed Homebrew
packages plus Kitty, Zed, and Raycast. Legacy `icu4c@76` and `postgresql@13`
installations are omitted; `libpq` supplies the PostgreSQL command-line tools.

## Installation

Clone this repository, then install the macOS packages if needed:

```sh
brew bundle --file=Brewfile
```

Link just the configuration files without installing software:

```sh
bash scripts/link.sh
```

Existing files and symlinks are moved to timestamped backups beside the originals.
Running the script again leaves correct links alone. Individual files are linked
so application caches, conversations, and databases stay outside this repository.
Zed automatically installs the extensions listed in its settings.

For a full shell bootstrap, run `bash install.sh`. It detects Linux or macOS,
installs oh-my-zsh and its plugins, and links these settings.

## Local settings

Put credentials and machine-specific overrides in `~/.zshrc.local`. It is sourced
at the end of `zshrc` and must be backed up privately. Git loads optional local
overrides from `~/.gitconfig.local`.

Ghostty on macOS also reads
`~/Library/Application Support/com.mitchellh.ghostty/config`; settings there may
override `~/.config/ghostty/config`. Check that file when restoring this setup.

## Raycast

The installed extension inventory and backup instructions are in
[config/raycast/README.md](config/raycast/README.md). A settings export is still
needed to restore Raycast hotkeys, aliases, and preferences. Full `.rayconfig`
exports contain private data and are ignored by Git.
