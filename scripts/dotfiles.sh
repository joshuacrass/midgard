#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
check_host
# Deploy the referenced commands before settings that enable them.
deploy "$ROOT/config/claude/statusline.sh" "$HOME/.claude/statusline.sh"
deploy "$ROOT/config/claude/hooks/confirm-push-merge.sh" "$HOME/.claude/hooks/confirm-push-merge.sh"
deploy "$ROOT/config/claude/settings.json" "$HOME/.claude/settings.json" merge-json
deploy "$ROOT/config/codex/config.toml" "$HOME/.codex/config.toml" create-only
# Global Git preferences are set only when unset. Identity (user.name/email) stays manual.
while read -r key value; do
    current=$(git config --global --get "$key" || true)
    case $current in
        "$value") say "Git $key already $value." ;;
        '') run git config --global "$key" "$value" ;;
        *) say "PRESERVE Git $key ($current); set $value manually if desired." ;;
    esac
done <<'EOF'
init.defaultBranch dev
core.editor vi
fetch.prune true
rerere.enabled true
EOF
