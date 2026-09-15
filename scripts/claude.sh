#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
source "$ROOT/config/versions.sh"
check_host
if command -v claude >/dev/null; then
    say "Existing Claude retained at $(command -v claude); baseline $CLAUDE_VERSION."
else
    vendor_install https://claude.ai/install.sh bash "$CLAUDE_VERSION"
fi
say 'Claude authentication is manual. Configuration is handled by the dotfiles step.'
