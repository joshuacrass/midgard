#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
check_host
packages ca-certificates curl gnupg git jq fish tmux ripgrep unzip xz-utils build-essential pkg-config python3 shellcheck
