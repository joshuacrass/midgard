#!/usr/bin/env bash
# Compact git status for the status bar: "⎇ branch ↑ahead ↓behind ●dirty"
# Prints nothing when the pane isn't inside a git work tree.
dir="${1:-$PWD}"
cd "$dir" 2>/dev/null || exit 0

# Bail fast if we're not in a work tree.
[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ] || exit 0

branch=$(git symbolic-ref --short -q HEAD 2>/dev/null) \
  || branch=$(git rev-parse --short HEAD 2>/dev/null) \
  || exit 0
[ -z "$branch" ] && exit 0

out="⎇ $branch"

# Ahead/behind vs upstream, if one is configured.
if up=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null); then
  if counts=$(git rev-list --left-right --count "$up"...HEAD 2>/dev/null); then
    behind=${counts%%[[:space:]]*}
    ahead=${counts##*[[:space:]]}
    [ "${ahead:-0}" -gt 0 ] 2>/dev/null && out="$out #[fg=#f9e2af]↑$ahead#[fg=#a6e3a1]"
    [ "${behind:-0}" -gt 0 ] 2>/dev/null && out="$out #[fg=#fab387]↓$behind#[fg=#a6e3a1]"
  fi
fi

# Dirty working tree.
[ -n "$(git status --porcelain 2>/dev/null)" ] && out="$out #[fg=#f38ba8]●#[fg=#a6e3a1]"

printf '%s' "$out"
