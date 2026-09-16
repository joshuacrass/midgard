#!/usr/bin/env bash
# Shared helpers. Individual steps also default to inspection.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
MIDGARD_MODE=${MIDGARD_MODE:-dry-run}
MIDGARD_REPLACE_CONFIG=${MIDGARD_REPLACE_CONFIG:-0}
[[ $MIDGARD_MODE == apply || $MIDGARD_MODE == dry-run ]] || { echo 'Invalid mode' >&2; exit 2; }
export PATH="$HOME/.local/bin:$PATH"
# System interpreter: a fresh host has no mise Python, so never rely on the active shell's python3.
PYTHON=/usr/bin/python3
say() { printf '%s\n' "$*"; }
die() { say "ERROR: $*" >&2; exit 1; }
run() {
    printf '  '; printf '%q ' "$@"; printf '\n'
    if [[ $MIDGARD_MODE == apply ]]; then "$@"; fi
}
check_host() {
    local id version_id
    # Read os-release in a subshell so its NAME/VERSION/ID variables stay out of the steps.
    # shellcheck disable=SC2153 # ID and VERSION_ID are defined by os-release.
    read -r id version_id < <(. /etc/os-release && printf '%s %s\n' "$ID" "$VERSION_ID")
    [[ $id == ubuntu && $version_id == 24.04 ]] || die 'Requires Ubuntu 24.04 LTS.'
    [[ $(uname -m) == x86_64 || $(uname -m) == aarch64 ]] || die 'Requires x86_64 or aarch64.'
    [[ $EUID -ne 0 ]] || die 'Run as your normal login user, not root or sudo.'
}
installed() { [[ $(dpkg-query -W -f='${Status}' "$1" 2>/dev/null) == 'install ok installed' ]]; }
packages() {
    local missing=() package
    for package in "$@"; do installed "$package" || missing+=("$package"); done
    if ((${#missing[@]})); then
        run sudo apt-get update
        run sudo apt-get install --no-remove -y "${missing[@]}"
    else say 'Packages already installed.'; fi
}
service_on() {
    if systemctl is-enabled --quiet "$1" && systemctl is-active --quiet "$1"; then
        say "$1 already enabled and active."
    else run sudo systemctl enable --now "$1"; fi
}
deploy() {
    local args=("$ROOT/scripts/deploy-config.py" "$1" "$2" --mode "$MIDGARD_MODE")
    [[ $MIDGARD_REPLACE_CONFIG == 1 ]] && args+=(--replace)
    [[ ${3:-} == merge-json ]] && args+=(--merge-json)
    [[ ${3:-} == create-only ]] && args+=(--create-only)
    "$PYTHON" "${args[@]}"
}
# Print "tool version" for each runtime pinned in config/mise/config.toml.
pinned_tools() {
    "$PYTHON" - "$ROOT/config/mise/config.toml" <<'PY'
import sys, tomllib
for name, version in tomllib.load(open(sys.argv[1], 'rb'))['tools'].items():
    print(name, version)
PY
}
pinned_version() { pinned_tools | awk -v tool="$1" '$1 == tool { print $2 }'; }
node_path() {
    if command -v mise >/dev/null; then
        local p
        p=$(mise where "node@$(pinned_version node)" 2>/dev/null) || true
        [[ -z $p ]] || export PATH="$p/bin:$PATH"
    fi
}
# Add a vendor repository only when no definition for that vendor exists.
apt_source() {
    local vendor=$1 key_url=$2 key_path=$3 source_path=$4 line=$5
    if grep -rqsF "$vendor" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
        say "Existing $vendor repository retained."
        return
    fi
    [[ ! -e $source_path && ! -L $source_path ]] || die "Review existing $source_path before adding repository."
    if [[ $MIDGARD_MODE == dry-run ]]; then
        say "Would download $key_url to $key_path and create $source_path: $line"
        return
    fi
    (
        tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT
        curl --fail --show-error --silent --location "$key_url" -o "$tmp/key"
        printf '%s\n' "$line" > "$tmp/source"
        sudo install -d -m 0755 /etc/apt/keyrings
        sudo install -m 0644 "$tmp/key" "$key_path"
        sudo install -m 0644 "$tmp/source" "$source_path"
    )
}
# Installers are downloaded to a temporary file, never piped into a shell.
vendor_install() {
    local url=$1 shell=$2
    shift 2
    if [[ $MIDGARD_MODE == dry-run ]]; then
        say "Would download $url and run $shell with arguments: $*"
        return
    fi
    (
        tmp=$(mktemp); trap 'rm -f -- "$tmp"' EXIT
        curl --fail --show-error --silent --location "$url" -o "$tmp"
        "$shell" "$tmp" "$@"
    )
}
# Every step and bootstrap.sh source this file, so the host check runs exactly once per process.
check_host
