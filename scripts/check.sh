#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
while IFS= read -r -d '' file; do bash -n "$file"; done < <(find scripts config -name '*.sh' -print0)
bash -n bootstrap.sh
fish --no-config -n config/fish/config.fish
# Captured tmux/Claude scripts keep their original content; check syntax above.
# Dynamic source paths are intentional; all repository shell files are checked.
shellcheck -e SC1091 bootstrap.sh scripts/*.sh config/versions.sh
/usr/bin/python3 tests/test_bootstrap.py
