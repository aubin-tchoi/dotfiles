nvm() {
  case "$1" in
    version) [[ -f "$NVM_DIR/default" ]] && cat "$NVM_DIR/default" || printf 'N/A\n' ;;
    install)
      printf 'install\n' >> "$TEST_STATE/runtimes"
      mkdir -p "$NVM_DIR/versions/node/test/bin"
      printf '#!/bin/bash\nexit 0\n' > "$NVM_DIR/versions/node/test/bin/node"
      chmod +x "$NVM_DIR/versions/node/test/bin/node"
      ;;
    alias) printf 'test\n' > "$NVM_DIR/default" ;;
    use) export PATH="$NVM_DIR/versions/node/test/bin:$PATH" ;;
    which) [[ -f "$NVM_DIR/default" ]] && printf '%s/versions/node/test/bin/node\n' "$NVM_DIR" ;;
    *) return 1 ;;
  esac
}
