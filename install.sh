#!/bin/bash
set -Eeuo pipefail

# shellcheck source=scripts/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/scripts/lib.sh"
profile=core
mode=install
apply_defaults=false
private_source=""
phase="reading options"
trap 'printf "Setup stopped while %s (line %s). Fix the error above and rerun the same command.\n" "$phase" "$LINENO" >&2' ERR

usage() {
  cat <<'USAGE'
Usage: bash install.sh [options]
  --full                  Include optional applications and development tools
  --check                 Report missing tools and configuration; change nothing
  --link-only             Back up and link configuration without installing software
  --macos-defaults         Apply the saved macOS preferences, with a restore backup
  --restore-private DIR   Restore allowlisted local overrides from a private backup
  --help                  Show this help

Defaults to the essential macOS or Ubuntu setup. Existing packages and Node
versions are preserved; rerunning resumes installation without upgrading them.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --full) profile=full ;;
    --check|--link-only)
      [[ "$mode" == install ]] || fail "Choose only one of --check and --link-only."
      mode="${1#--}"
      ;;
    --macos-defaults) apply_defaults=true ;;
    --restore-private)
      [[ $# -ge 2 && "$2" != --* ]] || fail "--restore-private requires a directory."
      private_source="$2"
      shift
      ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; fail "Unknown option: $1" ;;
  esac
  shift
done

[[ "$platform" == Darwin || "$platform" == Linux ]] || fail "Supported platforms are macOS and Ubuntu."
if [[ "$mode" == check ]]; then
  [[ "$apply_defaults" == false && -z "$private_source" ]] || fail "--check cannot be combined with options that change settings."
  exec bash "$dotfiles_dir/scripts/check.sh" "$profile"
fi
[[ "$apply_defaults" == false || "$platform" == Darwin ]] || fail "--macos-defaults requires macOS."
[[ -z "$private_source" || -d "$private_source" ]] || fail "Private backup directory does not exist."

export PATH="$target_dir/.local/bin:$target_dir/.bun/bin:$PATH"
if [[ "$mode" == install ]]; then
  phase="installing $profile packages"
  step "$phase"
  if [[ "$platform" == Darwin ]]; then
    # shellcheck source=scripts/macos.sh
    source "$dotfiles_dir/scripts/macos.sh"
    install_macos_packages
  else
    # shellcheck source=scripts/ubuntu.sh
    source "$dotfiles_dir/scripts/ubuntu.sh"
    install_ubuntu_packages
  fi

  # shellcheck source=scripts/shell.sh
  source "$dotfiles_dir/scripts/shell.sh"
  phase="installing the shell and plugins"
  step "$phase"
  install_shell
  phase="installing Node and Bun"
  step "$phase"
  install_runtimes
  phase="installing the secret scanner"
  bash "$dotfiles_dir/scripts/install-gitleaks.sh"
fi

phase="linking configuration"
step "$phase"
bash "$dotfiles_dir/scripts/link.sh" "$target_dir"
if [[ -n "$private_source" ]]; then
  phase="restoring private overrides"
  bash "$dotfiles_dir/scripts/restore-private.sh" "$private_source"
fi
if [[ "$apply_defaults" == true ]]; then
  phase="applying macOS preferences"
  python3 "$dotfiles_dir/scripts/macos-defaults.py" apply
fi

if [[ "$mode" == install ]]; then
  phase="enabling the repository's secret scan"
  existing_hooks="$(git -C "$dotfiles_dir" config --local --get core.hooksPath || true)"
  if [[ -z "$existing_hooks" || "$existing_hooks" == .githooks ]]; then
    git -C "$dotfiles_dir" config --local core.hooksPath .githooks
  else
    printf 'Keeping existing Git hooks. Run bash scripts/check-secrets.sh --staged before committing.\n'
  fi
  phase="checking the completed setup"
  bash "$dotfiles_dir/scripts/check.sh" "$profile"
fi

cat <<'NEXT'

Setup complete. Open a new terminal to load the configuration.
Remaining personal steps:
  - Sign in with gh auth login, then sign in to your applications.
  - Restore private overrides with --restore-private DIR if needed.
  - In Raycast, import your private .rayconfig backup and select the desired categories.
  - Grant app permissions in System Settings when the apps request them.
NEXT
