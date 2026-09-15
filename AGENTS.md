# AGENTS.md

## Mission

This repository bootstraps and documents Midgard, my permanent remote development server.

Before making changes:

1. Read `ARCHITECTURE.md`.
2. Inspect the repository.
3. Check `git status`.
4. Follow existing conventions.
5. Ask before making major infrastructure changes.

## Working Style

Work incrementally.

Do one logical step at a time.

Verify each step before continuing.

Avoid dumping long sequences of commands where failure in an early step invalidates later ones.

## Development Preferences

- Interactive shell: Fish
- Bootstrap scripts: Bash
- Package manager: Yarn
- Runtime manager: mise
- Docker installed from Docker's official repository
- Remote networking uses Tailscale
- Persistent development happens inside tmux.

## Safety

Never commit:

- credentials
- secrets
- private keys
- API tokens
- `.env` contents

Never force-push, merge, delete infrastructure, or perform destructive operations without explicit approval.

## Documentation

The architecture and implementation details live in:

- `ARCHITECTURE.md`
- `docs/`

Keep those documents updated when making significant infrastructure changes.
