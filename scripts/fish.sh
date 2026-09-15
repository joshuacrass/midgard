#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
check_host
deploy "$ROOT/config/fish/config.fish" "$HOME/.config/fish/config.fish"
say 'Login shell is unchanged. On a fresh host, choose Fish manually after verifying it works.'
