#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
source "$ROOT/config/versions.sh"
check_host
node_path
if ! command -v corepack >/dev/null; then
    if [[ $MIDGARD_MODE == dry-run ]]; then
        say 'Corepack will be supplied by the pinned Node 24 installation; run languages first.'
    else die 'Corepack is missing; inspect the pinned Node installation before proceeding.'; fi
fi
# Corepack install --global selects the default without changing project manifests.
# Do not invoke yarn during inspection: Corepack can download on first invocation.
cache=${COREPACK_HOME:-${XDG_CACHE_HOME:-$HOME/.cache}/node/corepack}
current=$(python3 - "$cache/lastKnownGood.json" <<'PY'
import json,sys
from pathlib import Path
p=Path(sys.argv[1])
print(json.loads(p.read_text()).get('yarn','').split('+')[0] if p.exists() else '')
PY
)
if [[ $current == "$YARN_VERSION" ]] && command -v yarn >/dev/null; then
    say "Yarn default already $YARN_VERSION."
else
    run corepack enable yarn
    run corepack install --global "yarn@$YARN_VERSION"
fi
