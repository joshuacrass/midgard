#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
check_host
deploy "$ROOT/config/tmux/tmux.conf" "$HOME/.tmux.conf"
while IFS= read -r -d '' file; do
    deploy "$file" "$HOME/.config/tmux/${file#"$ROOT/config/tmux/"}"
done < <(find "$ROOT/config/tmux" -type f ! -name tmux.conf ! -name .current-theme -print0)
# theme.sh rewrites the selected theme on every switch: seed the default, never replace it.
deploy "$ROOT/config/tmux/.current-theme" "$HOME/.config/tmux/.current-theme" create-only
say 'tmux configuration deployed or compared; existing sessions were not reloaded.'
