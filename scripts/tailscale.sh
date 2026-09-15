#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
check_host
apt_source pkgs.tailscale.com https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg \
    /etc/apt/keyrings/tailscale.gpg /etc/apt/sources.list.d/midgard-tailscale.list \
    'deb [signed-by=/etc/apt/keyrings/tailscale.gpg] https://pkgs.tailscale.com/stable/ubuntu noble main'
packages tailscale
service_on tailscaled
say 'On a NEW machine only, authenticate manually with sudo tailscale up. Existing identity is retained.'
