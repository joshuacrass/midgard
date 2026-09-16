#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
while read -r tool version; do
    if command -v mise >/dev/null && mise where "$tool@$version" >/dev/null 2>&1; then
        say "$tool@$version already installed."
    else
        run mise install "$tool@$version"
    fi
done < <("$PYTHON" - "$ROOT/config/mise/config.toml" <<'PY'
import sys,tomllib
for name,version in tomllib.load(open(sys.argv[1],'rb'))['tools'].items():
    print(name,version)
PY
)
deploy "$ROOT/config/mise/config.toml" "$HOME/.config/mise/config.toml"
