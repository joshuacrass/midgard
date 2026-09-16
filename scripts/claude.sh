#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
source "$ROOT/config/versions.sh"
if command -v claude >/dev/null; then
    say "Existing Claude retained at $(command -v claude); baseline $CLAUDE_VERSION."
else
    vendor_install https://claude.ai/install.sh bash "$CLAUDE_VERSION"
fi
native_shadowed claude @anthropic-ai/claude-code
# Deploy the referenced commands before the settings that enable them.
deploy "$ROOT/config/claude/statusline.sh" "$HOME/.claude/statusline.sh"
deploy "$ROOT/config/claude/hooks/confirm-push-merge.sh" "$HOME/.claude/hooks/confirm-push-merge.sh"
deploy "$ROOT/config/claude/settings.json" "$HOME/.claude/settings.json" merge-json
say 'Claude authentication is manual.'
