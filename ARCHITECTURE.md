# Midgard Architecture

## Overview

Midgard is my permanent remote development workstation.

It is designed to be a reproducible Ubuntu server that can be rebuilt from scratch and accessed securely from anywhere using Tailscale.

The goal is for my Mac to become a lightweight client while Midgard hosts:

- source code
- development tools
- tmux sessions
- Docker containers
- AI coding agents
- local infrastructure
- future AI workloads

A new machine should be able to become Midgard by cloning this repository and running the bootstrap process.

---

# Design Goals

Midgard should be:

- reproducible
- secure
- simple
- reliable
- easy to recover
- pleasant to develop on
- accessible from anywhere

Infrastructure should favor boring, well-supported technology over unnecessary complexity.

---

# Hardware

Current platform:

- VMware ESXi virtual machine
- Ubuntu Server 24.04 LTS
- 4 vCPU
- 16 GB RAM
- 48 GB system disk

Future hardware may include:

- dedicated workstation
- Mac Studio
- GPU server
- Proxmox cluster

The software architecture should not depend on the underlying hardware.

---

# Network

Remote access is provided through Tailscale.

Preferred connection:

```
Mac
    │
Tailscale
    │
Midgard
```

SSH should always use the Tailscale hostname rather than LAN addresses whenever possible.

Current hostname:

```
midgard.tail6ef7a8.ts.net
```

No inbound SSH ports should be exposed to the public Internet.

---

# Development Workflow

Development happens remotely.

Typical workflow:

```
Mac
    │
SSH
    │
Midgard
    │
tmux
    │
Claude Code
Codex
Docker
Git
```

The local workstation should primarily act as a terminal and editor.

Development sessions should survive disconnects.

---

# Shell Environment

Interactive shell:

- Fish

Automation scripts:

- Bash

Language versions are managed using:

- mise

Global package management should be avoided whenever possible.

---

# Language Stack

Primary languages:

- JavaScript
- TypeScript
- Go
- Python

Preferred tooling:

- Node.js LTS
- Yarn 4
- Go
- Python
- Corepack
- mise

---

# AI Tooling

Primary coding agents:

- Claude Code
- OpenAI Codex

Configuration should remain consistent across all development machines.

Machine-specific credentials should never be committed.

AI configuration that is safe to share belongs in this repository.

---

# tmux

tmux is the persistent workspace.

Every development session should happen inside tmux.

The status line is customized and maintained as part of this repository.

The status bar prefers the Tailscale IP address when available.

---

# Docker

Docker is the standard runtime for local infrastructure.

Examples include:

- PostgreSQL
- Redis
- Mailpit
- MinIO
- local APIs
- future AI services

Containers should be managed with Docker Compose whenever practical.

---

# Repository Layout

```
midgard/
├── AGENTS.md
├── ARCHITECTURE.md
├── README.md
├── bootstrap.sh
├── config/
├── docs/
└── scripts/
```

This repository is the source of truth for Midgard.

---

# Bootstrap Strategy

The system should be bootstrapped using many small scripts rather than one large script.

Example:

```
scripts/
    install-system-tools.sh
    install-docker.sh
    install-mise.sh
    install-node.sh
    install-go.sh
    install-python.sh
    install-claude.sh
    install-codex.sh
    configure-fish.sh
    configure-tmux.sh
```

Scripts should be:

- idempotent
- easy to understand
- safe to rerun

---

# Security

Never commit:

- secrets
- credentials
- SSH private keys
- API tokens
- Tailscale auth keys
- .env files

Authentication should rely on:

- SSH keys
- GitHub authentication
- Claude authentication
- ChatGPT authentication
- Tailscale

---

# Backup and Recovery

A complete Midgard rebuild should require only:

1. Install Ubuntu.
2. Install Git.
3. Clone this repository.
4. Run bootstrap.
5. Restore any private credentials.

Everything else should be recreated automatically.

Recovery should take less than one hour.

---

# Long-Term Roadmap

Potential future additions:

- Windsurf Remote SSH
- PostgreSQL
- Redis
- Mailpit
- Ollama
- Open WebUI
- vLLM
- Local coding models
- GPU acceleration
- Home Kubernetes
- Proxmox migration

These should be added incrementally without increasing operational complexity.

---

# Philosophy

Midgard is not just a server.

It is my primary development workstation.

Every improvement should make the environment:

- easier to rebuild
- easier to understand
- easier to maintain
- easier to use remotely

If a decision makes Midgard more complex without providing significant long-term value, it is probably the wrong decision.

---

# Implemented Bootstrap (2026-09-15)

`bootstrap.sh` runs focused steps in dependency order. Its default is a read-only
dry-run; `--apply` enables installation and deployment. `--only` selects steps
without implicitly installing their dependencies.

Shareable configuration lives in `config/`. Runtime versions are pinned in
`config/mise/config.toml`; fresh-install mise, Yarn, and agent versions live in
`config/versions.sh`. Existing agent installations are retained. APT package
versions and upstream installer scripts are not frozen.

Configuration deployment compares files before writing. Conflicts are preserved
unless `--replace-config` is selected; replacement first makes a private backup.
Claude settings merge existing hooks and permissions. No network identity,
SSH settings, disks, or live tmux sessions are changed by configuration deployment.

Authentication and selection of Fish as the login shell remain manual. See
README.md for rebuild instructions and docs/configuration.md for capture details.
A complete rebuild on a fresh disposable VM remains the recovery acceptance test.
