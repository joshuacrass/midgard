# Midgard

Midgard is my permanent remote development server: an Ubuntu 24.04 LTS VM accessed through Tailscale and SSH, with persistent work inside tmux. This repository captures its working configuration and bootstraps the tools needed to rebuild it.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the design and [DECISIONS.md](DECISIONS.md) for the rationale.

## Captured baseline

| Component | Baseline |
| --- | --- |
| Platform | Ubuntu 24.04 LTS; x86_64 or aarch64 |
| Interactive shell / automation | Fish / Bash |
| Persistent workspace | tmux; existing cobalt2 theme and all six palettes |
| Networking | Tailscale; SSH over the tailnet |
| Containers | Docker Engine and Compose from Docker's official repository |
| Runtime manager | mise 2026.9.9 |
| Languages | Node 24.21.0, Go 1.27.1, Python 3.13.15 |
| JavaScript package manager | Corepack / Yarn 4.18.0 |
| Coding agents | Claude Code 2.1.272; Codex 0.154.0 |
| Git | Default branch `dev`, editor `vi`, `fetch.prune`, `rerere.enabled`; GitHub CLI; SSH authentication |

Language versions are pinned in `config/mise/config.toml`; installer versions are in `config/versions.sh`. Existing mise and agent installations are retained, even if their versions differ. Fresh agent installations use the vendors' native installers, avoiding global npm installs. Ubuntu, Docker, GitHub CLI, and Tailscale packages use their configured repositories and are not version-pinned. Claude's normal update behavior remains unchanged.

This reproduces the configuration and tool baseline, not a byte-identical OS image. Downloads require upstream availability. The current VM is x86_64; aarch64 is supported by the script checks but has not been tested here.

## Prerequisites

- Ubuntu Server 24.04 LTS with a normal user, sudo access, Git, and system Python 3.12+.
- Working SSH key access and an existing safe connection to the server.
- Outbound HTTPS access to Ubuntu and vendor repositories.
- Run as the target user, **without `sudo` on bootstrap itself**.

Bootstrap does not configure SSH, router forwarding, addresses, disks, ESXi, or Tailscale identity. Prepare SSH access during OS installation. It does not change the login shell or authenticate accounts.

### OS installation checklist

Size the VM before installing. Bootstrap adds about 2 GB to a 5 GB Ubuntu Server install and downloads about 1.5 GB; the Claude installer needs 512 MB of free memory. The production numbers are the current Midgard VM, which runs the full tool set, Docker infrastructure, and both coding agents with headroom.

| Purpose | vCPU | Memory | Disk |
| --- | --- | --- | --- |
| Disposable test rebuild | 2 | 4 GB | 25 GB (installer default) |
| Production Midgard | 4 | 16 GB | 48 GB |

Only the disk grows with use: container volumes and local model weights are the items to plan for. The production disk is a quarter used after bootstrap and several repositories. Memory is the first limit for future AI workloads.

Bootstrap depends on these installer choices and never changes them:

- **Hostname `midgard`.** The Tailscale MagicDNS name derives from it. Remove the previous Midgard node in the Tailscale admin console before authenticating the rebuilt machine, otherwise it becomes `midgard-1`.
- **Your normal user in the `sudo` group.** Bootstrap runs as that user and calls `sudo` for packages and services. Do not enable a root login.
- **SSH public key imported during installation.** Ubuntu records the installer's password-authentication choice in `/etc/ssh/sshd_config.d/50-cloud-init.conf`. sshd keeps the first value it reads and includes drop-ins in name order, so enforce key-only login regardless of that choice, after confirming a key login works from another terminal:

  ```sh
  printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\n' | sudo tee /etc/ssh/sshd_config.d/10-midgard.conf
  sudo sshd -t && sudo systemctl reload ssh
  ```
- **No snaps from the "Featured Server Snaps" screen.** Docker comes from Docker's repository; the docker step refuses to proceed beside a Docker snap.
- **OpenSSH server enabled.** The working host also has `unattended-upgrades` running and `ufw` installed but inactive, both Ubuntu Server defaults; there are no firewall rules to restore. Inbound access is limited by the network and Tailscale, not by a host firewall. Bootstrap manages neither.
- **Timezone `Etc/UTC`, locale `en_US.UTF-8`.** These are the captured values; nothing in the repository depends on them.
- **Install Git after the first login:** `sudo apt-get install -y git`. Python 3.12 is already present on Ubuntu Server.

## Fresh installation

Run each step after verifying the previous one succeeds. Git and Python can be installed with Ubuntu's package manager if missing.

Clone the public repository without needing GitHub authentication:

```sh
git clone https://github.com/joshuacrass/midgard.git ~/development/midgard
```

Enter the repository:

```sh
cd ~/development/midgard
```

Inspect the plan (also the default when no arguments are supplied):

```sh
bash bootstrap.sh --dry-run
```

Apply it once the plan is understood:

```sh
bash bootstrap.sh --apply
```

The ordered steps are `system,docker,mise,languages,yarn,github,git,tailscale,claude,codex,fish,tmux`. Each step installs and configures one concern. To run a subset:

```sh
bash bootstrap.sh --dry-run --only fish,tmux
```

