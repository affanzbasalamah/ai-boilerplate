#!/usr/bin/env bash
# AI Boilerplate installer for Ubuntu and RHEL 10 (Rocky/Alma 10).
# Usage: curl -fsSL https://ai.salamahsystems.com/install.sh | bash
set -euo pipefail

if [ ! -t 0 ] && [ -t 1 ] && [ -r /dev/tty ]; then
  exec </dev/tty
fi

C_GREEN=$'\033[0;32m'; C_YELLOW=$'\033[0;33m'; C_RED=$'\033[0;31m'; C_BLUE=$'\033[0;34m'; C_RESET=$'\033[0m'
info() { printf "%s[*]%s %s\n" "$C_BLUE" "$C_RESET" "$*"; }
ok()   { printf "%s[+]%s %s\n" "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf "%s[!]%s %s\n" "$C_YELLOW" "$C_RESET" "$*"; }
die()  { printf "%s[x]%s %s\n" "$C_RED" "$C_RESET" "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

confirm() {
  local prompt="$1" reply
  printf "%s [Y/n] " "$prompt"
  read -r reply || reply=""
  case "${reply}" in
    n|N|no|NO|No) return 1 ;;
    *) return 0 ;;
  esac
}

detect_os() {
  [ -r /etc/os-release ] || die "Cannot read /etc/os-release — unsupported OS."
  . /etc/os-release
  OS_ID="${ID:-}"; OS_LIKE="${ID_LIKE:-}"; OS_VER="${VERSION_ID:-}"
  case "$OS_ID $OS_LIKE" in
    *ubuntu*|*debian*)
      PM=apt
      PM_UPDATE="sudo apt-get update -y"
      PM_INSTALL="sudo apt-get install -y"
      ;;
    *rhel*|*rocky*|*alma*|*fedora*|*centos*)
      PM=dnf
      have dnf || die "dnf not found on this RHEL-family system."
      PM_UPDATE="sudo dnf -y makecache"
      PM_INSTALL="sudo dnf install -y"
      ;;
    *)
      die "Unsupported OS: ID=$OS_ID ID_LIKE=$OS_LIKE. Supported: Ubuntu/Debian, RHEL 10/Rocky 10/Alma 10."
      ;;
  esac
  ok "Detected ${PRETTY_NAME:-$OS_ID $OS_VER} — using $PM"
}

install_baseline() {
  info "Refreshing package metadata..."
  eval "$PM_UPDATE" >/dev/null
  if [ "$PM" = "apt" ]; then
    eval "$PM_INSTALL curl ca-certificates git xz-utils" >/dev/null
  else
    eval "$PM_INSTALL curl ca-certificates git xz" >/dev/null
  fi
  ok "Baseline tools ready (curl, git, ca-certificates)."
}

ensure_local_bin_path() {
  case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
  local line='export PATH="$HOME/.local/bin:$PATH"'
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] || continue
    grep -qsF "$line" "$rc" || printf '\n# Added by ai-boilerplate installer\n%s\n' "$line" >> "$rc"
  done
}

install_tailscale() {
  if have tailscale; then ok "Tailscale already installed — skipping."; return; fi
  info "Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
  ok "Tailscale installed. Run \`sudo tailscale up\` to authenticate this machine."
}

install_claude_code() {
  if have claude; then ok "Claude Code already installed — skipping."; ensure_local_bin_path; return; fi
  info "Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash
  ensure_local_bin_path
  have claude || die "Claude Code install reported success but \`claude\` is not on PATH."
  ok "Claude Code installed at $(command -v claude)"
}

install_node() {
  if have node && have npm; then
    local major
    major="$(node -v | sed 's/^v//; s/\..*$//')"
    if [ "$major" -ge 22 ] 2>/dev/null; then
      ok "Node.js $(node -v) already installed (>= 22) — skipping."
      return
    fi
    warn "Node.js $(node -v) is below LTS 22 — reinstalling."
  fi
  info "Installing Node.js 22 LTS..."
  if [ "$PM" = "apt" ]; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - >/dev/null
    eval "$PM_INSTALL nodejs" >/dev/null
  else
    eval "$PM_INSTALL nodejs npm" >/dev/null
  fi
  have node && have npm || die "Node.js install failed."
  ok "Node.js $(node -v), npm $(npm -v) ready."
}

install_codex() {
  if have codex; then ok "Codex already installed — skipping."; return; fi
  info "Installing Codex CLI..."
  sudo npm install -g @openai/codex >/dev/null
  ok "Codex installed. Run \`/codex:setup\` inside Claude Code to authenticate (needs OPENAI_API_KEY or ChatGPT subscription)."
}

install_gemini() {
  if have gemini; then ok "Gemini CLI already installed — skipping."; return; fi
  info "Installing Gemini CLI..."
  sudo npm install -g @google/gemini-cli >/dev/null
  ok "Gemini CLI installed. Run \`gemini\` to authenticate (Google account required)."
}

install_leaf() {
  if have leaf; then ok "Leaf already installed — skipping."; return; fi
  info "Installing Leaf (markdown reader)..."
  curl -fsSL https://raw.githubusercontent.com/RivoLink/leaf/main/scripts/install.sh | sh
  ensure_local_bin_path
  ok "Leaf installed. Use \`leaf <file.md>\` to read markdown in the terminal."
}

claude_plugin_installed() {
  claude plugin list 2>/dev/null | grep -qi "$1"
}

