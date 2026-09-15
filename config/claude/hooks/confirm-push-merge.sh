#!/usr/bin/env bash
#
# PreToolUse/Bash — force an explicit confirmation prompt before any push or merge.
#
# Permission rules alone are not enough: they prefix-match, so `Bash(git push *)` misses
# `git -C /repo push`, `cd sub && git push`, and anything behind a shell alias. This
# inspects the whole command string instead, and returns permissionDecision "ask", which
# a hook can assert in EVERY permission mode — including auto mode, where a broad allow
# rule like `Bash(gh pr *)` would otherwise let `gh pr merge` through silently.
#
# Fails open by design: if jq is missing or the payload is unreadable, it stays quiet and
# the normal permission machinery decides. It never auto-approves anything.

set -uo pipefail

cmd=$(jq -r '.tool_input.command // ""' 2>/dev/null) || exit 0

# `[^;&|]*` keeps the match inside one shell command, so `echo hi && git push` still
# matches on its own segment. Word boundaries exclude `--merges`, `--merged`, `push-notes`.
if printf '%s' "$cmd" | grep -Eq '\bgit\b[^;&|]*\b(push|merge)\b|\bgh\b[^;&|]*\bpr\b[^;&|]*\bmerge\b|\bgh\b[^;&|]*\bapi\b[^;&|]*merge'; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Pushes and merges always require explicit confirmation (~/.claude/hooks/confirm-push-merge.sh)."}}'
fi

exit 0
