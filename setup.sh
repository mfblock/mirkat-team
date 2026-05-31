#!/usr/bin/env bash
# MirKat|Team — First-run setup
# Run this once to configure the app before starting it.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

GREEN='\033[0;32m'; AMBER='\033[0;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║         MirKat|Team — Setup              ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${RESET}"
echo ""

if [[ -f "$ENV_FILE" ]]; then
  echo -e "${AMBER}An .env file already exists.${RESET}"
  read -rp "Overwrite it? [y/N] " overwrite
  [[ "$overwrite" =~ ^[Yy]$ ]] || { echo "Setup cancelled."; exit 0; }
fi

# ── Step 1 — Your name ─────────────────────────────────────────
echo -e "${CYAN}Step 1 — Who are you?${RESET}"
read -rp "Your first name: " USER_NAME
USER_NAME="${USER_NAME:-User}"

# ── Step 2 — Access token ──────────────────────────────────────
echo ""
echo -e "${CYAN}Step 2 — Access token${RESET}"
echo "This is the password you use to log in. Pick something strong (no spaces)."
read -rp "Access token: " AUTH_TOKEN
while [[ -z "$AUTH_TOKEN" || "$AUTH_TOKEN" == *" "* ]]; do
  echo "Token cannot be empty or contain spaces."
  read -rp "Access token: " AUTH_TOKEN
done
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))" 2>/dev/null || openssl rand -hex 32)

# ── Step 3 — Workspace root ────────────────────────────────────
echo ""
echo -e "${CYAN}Step 3 — Workspace${RESET}"
DEFAULT_WS="$HOME/mirkat-team"
read -rp "Workspace folder [$DEFAULT_WS]: " WORKSPACE
WORKSPACE="${WORKSPACE:-$DEFAULT_WS}"

INBOX_PATH="$WORKSPACE/Owner's Inbox"
ARCHIVE_PATH="$WORKSPACE/Owner's Inbox Archive"
TEAM_PATH_INPUT="$WORKSPACE/_teams/management/inbox"
JOURNAL_PATH="$WORKSPACE/Journal"
NOTES_PATH="$WORKSPACE/_knowledge/inbox"
ROSTER_PATH="$WORKSPACE/Team"

echo -e "  ${DIM}Will create:${RESET}"
echo -e "  ${DIM}  $WORKSPACE/${RESET}"
echo -e "  ${DIM}    Owner's Inbox/   _teams/   Journal/   Team/   _knowledge/${RESET}"

# ── Step 4 — Orchestrator name ────────────────────────────────
echo ""
echo -e "${CYAN}Step 4 — Your orchestrator${RESET}"
echo "The AI assistant in this workspace is called Mirjam."
ORCHESTRATOR_NAME="Mirjam"
echo -e "  ${GREEN}✓ Orchestrator: ${BOLD}Mirjam${RESET}"

# ── Step 5 — Starter team ──────────────────────────────────────
echo ""
echo -e "${CYAN}Step 5 — Starter team${RESET}"
echo "MirKat|Team comes with three built-in agents: Vera (orchestrator),"
echo "Iris (librarian) and Rex (researcher). You can add more later."
echo ""
echo "Do you want to add a custom team member now?"
read -rp "Team member name (or leave blank): " CUSTOM_AGENT_NAME
if [[ -n "$CUSTOM_AGENT_NAME" ]]; then
  read -rp "Their role: " CUSTOM_AGENT_ROLE
fi

# ── Step 5 — Vera / Claude ─────────────────────────────────────
echo ""
echo -e "${CYAN}Step 6 — AI chat provider (optional)${RESET}"
echo "Which AI provider do you want to power the ${ORCHESTRATOR_NAME} chat panel?"
echo ""
echo "  1) Anthropic (Claude Sonnet) — requires API key from console.anthropic.com"
echo "  2) OpenAI (GPT-4o)           — requires API key from platform.openai.com"
echo "  3) LM Studio                 — runs locally on this machine, no key needed"
echo "  4) Skip                      — no AI chat"
echo ""
read -rp "Choice [1/2/3/4]: " AI_CHOICE

ANTHROPIC_API_KEY=""; OPENAI_API_KEY=""; OPENAI_MODEL="gpt-4o"
LM_STUDIO_URL="http://host.docker.internal:1234/v1"; LM_STUDIO_MODEL="local-model"

case "$AI_CHOICE" in
  1)
    read -rp "Anthropic API key: " ANTHROPIC_API_KEY
    ;;
  2)
    read -rp "OpenAI API key: " OPENAI_API_KEY
    read -rp "Model [gpt-4o]: " _model; OPENAI_MODEL="${_model:-gpt-4o}"
    ;;
  3)
    echo -e "  ${DIM}LM Studio must be running on this machine with a model loaded.${RESET}"
    read -rp "LM Studio URL [http://host.docker.internal:1234/v1]: " _url
    LM_STUDIO_URL="${_url:-http://host.docker.internal:1234/v1}"
    read -rp "Model name (as shown in LM Studio) [local-model]: " _model
    LM_STUDIO_MODEL="${_model:-local-model}"
    ;;
  *)
    echo -e "  ${DIM}Skipping AI chat.${RESET}"
    ;;