install_rtk() {
  if have rtk; then
    ok "rtk already installed — running \`rtk init -g\` to ensure Claude Code hook is up to date."
  else
    info "Installing rtk (token-optimization CLI proxy)..."
    curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
    ensure_local_bin_path
    have rtk || die "rtk install failed."
  fi
  rtk init -g >/dev/null
  ok "rtk hook injected into Claude Code config."
}

install_marketplace_plugin() {
  local marketplace_repo="$1" install_target="$2" friendly_name="$3"
  if claude_plugin_installed "$friendly_name"; then
    ok "$friendly_name plugin already installed — skipping."
    return
  fi
  info "Installing $friendly_name plugin..."
  if claude plugin marketplace add "$marketplace_repo" >/dev/null 2>&1 \
     && claude plugin install "$install_target" >/dev/null 2>&1; then
    ok "$friendly_name installed via Claude Code CLI."
  else
    warn "\`claude plugin\` CLI form failed for $friendly_name."
    warn "Install manually inside Claude Code: /plugin marketplace add $marketplace_repo && /plugin install $install_target"
  fi
}

install_skill() {
  local repo="$1" name="$2"
  if [ -d "$HOME/.claude/skills/$name" ]; then
    ok "$name skill already present — skipping."
    return
  fi
  info "Installing $name skill from $repo..."
  npx -y skills add "$repo" -a claude-code -g -y >/dev/null
  ok "$name skill installed."
}

print_summary() {
  echo
  printf "%s========== AI BOILERPLATE INSTALL COMPLETE ==========%s\n" "$C_GREEN" "$C_RESET"
  echo "Installed components:"
  have tailscale && echo "  - tailscale ($(tailscale version 2>/dev/null | head -n1))"
  have claude    && echo "  - claude    ($(claude --version 2>/dev/null | head -n1))"
  have codex     && echo "  - codex     ($(codex --version 2>/dev/null | head -n1))"
  have gemini    && echo "  - gemini    ($(gemini --version 2>/dev/null | head -n1))"
  have leaf      && echo "  - leaf      (markdown reader)"
  have node      && echo "  - node $(node -v)  npm $(npm -v)"
  have rtk       && echo "  - rtk hook (auto-rewrites bash commands for token savings)"
  echo
  echo "Next steps:"
  have tailscale && echo "  • sudo tailscale up                    # authenticate this machine to your tailnet"
  have claude    && echo "  • claude                                # launch Claude Code"
  have codex     && echo "  • inside Claude Code: /codex:setup     # authenticate Codex (OPENAI_API_KEY or ChatGPT)"
  have gemini    && echo "  • gemini                                # authenticate Gemini CLI (Google account)"
  have leaf      && echo "  • leaf <file.md>                        # read any markdown file in the terminal"
  have claude    && echo "  • shell rc updated → open a new terminal (or \`source ~/.bashrc\`) so PATH picks up ~/.local/bin"
  echo
  echo "New slash commands available in Claude Code:"
  echo "  Workflow (Waza):  /think  /design  /check  /hunt  /write  /learn  /read  /health"
  echo "  Documents (Kami): one-pagers, slides, research docs (auto-triggered from natural requests)"
  echo "  Codex bridge:     /codex:review  /codex:adversarial-review  /codex:rescue"
  echo "  Compression:      /caveman (and modes: lite/full/ultra)"
  echo "  Token saver:      rtk runs transparently — no command needed"
  printf "%s=====================================================%s\n" "$C_GREEN" "$C_RESET"
}

main() {
  echo
  printf "%sAI Boilerplate installer%s — Ubuntu / RHEL 10 (Rocky 10 / Alma 10)\n" "$C_BLUE" "$C_RESET"
  echo

  detect_os
  install_baseline

  WANT_TAILSCALE=0; WANT_CLAUDE=0; WANT_CODEX=0; WANT_GEMINI=0; WANT_LEAF=0
  confirm "Install Tailscale?"        && WANT_TAILSCALE=1 || warn "Skipping Tailscale."
  confirm "Install Claude Code?"      && WANT_CLAUDE=1    || warn "Skipping Claude Code (plugins/skills will also be skipped)."
  confirm "Install Codex CLI?"        && WANT_CODEX=1     || warn "Skipping Codex."
  confirm "Install Gemini CLI?"       && WANT_GEMINI=1    || warn "Skipping Gemini CLI."
  confirm "Install Leaf (md reader)?" && WANT_LEAF=1      || warn "Skipping Leaf."

  [ "$WANT_TAILSCALE" -eq 1 ] && install_tailscale
  [ "$WANT_CLAUDE"    -eq 1 ] && install_claude_code

  if [ "$WANT_CODEX" -eq 1 ] || [ "$WANT_GEMINI" -eq 1 ] || [ "$WANT_CLAUDE" -eq 1 ]; then
    install_node
  fi

  [ "$WANT_CODEX"  -eq 1 ] && install_codex
  [ "$WANT_GEMINI" -eq 1 ] && install_gemini
  [ "$WANT_LEAF"   -eq 1 ] && install_leaf

  if [ "$WANT_CLAUDE" -eq 1 ]; then
    info "Installing Claude Code plugins..."
    install_rtk
    install_marketplace_plugin "JuliusBrussee/caveman"   "caveman@caveman"     "caveman"
    install_marketplace_plugin "openai/codex-plugin-cc"  "codex@openai-codex"  "codex"

    info "Installing Claude Code skills..."
    install_skill "tw93/Waza" "Waza"
    install_skill "tw93/Kami" "Kami"
  fi

  print_summary
}

main "$@"
