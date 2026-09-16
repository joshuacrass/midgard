#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# Global Git preferences are set only when unset. Identity (user.name/email) stays manual.
while read -r key value; do
    current=$(git config --global --get "$key" || true)
    case $current in
        "$value") say "Git $key already $value." ;;
        '') run git config --global "$key" "$value" ;;
        *) say "PRESERVE Git $key ($current); set $value manually if desired." ;;
    esac
done <<'EOF2'
init.defaultBranch dev
core.editor vi
fetch.prune true
rerere.enabled true
EOF2
say 'Git identity is manual: git config --global user.name / user.email'
