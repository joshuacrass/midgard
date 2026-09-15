#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
check_host
# Deploy the referenced commands before settings that enable them.
deploy "$ROOT/config/claude/statusline.sh" "$HOME/.claude/statusline.sh"
deploy "$ROOT/config/claude/hooks/confirm-push-merge.sh" "$HOME/.claude/hooks/confirm-push-merge.sh"
deploy "$ROOT/config/claude/settings.json" "$HOME/.claude/settings.json" merge-json
branch=$(git config --global --get init.defaultBranch || true)
case $branch in
    dev) say 'Git default branch already dev.' ;;
    '') run git config --global init.defaultBranch dev ;;
    *) say "PRESERVE Git default branch ($branch); set dev manually if desired." ;;
esac
