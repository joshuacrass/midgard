#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export MIDGARD_MODE=dry-run MIDGARD_REPLACE_CONFIG=0
steps=(system docker mise languages yarn github tailscale claude codex fish tmux dotfiles)
sudo_steps=(system docker github tailscale)
selected=()
while (($#)); do
    case $1 in
        --dry-run) MIDGARD_MODE=dry-run ;;
        --apply) MIDGARD_MODE=apply ;;
        --replace-config) MIDGARD_REPLACE_CONFIG=1 ;;
        --only)
            shift
            [[ $# -gt 0 && -n $1 ]] || { echo '--only requires a comma-separated step list' >&2; exit 2; }
            IFS=, read -r -a selected <<< "$1"
            ;;
        --help|-h)
            echo 'Usage: ./bootstrap.sh [--dry-run|--apply] [--only step,...] [--replace-config]'
            echo "Steps (dependency order): ${steps[*]}"
            echo 'Default: dry-run. --only does not automatically install dependencies.'
            echo '--replace-config backs up conflicting files before applying repository configuration.'
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done
for step in "${selected[@]}"; do
    [[ " ${steps[*]} " == *" $step "* ]] || { echo "Unknown step: $step" >&2; exit 2; }
done
source "$ROOT/scripts/lib.sh"
cd "$HOME"
# Confirm sudo before the first privileged step rather than stalling on a prompt mid-run.
if [[ $MIDGARD_MODE == apply ]]; then
    for step in "${sudo_steps[@]}"; do
        if ((${#selected[@]})) && [[ " ${selected[*]} " != *" $step "* ]]; then continue; fi
        sudo -v || die 'sudo access is required for the selected steps.'
        break
    done
fi
for step in "${steps[@]}"; do
    if ((${#selected[@]})) && [[ " ${selected[*]} " != *" $step "* ]]; then continue; fi
    printf '\n== %s (%s) ==\n' "$step" "$MIDGARD_MODE"
    bash "$ROOT/scripts/$step.sh"
done
echo 'Finished. Review PRESERVE notices; authentication and login-shell changes are manual (see README).'
