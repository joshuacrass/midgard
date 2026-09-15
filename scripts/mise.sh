#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
source "$ROOT/config/versions.sh"
check_host
if command -v mise >/dev/null; then
    say "Existing mise retained: $(mise --version)"
else
    export MISE_VERSION="v$MISE_VERSION" MISE_INSTALL_PATH="$HOME/.local/bin/mise"
    vendor_install https://mise.run sh
fi