esac

# ── Step 6 — Email ─────────────────────────────────────────────
echo ""
echo -e "${CYAN}Step 7 — Email sharing (optional)${RESET}"
echo "SMTP settings for the 'Share by email' feature. Leave blank to skip."
read -rp "SMTP host (e.g. smtp.office365.com): " SMTP_HOST
SMTP_PORT=587; SMTP_USER=""; SMTP_PASSWORD=""
if [[ -n "$SMTP_HOST" ]]; then
  read -rp "SMTP port [587]: " _port; SMTP_PORT="${_port:-587}"
  read -rp "SMTP username (your email): " SMTP_USER
  read -rsp "SMTP password: " SMTP_PASSWORD; echo ""
fi

# ── Step 7 — Cloudflare ────────────────────────────────────────
echo ""
echo -e "${CYAN}Step 8 — Ko-fi donation button (optional)${RESET}"
echo "Show a Ko-fi link on the login page so users can support the product."
read -rp "Ko-fi URL (e.g. ko-fi.com/yourname): " KOFI_URL

echo ""
echo -e "${CYAN}Step 9 — Remote access (optional)${RESET}"
echo "How do you want to reach MirKat|Team from outside your local network?"
echo ""
echo "  1) Cloudflare Tunnel  — free, no open ports, works behind NAT"
echo "                          get a token at: one.dash.cloudflare.com → Networks → Tunnels"
echo "  2) Tailscale          — private network, zero config, install Tailscale first"
echo "                          exposes http://localhost:8200 to your Tailscale IP automatically"
echo "  3) Skip               — localhost only for now"
echo ""
read -rp "Choice [1/2/3]: " ACCESS_CHOICE

CF_TOKEN=""
COMPOSE_PROFILES=""
case "$ACCESS_CHOICE" in
  1)
    read -rp "Cloudflare Tunnel token: " CF_TOKEN
    COMPOSE_PROFILES="tunnel"
    ;;
  2)
    echo -e "  ${GREEN}✓ Tailscale selected.${RESET} Make sure Tailscale is running on this machine."
    echo -e "  ${DIM}MirKat|Team will be reachable at your Tailscale IP on port 8200.${RESET}"
    ;;
  *)
    echo -e "  ${DIM}Localhost only. You can add remote access later.${RESET}"
    ;;
esac

# ── Create folder structure ────────────────────────────────────
echo ""
echo -e "${CYAN}Creating workspace…${RESET}"

for DIR in \
  "$INBOX_PATH" \
  "$ARCHIVE_PATH" \
  "$TEAM_PATH_INPUT" \
  "$JOURNAL_PATH" \
  "$NOTES_PATH" \
  "$ROSTER_PATH" \
  "$WORKSPACE/_knowledge" \
  "$WORKSPACE/_projects"; do
  [[ -d "$DIR" ]] || { mkdir -p "$DIR"; echo -e "  ${GREEN}+${RESET} $DIR"; }
done

# ── Write roster.md ────────────────────────────────────────────
TODAY=$(date +%Y-%m-%d)

CUSTOM_ROW=""
if [[ -n "$CUSTOM_AGENT_NAME" ]]; then
  CUSTOM_ROW="| **${CUSTOM_AGENT_NAME}** | ${CUSTOM_AGENT_ROLE:-Specialist} | — | Active |"$'\n'
fi

cat > "$ROSTER_PATH/roster.md" <<ROSTER
# Team roster

| Name | Role | Profile | Status |
|------|------|---------|--------|
| **Vera** | Orchestrator — routes tasks, never does the work directly | vera.md | Active |
| **Iris** | Librarian — catalogues, archives, retrieves knowledge | iris.md | Active |
| **Rex** | Researcher — processes URLs, articles, references | rex.md | Active |
${CUSTOM_ROW}
---
*Last updated: ${TODAY}*
ROSTER

echo -e "  ${GREEN}+${RESET} Team/roster.md"

# ── Write agent profiles ───────────────────────────────────────
cat > "$ROSTER_PATH/vera.md" <<'VERA'
# Vera — Orchestrator

You are Vera, the orchestrator. You route every task to the right team member and never do the work directly.

## Rules
- Always read context before acting
- Route to Iris for anything to store or catalogue
- Route to Rex for any URL or article to read
- Ask one question only when something is unclear
- Finished work goes to Owner's Inbox

## Workspace
Read CLAUDE.md at the start of every session.
VERA

cat > "$ROSTER_PATH/iris.md" <<'IRIS'
# Iris — Librarian

You catalogue, tag, archive, and retrieve knowledge. You keep the team's memory current.

## Rules
- Every agent hands off to you before closing a task
- You decide what to keep — agents don't
- Store knowledge in _knowledge/
- One file per topic, clear naming
IRIS

