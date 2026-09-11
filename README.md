# dotfiles

My macOS and Ubuntu setup: applications, shell, fonts, and settings for Kitty,
Zed, Ghostty, Zellij, tmux, htop, Git, and Powerlevel10k.

## New machine

On a new Mac, install Apple's Command Line Tools first with
`xcode-select --install` and wait for the installation to finish. On Ubuntu
24.04 or newer, start with `sudo apt-get update && sudo apt-get install -y git curl`.
Then:

```sh
mkdir -p ~/projects
git clone https://github.com/aubin-tchoi/dotfiles.git ~/projects/dotfiles
cd ~/projects/dotfiles
bash install.sh
```

The default installs the essential tools, Node LTS through nvm, Bun, Oh My Zsh,
Powerlevel10k, shell plugins, and the saved configuration. On macOS it installs
Homebrew when needed, plus Kitty, Zed, Raycast, Codex, and JetBrains Mono fonts.
Package installation may ask for your administrator password.

| Command | Purpose |
| --- | --- |
| `bash install.sh` | Essential setup |
| `bash install.sh --full` | Also install the optional apps and development tools |
| `bash install.sh --check` | Read-only report of missing essentials and config drift |
| `bash install.sh --full --check` | Check the full profile |
| `bash install.sh --link-only` | Back up and link settings without installing software |
| `bash install.sh --macos-defaults` | Also apply the saved macOS preferences |
| `bash install.sh --restore-private /path/to/backup` | Also restore private overrides |

Options can be combined, for example:

```sh
bash install.sh --full --macos-defaults --restore-private /path/to/backup
```

Check mode cannot be combined with options
that change settings. Checks exit with status 1 when something needs attention.

On an existing installation, pull this repository and rerun the same command.
Completed installs and correct links are skipped. Existing packages, plugin
checkouts, and the default Node version are preserved. An installation error
stops setup and identifies the phase to retry. This is a current setup recipe,
not a lockfile; a fresh machine downloads the versions available at that time.

## What gets installed

- [Brewfile](Brewfile): essential macOS applications, fonts, and CLI tools,
  including Git LFS, direnv, fzf, and Gitleaks.
- [Brewfile.full](Brewfile.full): optional macOS additions, including Ghostty,
  Zellij, Docker Desktop, OrbStack, database tools, Kubernetes tools, Terraform,
  Google Cloud CLI, Poetry, and other development utilities.
- [packages/ubuntu.txt](packages/ubuntu.txt) and
  [packages/ubuntu-full.txt](packages/ubuntu-full.txt): Ubuntu packages. Linux
  includes Kitty and the shared shell setup; the full profile adds build tools,
  database clients, Neovim, Terminator, and Poetry. The macOS app collection is
  not installed on Linux; install Zed and other desired Linux apps separately.
- [scripts/plugins.txt](scripts/plugins.txt): the custom Oh My Zsh plugins.

Node is managed by nvm, avoiding a second Homebrew Node installation. If nvm
already has a usable default, it is kept. Bun is installed in `~/.local` through
npm when absent. On Ubuntu, diff-so-fancy uses the same user-local npm prefix.
Homebrew and apt only install missing packages during setup; use their normal
update commands when you deliberately want upgrades.

## Settings and backups

[scripts/config-files.txt](scripts/config-files.txt) is the explicit list of
shared files to link. Existing files and conflicting symlinks are moved to
`.backup.TIMESTAMP.PID` siblings; reruns leave correct links alone. To undo a
link, remove that symlink and move its backup back to the original name.
Individual config files are linked so application databases and caches stay in
their own directories. Zed installs the extensions listed in its settings.

On macOS both Ghostty config locations are linked to the saved configuration,
including `~/Library/Application Support/com.mitchellh.ghostty/config`, which
can otherwise override `~/.config/ghostty/config`.

Keep credentials and machine-specific settings in `~/.zshrc.local`, sourced
last by zsh. Git loads `~/.gitconfig.local`; it can point `core.excludesFile` at
`~/.gitignore.local` for additional private ignore rules. These files are not
part of the public repository.

## Private restore and Raycast

Keep a private backup directory outside this repository with any of these files:

```text
.zshrc.local
.gitconfig.local
.gitignore.local
raycast.rayconfig
```

Restore it during setup with `--restore-private DIR`, or independently:

```sh
bash scripts/restore-private.sh /path/to/private-backup
```

Only those four filenames are accepted. Existing different files are backed up,
restored files use mode `0600`, and identical files are left in place. Secrets
are never printed. The Raycast export is copied to
`~/.local/state/dotfiles/private/raycast.rayconfig` for manual import.

[Raycast backup instructions and the extension inventory](config/raycast/README.md)
explain exporting and importing settings. The public inventory cannot restore
hotkeys, aliases, or extension credentials; create a private encrypted export
before retiring the old machine. Keep its passphrase in your password manager.

## macOS preferences

`--macos-defaults` applies only the six preferences in
[config/macos/defaults.json](config/macos/defaults.json): key repeat, initial key
repeat delay, natural scrolling, Dock autohide, Finder list view, and trackpad
tap-to-click. Unrelated preferences are left alone.

The original values and types of changed keys are saved privately under
`~/.local/state/dotfiles/macos/`. Setup prints the exact restore command:

```sh
python3 scripts/macos-defaults.py restore /path/to/backup.json
```

A rerun that finds matching settings makes no new backup. Restoring also removes
individual overrides that were originally absent. Log out and back in after
applying or restoring preferences to load every change.

## Finish setup

1. Open a new terminal. On Ubuntu, choose zsh as your login shell with
   `chsh -s "$(command -v zsh)"`, then log out and back in.
2. Run `gh auth login` and sign in to the applications you use. Restore SSH keys
   through your private key manager if needed.
3. Import your private Raycast export, selecting the desired categories.
4. Grant Accessibility, Screen Recording, and other permissions when requested
   by apps. Configure your password manager and browser sync.
5. Run `bash install.sh --check` (or `--full --check`).

## Repository checks

```sh
python3 -m unittest discover -s tests -v
bash scripts/check-secrets.sh
```

Tests use temporary targets and fake installers to exercise both platforms,
reruns, interrupted installs, backups, and preference restoration. CI runs them
on macOS and Ubuntu, checks shell and JSON syntax, and scans branch history for
secrets. Tests do not install applications or change this machine's preferences.

Setup enables this repository's staged-secret pre-commit check unless you
already configured a custom Git hooks directory. With custom hooks, run
`bash scripts/check-secrets.sh --staged` before committing. Install the scanner
alone with `bash scripts/install-gitleaks.sh`. The scanner catches common secret
patterns; review the staged diff as well, since personal details and internal
identifiers are not necessarily secrets it recognizes. Private overrides,
`.env` files, databases, and `.rayconfig` exports are ignored by Git.
