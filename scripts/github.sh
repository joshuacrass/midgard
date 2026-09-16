#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
# Match the working machine: Ubuntu supplies gh, with authentication kept local.
packages gh
say 'GitHub authentication is manual: gh auth login --git-protocol ssh'