cat > "$ROSTER_PATH/rex.md" <<'REX'
# Rex — Researcher

You process URLs, articles, and references. You summarise, extract facts, and hand off to Iris.

## Rules
- When given a URL: fetch, read, summarise, extract key facts
- Hand summary to Iris for storage
- Flag anything that needs a decision back to Vera
REX

echo -e "  ${GREEN}+${RESET} Team/vera.md, iris.md, rex.md"

# ── Write welcome file ─────────────────────────────────────────
cat > "$INBOX_PATH/Welcome — Getting started with MirKat|Team.md" <<WELCOME
# Welcome to MirKat|Team, ${USER_NAME}

This is your personal team inbox. Here's how it works.

## Your inbox tabs

- **Owner's** — deliverables from your team land here. Read, archive, or reply.
- **Team** — your outbox. Notes and tasks you send to the team appear here.
- **Archive** — files you've processed and filed away.
- **Journal** — daily log. Press J to write a quick entry.

## Your team

| Agent | What they do |
|-------|-------------|
| **${ORCHESTRATOR_NAME}** | Orchestrator — your AI assistant. Ask anything. |
| **Iris** | Librarian — stores and retrieves knowledge. |
| **Rex** | Researcher — give Rex a URL and it gets read and summarised for you. |
${CUSTOM_AGENT_NAME:+| **${CUSTOM_AGENT_NAME}** | ${CUSTOM_AGENT_ROLE:-Your custom team member.} |}

## Quick actions

- **Click a file** to read it
- **Reply** to send a note back to the team
- **Archive** when you're done with something
- **Vera button** (top right) to chat with your AI orchestrator
- **V** key to open Vera from anywhere

## File naming convention

Agents name files like this: \`Vera — Task summary YYYY-MM-DD.md\`
The name before the dash becomes their badge in your inbox.

---
*Set up on ${TODAY}. Welcome aboard.*
WELCOME

echo -e "  ${GREEN}+${RESET} Owner's Inbox/Welcome file"

# ── Write .env ─────────────────────────────────────────────────
cat > "$ENV_FILE" <<EOF
CLOUDFLARE_TUNNEL_TOKEN="${CF_TOKEN}"
COMPOSE_PROFILES="${COMPOSE_PROFILES}"

AUTH_TOKEN="${AUTH_TOKEN}"
SECRET_KEY="${SECRET_KEY}"

ORCHESTRATOR_NAME="${ORCHESTRATOR_NAME}"
KOFI_URL="${KOFI_URL}"

# AI provider — only one should be set
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY}"
OPENAI_API_KEY="${OPENAI_API_KEY}"
OPENAI_MODEL="${OPENAI_MODEL}"
LM_STUDIO_URL="${LM_STUDIO_URL}"
LM_STUDIO_MODEL="${LM_STUDIO_MODEL}"

SMTP_HOST="${SMTP_HOST}"
SMTP_PORT="${SMTP_PORT}"
SMTP_USER="${SMTP_USER}"
SMTP_PASSWORD="${SMTP_PASSWORD}"
# SMTP_FROM defaults to SMTP_USER — change here if your setup requires a different sender address
SMTP_FROM="${SMTP_USER}"
EOF

echo -e "  ${GREEN}+${RESET} .env"

# ── Update docker-compose volumes ──────────────────────────────
COMPOSE="$SCRIPT_DIR/docker-compose.yml"
python3 - "$COMPOSE" "$INBOX_PATH" "$TEAM_PATH_INPUT" "$ARCHIVE_PATH" "$NOTES_PATH" "$ROSTER_PATH" "$JOURNAL_PATH" <<'PYEOF'
import re, sys
compose_file, inbox, team, archive, notes, roster, journal = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7]
compose = open(compose_file).read()
patterns = [
    (r"- .+:/inbox\b",         f"- {inbox}:/inbox"),
    (r"- .+:/outbox\b",        f"- {team}:/outbox"),
    (r"- .+:/inbox-archive\b", f"- {archive}:/inbox-archive"),
    (r"- .+:/notes-out\b",     f"- {notes}:/notes-out"),
    (r"- .+:/team-data[^\n]*", f"- {roster}:/team-data:ro"),
    (r"- .+:/journal\b",       f"- {journal}:/journal"),
]
for pattern, repl in patterns:
    compose = re.sub(pattern, repl, compose)
open(compose_file, "w").write(compose)
PYEOF

echo -e "  ${GREEN}+${RESET} docker-compose.yml"

# ── Done ───────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}✓ All done, ${USER_NAME}.${RESET}"
echo ""
echo "Start MirKat|Team:"
echo -e "  ${BOLD}docker compose up -d${RESET}"
echo ""
echo "Then open:  http://localhost:8200"
[[ -n "$CF_TOKEN" ]] && echo "Or remotely via your Cloudflare Tunnel hostname."
echo ""
echo -e "${DIM}Your workspace is at: ${WORKSPACE}${RESET}"
echo ""
