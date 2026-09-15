#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
check_host
deploy "$ROOT/config/tmux/tmux.conf" "$HOME/.tmux.conf"
while IFS= read -r -d '' file; do
    deploy "$file" "$HOME/.config/tmux/${file#"$ROOT/config/tmux/"}"
done < <(find "$ROOT/config/tmux" -type f ! -name tmux.conf -print0)
say 'tmux configuration deployed or compared; existing sessions were not reloaded.'