`--only` keeps dependency order but does not add prerequisites. An installation failure stops the run; fix the cause and rerun the affected step. Missing packages are installed with `apt-get --no-remove`; existing packages are not explicitly upgraded. Package dependencies can still be updated by APT.

### Existing configuration

Identical files are left alone. Differing files produce a `PRESERVE` notice and are skipped. A successful bootstrap with these notices means reconciliation remains: inspect the differences before adopting repository configuration. Add `--diff` to a dry-run to print how each preserved plain-text file differs; merged JSON settings are never printed.

For example, after comparing the live and repository Fish configuration:

```sh
bash bootstrap.sh --dry-run --only fish --replace-config
```

Then apply that specific change:

```sh
bash bootstrap.sh --apply --only fish --replace-config
```

Replacement creates a private backup under `~/.local/state/midgard/backups/` first. Symlink destinations are refused. Claude settings are merged, retaining existing hooks, permissions, and unrelated keys. No live tmux session is reloaded. See [configuration notes](docs/configuration.md) for exact paths and the Claude confirmation hook.

## Manual setup and authentication

Complete these one at a time:

1. **New Tailscale machine:** remove the old node in the admin console, then run `sudo tailscale up` and authenticate in the browser. Verify tailnet access before relying on it. Do not reauthenticate or reset a working Midgard identity.
2. **Docker:** log out and back in if the docker group was newly added. Verify with `docker info`; optionally run `docker run --rm hello-world` (downloads and runs a container).
3. **Fish:** verify `fish --version`, then run `chsh -s /usr/bin/fish` if it is not already your login shell. Reconnect. The managed configuration adds `~/.local/bin` and activates mise.
4. **Git:** set your own `user.name` and `user.email`; these are not stored here.
5. **GitHub:** run `gh auth login` and choose SSH as the Git protocol. Register or restore your SSH key privately and verify GitHub access. Then change this checkout's origin to `git@github.com:joshuacrass/midgard.git` if it was cloned over HTTPS.
6. **Claude Code:** run `claude` and complete authentication. Verify the push/merge confirmation hook is registered in settings before allowing agent Git operations.
7. **Codex:** run `codex` and choose Sign in with ChatGPT. Complete the offered authentication flow.
8. **tmux:** start a new session with `tmux new -s dev`. Existing sessions are preserved by bootstrap.

Credentials, agent sessions/history, SSH keys, `.env` files, and Tailscale state are never captured. Store private recovery material separately.

### Private material to back up

Bootstrap recreates everything else; only these need your own backup or re-creation:

- `~/.ssh/`: keys, `config`, and `authorized_keys`. Alternatively generate a new key and register it with GitHub.
- `~/.config/gh/hosts.yml`: GitHub CLI token. Alternatively run `gh auth login` again.
- `~/.claude/.credentials.json` and `~/.codex/auth.json`: agent sessions. Alternatively authenticate again.
- `~/.claude/settings.mac.json`: Mac-side Claude settings kept alongside the server ones; not deployed by bootstrap.
- `~/development/`: repositories. Re-clone from GitHub if nothing is unpushed.
- Docker volumes: list with `docker volume ls`; back up any that hold data you cannot rebuild.
- Tailscale identity: not portable. Authenticate the new machine as described above.

## Recovery

1. Install Ubuntu, restore safe SSH access, and create the login user.
2. Clone this repository and inspect its dry-run.
3. Apply bootstrap and review every `PRESERVE` notice.
4. Authenticate accounts manually; restore private application data and repositories from your own backups.
5. Reconnect through Tailscale and start tmux.

To undo an explicitly replaced configuration file, compare it with the corresponding timestamped backup under `~/.local/state/midgard/backups/`, then restore that file manually. Keep these backups private: they may contain old local settings. Bootstrap is incremental, not transactional; it does not roll back package installations or earlier successful steps.

## Validation

```sh
/usr/bin/python3 tests/test_bootstrap.py
```

```sh
bash scripts/check.sh
```

```sh
bash bootstrap.sh --dry-run
```

Tests use temporary homes and synthetic input. Dry-run prints intended changes without downloading packages/installers, authenticating, or writing configuration. It reads installed package state, mise paths, and service status. ShellCheck is included in the base package list; `scripts/check.sh` requires it to be available.

The acceptance test applies the complete bootstrap on a fresh host:

```sh
bash tests/fresh-host.sh
```

It builds a minimal Ubuntu 24.04 systemd container holding only the prerequisites above, mounts this repository read-only, runs `bootstrap.sh --apply` including the Docker and Tailscale steps, requires the second dry-run to report no pending changes, and checks every tool against its pin. It needs Docker and network access and changes nothing on the host. GitHub Actions runs it on every push and weekly.

The full apply last passed on 2026-09-16 (this container test; every step, no manual intervention). A container shares the host kernel, so a disposable VM remains the final check for the OS installation checklist and Tailscale authentication.

## Upstream installation references

- [Docker on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
- [mise installation](https://mise.jdx.dev/installing-mise.html)
- [Corepack](https://github.com/nodejs/corepack)
- [Tailscale Ubuntu packages](https://pkgs.tailscale.com/stable/#ubuntu-noble)
- [Claude installation](https://code.claude.com/docs/en/setup) and [hooks](https://code.claude.com/docs/en/hooks)
- [Codex CLI](https://learn.chatgpt.com/docs/codex/cli)
