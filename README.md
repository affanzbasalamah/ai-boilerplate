# ai-boilerplate

One-command bootstrap for an AI development workstation on **Ubuntu** or **RHEL 10** (Rocky 10 / Alma 10).

```sh
curl -fsSL https://ai.salamahsystems.com/install.sh | bash
```

The script asks Y/n for each major component, then sets up everything and prints next steps.

## What it installs

| Component | Purpose |
|---|---|
| **Tailscale** | Mesh VPN so you can reach this box from anywhere. |
| **Claude Code** | Primary AI coding harness. |
| **Codex CLI** (`@openai/codex`) | Standalone Codex CLI — used directly and via the Claude Code bridge plugin below. |
| **Gemini CLI** (`@google/gemini-cli`) | Google's Gemini CLI for a third AI perspective on your code. |
| **OpenCode** | AI coding agent from opencode.ai. |
| **Leaf** | Terminal markdown reader — always installed, no prompt. |
| **Node.js 22 LTS** | Auto-installed if you pick Codex, Gemini CLI, Claude Code plugins, or skills. AppStream on RHEL 10; NodeSource on Ubuntu. |

### Claude Code plugins (auto-installed when Claude Code is selected)

| Plugin | What it does |
|---|---|
| [rtk](https://github.com/rtk-ai/rtk) | Transparent CLI proxy — rewrites bash commands to compress output. 60–90% token reduction on common dev commands. |
| [caveman](https://github.com/juliusbrussee/caveman) | Output compression — "why use many token when few token do trick." Modes: lite / full / ultra. |
| [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) | Bridges Codex into Claude Code as a second-opinion reviewer. Adds `/codex:review`, `/codex:adversarial-review`, `/codex:rescue`. |

### Claude Code skills (auto-installed when Claude Code is selected)

| Skill | What it does |
|---|---|
| [Waza](https://github.com/tw93/Waza) | Engineering workflow skills: `/think` `/design` `/check` `/hunt` `/write` `/learn` `/read` `/health`. |
| [Kami](https://github.com/tw93/Kami) | Document design system — one-pagers, slides, research docs, letters, portfolios, resumes. Triggers automatically from natural requests. |

## After it finishes

The summary at the end prints exactly what to do next, but in short:

1. `sudo tailscale up` to authenticate the machine to your tailnet.
2. Open a fresh terminal (so `~/.local/bin` is on `PATH`).
3. `claude` to launch Claude Code.
4. Inside Claude Code: `/codex:setup` to authenticate Codex.
5. Run `gemini` once to authenticate with your Google account.

## Re-running

The script is idempotent — re-run it any time to add components you skipped or to reapply the rtk hook.

## Supported systems

- Ubuntu 22.04 / 24.04
- RHEL 10, Rocky Linux 10, AlmaLinux 10

## Hosting

This script is served from Cloudflare Pages at `ai.salamahsystems.com`, deployed automatically from the `main` branch of this repo.
