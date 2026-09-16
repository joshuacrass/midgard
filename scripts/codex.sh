#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
source "$ROOT/config/versions.sh"
if command -v codex >/dev/null; then
    say "Existing Codex retained at $(command -v codex); baseline $CODEX_VERSION."
else
    export CODEX_NON_INTERACTIVE=1
    vendor_install https://chatgpt.com/codex/install.sh sh --release "$CODEX_VERSION"
fi
native_shadowed codex @openai/codex
# Codex rewrites its own config, so the repository only seeds a new host.
deploy "$ROOT/config/codex/config.toml" "$HOME/.codex/config.toml" create-only
say 'Codex authentication is manual; credentials are never copied.'
