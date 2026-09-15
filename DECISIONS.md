# Architecture Decisions

This document records important architectural and technical decisions made while building Midgard.

The purpose is to preserve **why** decisions were made so they do not have to be rediscovered later.

---

# Decision 001

## Title

Midgard is the Primary Development Environment

## Date

2026-09-15

## Status

Accepted

## Decision

Midgard will become the primary software development environment.

My Mac acts primarily as a client for editing, SSH, and remote access.

Development tools, repositories, tmux sessions, Docker containers, and AI coding agents live on Midgard.

## Why

This provides:

- persistent development sessions
- identical environment from any client
- simplified machine upgrades
- centralized tooling
- easier backup and recovery

---

# Decision 002

## Title

Remote Access Uses Tailscale

## Date

2026-09-15

## Status

Accepted

## Decision

Remote access uses Tailscale.

SSH should use the Tailscale hostname whenever possible.

Public SSH exposure and router port forwarding are avoided.

## Why

Benefits include:

- encrypted networking
- zero port forwarding
- simple multi-device access
- secure remote development
- reduced attack surface

---

# Decision 003

## Title

Language Versions Managed with mise

## Date

2026-09-15

## Status

Accepted

## Decision

Node.js, Go, Python, and future language runtimes are managed with `mise`.

## Why

Benefits include:

- reproducible environments
- easy upgrades
- consistent developer experience
- avoids conflicting package manager installations

---

# Decision 004

## Title

Fish is the Interactive Shell

## Date

2026-09-15

## Status

Accepted

## Decision

Fish is used for interactive work.

Bootstrap and automation scripts continue to use Bash.

## Why

Fish provides a better interactive experience while Bash remains the most portable scripting language.

---

# Decision 005

## Title

tmux is Required

## Date

2026-09-15

## Status

Accepted

## Decision

All remote development should happen inside tmux.

## Why

Benefits include:

- persistent sessions
- disconnect recovery
- multi-client access
- long-running tasks
- consistent workspace

---

# Decision 006

## Title

Docker is the Standard Container Runtime

## Date

2026-09-15

## Status

Accepted

## Decision

Docker Engine installed from Docker's official repository is the standard container runtime.

Docker Compose is preferred for local infrastructure.

## Why

Docker is widely supported and integrates well with existing tooling.

---

# Decision 007

## Title

AI Development Uses Multiple Coding Agents

## Date

2026-09-15

## Status

Accepted

## Decision

Midgard supports both Claude Code and OpenAI Codex.

Each tool should be configured consistently.

## Why

Different coding agents have different strengths.

Using both provides flexibility while avoiding dependence on a single tool.

---

# Decision 008

## Title

Repository as Source of Truth

## Date

2026-09-15

## Status

Accepted

## Decision

This repository documents and automates the complete Midgard environment.

Configuration should live here whenever it can safely be shared.

Secrets remain outside the repository.

## Why

A complete rebuild should require only:

1. Install Ubuntu.
2. Install Git.
3. Clone this repository.
4. Run bootstrap.
5. Restore credentials.

Everything else should be recreated automatically.

---

# Decision 009

## Title

Incremental Automation

## Date

2026-09-15

## Status

Accepted

## Decision

Automation should consist of many small, focused, idempotent scripts rather than one large bootstrap script.

## Why

Small scripts are:

- easier to understand
- easier to test
- easier to debug
- easier to rerun
- easier to replace

---

# Future Decisions

Future architecture decisions should be added to this document rather than modifying historical entries.

If a decision changes, create a new decision explaining why the previous decision was replaced.

Do not rewrite history.

The goal is to preserve the evolution of Midgard over time.
