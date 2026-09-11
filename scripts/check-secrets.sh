#!/bin/bash
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
export PATH="$target_dir/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
command -v gitleaks >/dev/null 2>&1 || fail "Install gitleaks with bash scripts/install-gitleaks.sh, then rerun."
case "${1:-}" in
  --staged) exec gitleaks git "$dotfiles_dir" --pre-commit --staged --redact --no-banner --timeout 60 ;;
  "") exec gitleaks git "$dotfiles_dir" --log-opts=HEAD --redact --no-banner --timeout 60 ;;
  *) fail "Usage: bash scripts/check-secrets.sh [--staged]" ;;
esac
