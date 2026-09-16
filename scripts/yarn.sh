#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
source "$ROOT/config/versions.sh"
node_path
if ! command -v corepack >/dev/null; then
    if [[ $MIDGARD_MODE == dry-run ]]; then
        say 'Corepack is supplied by the pinned Node installation; run languages first.'
    else
        die 'Corepack is missing. Node 24 bundles it; Node 25 and later do not, so a newer pin needs Corepack installed before this step.'
    fi
fi
# Ask Corepack which Yarn it would run, with network access disabled so inspection can never
# download. Run outside any project so a package.json cannot influence the answer.
current=$(cd / && COREPACK_ENABLE_NETWORK=0 COREPACK_ENABLE_DOWNLOAD_PROMPT=0 corepack yarn --version 2>/dev/null) || current=''
if [[ $current == "$YARN_VERSION" ]] && command -v yarn >/dev/null; then
    say "Yarn default already $YARN_VERSION."
else
    # corepack install --global selects the default without changing project manifests.
    run corepack enable yarn
    run corepack install --global "yarn@$YARN_VERSION"
fi
