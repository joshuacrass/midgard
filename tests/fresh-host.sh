#!/usr/bin/env bash
# Acceptance test: apply the complete bootstrap inside a fresh Ubuntu 24.04 systemd container,
# then prove a second run is a no-op and every installed tool works. Requires Docker and
# network access; it downloads exactly what a rebuild downloads. Nothing on the host changes.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
name=midgard-fresh-host
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup
echo "== building $name image"
docker build -q -t "$name" "$ROOT/tests/fresh-host"
echo "== starting container"
docker run -d --name "$name" --hostname midgard --privileged --cgroupns=host \
    --tmpfs /run --tmpfs /run/lock -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    -v "$ROOT:/home/midgard/development/midgard:ro" "$name" >/dev/null
for _ in $(seq 60); do
    docker exec "$name" systemctl is-system-running 2>/dev/null | grep -qE 'running|degraded' && break
    sleep 1
done
as_user() { docker exec -u midgard -w /home/midgard/development/midgard "$name" bash -c "$1"; }

echo "== apply"
as_user 'bash bootstrap.sh --apply'

echo "== second dry-run must be a no-op"
second=$(as_user 'bash bootstrap.sh --dry-run')
printf '%s\n' "$second"
if grep -qE '^(CREATE|BACKUP|PRESERVE|Would |  )' <<<"$second"; then
    echo 'ERROR: second run still has pending changes' >&2; exit 1
fi

echo "== verify tools"
# shellcheck disable=SC2016 # The single-quoted script is expanded inside the container.
as_user '
set -euo pipefail
export PATH=$HOME/.local/bin:$PATH
mise --version
mise exec -- node --version
mise exec -- go version
mise exec -- python --version
mise exec -- yarn --version
claude --version
codex --version
gh --version | head -1
docker --version
sudo docker info --format "server: {{.ServerVersion}}"
tailscale --version | head -1
systemctl is-active docker tailscaled
fish --version
fish -c "node --version; string join \" \" \$PATH" | head -2
tmux -V
tmux new-session -d -s verify && tmux kill-server
git config --global --get init.defaultBranch
test -x ~/.claude/hooks/confirm-push-merge.sh
test -f ~/.codex/config.toml
'
echo "== fresh-host apply succeeded"
