# Configuration capture and deployment

Captured from the working Midgard server on 2026-09-15.

| Repository source | Destination | Capture details |
| --- | --- | --- |
| `config/tmux/tmux.conf` | `~/.tmux.conf` | Exact copy |
| Remaining `config/tmux/` files | `~/.config/tmux/` | Exact helpers, palettes, and cobalt2 selection; modes preserved |
| `config/fish/config.fish` | `~/.config/fish/config.fish` | Replaces the hardcoded username with `$HOME`, adds local binaries to PATH, guards mise activation |
| `config/mise/config.toml` | `~/.config/mise/config.toml` | Pins the installed versions instead of `latest`, `lts`, and `3.13` |
| `config/claude/statusline.sh` | `~/.claude/statusline.sh` | Exact copy; executable |
| `config/claude/hooks/confirm-push-merge.sh` | `~/.claude/hooks/confirm-push-merge.sh` | Exact copy; executable |
| `config/claude/settings.json` | `~/.claude/settings.json` | Existing UI/statusline preferences, plus hook registration |

Fish universal variables are deliberately excluded: `fish_variables` is shell-managed state. The captured startup file provides mise activation; existing local universal variables remain untouched. Codex account/configuration state and Claude project/runtime directories are not copied.

## Comparing and adopting changes

Compare only reviewed, shareable files; do not paste authentication files into logs. For example:

```sh
diff -u ~/.config/fish/config.fish config/fish/config.fish
```

A content or permission difference is preserved unless `--replace-config` is explicitly selected. Applying that option backs up the original before an atomic file replacement. Configuration directories must not be symlinks. File permissions are taken from the repository sources; local backup files are restricted to the owner.

Claude settings use a recursive merge. Existing arrays (including permission rules and hooks) are retained and missing entries are appended; unrelated keys survive. Repository scalar values take precedence only during explicit replacement. The helper never prints settings contents. The original settings file is backed up before a merge that changes it.

## Claude push/merge confirmation

At capture time, the executable confirmation hook existed, but the user settings did not register it. The repository adds a `PreToolUse` hook for `Bash` pointing at that script. Capturing the configuration does not activate it on the running server.

After inspecting the repository settings and hook, preview adoption with:

```sh
bash bootstrap.sh --dry-run --only dotfiles --replace-config
```

Apply the same scoped command with `--apply` when ready, then inspect Claude's hooks in a new session. Existing permissions and other hooks survive the merge.

The preserved script asks for confirmation for recognized `git push`, `git merge`, `gh pr merge`, and merge API commands. It depends on `jq` (included in base packages). It intentionally falls back to normal Claude permissions when input cannot be parsed or `jq` is unavailable. Its regex is not a shell parser and cannot guarantee detection through arbitrary aliases, functions, or indirect scripts. It never grants approval; do not treat it as a replacement for the explicit approval rules in AGENTS.md.

## Installation choices

Base packages and GitHub CLI come from Ubuntu. Docker and Tailscale use their official APT repositories. Existing vendor source files are retained rather than rewritten. Conflicting Docker packages stop the step without removing anything.

mise and fresh agent installs use downloaded vendor installers as the login user, without sudo. Installer scripts are fetched at apply time and may evolve; their version arguments pin tool versions, not the installer code. Existing mise/agent commands are retained to avoid migration of the working installations. If the Codex installer detects another Codex installation (for example an npm global), it appends a marked PATH block to `~/.bashrc`; on a fresh host with `~/.local/bin` already on PATH it leaves shell profiles alone. The Claude installer removes an npm-installed Claude Code during its own migration. Corepack comes with the pinned Node 24 distribution; Yarn is selected with Corepack without creating a JavaScript project in this repository.
