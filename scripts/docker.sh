#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
for package in docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc; do
    installed "$package" && die "Conflicting $package is installed; manual review required. Nothing removed."
done
arch=$(dpkg --print-architecture)
apt_source download.docker.com https://download.docker.com/linux/ubuntu/gpg \
    /etc/apt/keyrings/docker.asc /etc/apt/sources.list.d/midgard-docker.list \
    "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable"
packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
service_on docker
if id -nG "$(id -un)" | tr ' ' '\n' | grep -qx docker; then
    say 'User already belongs to docker group.'
else
    run sudo usermod -aG docker "$(id -un)"
    say 'Log out and back in before using Docker without sudo.'
fi
