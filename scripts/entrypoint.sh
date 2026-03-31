#!/usr/bin/env bash
set -euo pipefail

export HERMES_HOME="${HERMES_HOME:-/data/.hermes}"
export HOME="${HOME:-/data}"
export MESSAGING_CWD="${MESSAGING_CWD:-/data/workspace}"

INIT_MARKER="${HERMES_HOME}/.initialized"
ENV_FILE="${HERMES_HOME}/.env"
CONFIG_FILE="${HERMES_HOME}/config.yaml"

mkdir -p "${HERMES_HOME}" "${HERMES_HOME}/logs" "${HERMES_HOME}/sessions" "${HERMES_HOME}/cron" "${HERMES_HOME}/pairing" "${MESSAGING_CWD}"

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

validate_platforms() {
  local count=0

  if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]]; then
    count=$((count + 1))
  fi

  if [[ -n "${DISCORD_BOT_TOKEN:-}" ]]; then
    count=$((count + 1))
  fi

  if [[ -n "${SLACK_BOT_TOKEN:-}" || -n "${SLACK_APP_TOKEN:-}" ]]; then
    if [[ -z "${SLACK_BOT_TOKEN:-}" || -z "${SLACK_APP_TOKEN:-}" ]]; then
      echo "[bootstrap] ERROR: Slack requires both SLACK_BOT_TOKEN and SLACK_APP_TOKEN." >&2
      exit 1
    fi
    count=$((count + 1))
  fi

  if [[ "$count" -lt 1 ]]; then
    echo "[bootstrap] ERROR: Configure at least one platform: Telegram, Discord, or Slack." >&2
    exit 1
  fi
}

has_valid_provider_config() {
  if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
    return 0
  fi

  if [[ -n "${OPENAI_BASE_URL:-}" && -n "${OPENAI_API_KEY:-}" ]]; then
    return 0
  fi

  if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    return 0
  fi

  return 1
}

append_if_set() {
  local key="$1"
  local val="${!key:-}"
  if [[ -n "$val" ]]; then
    printf '%s=%s\n' "$key" "$val" >> "$ENV_FILE"
  fi
}

if ! has_valid_provider_config; then
  echo "[bootstrap] ERROR: Configure a provider: OPENROUTER_API_KEY, or OPENAI_BASE_URL+OPENAI_API_KEY, or ANTHROPIC_API_KEY." >&2
  exit 1
fi

validate_platforms

echo "[bootstrap] Writing runtime env to ${ENV_FILE}"
{
  echo "# Managed by entrypoint.sh"
  echo "HERMES_HOME=${HERMES_HOME}"
  echo "MESSAGING_CWD=${MESSAGING_CWD}"
} > "$ENV_FILE"

for key in \
  OPENROUTER_API_KEY OPENAI_API_KEY OPENAI_BASE_URL ANTHROPIC_API_KEY LLM_MODEL HERMES_INFERENCE_PROVIDER HERMES_PORTAL_BASE_URL NOUS_INFERENCE_BASE_URL HERMES_NOUS_MIN_KEY_TTL_SECONDS HERMES_DUMP_REQUESTS \
  TELEGRAM_BOT_TOKEN TELEGRAM_ALLOWED_USERS TELEGRAM_ALLOW_ALL_USERS TELEGRAM_HOME_CHANNEL TELEGRAM_HOME_CHANNEL_NAME \
  DISCORD_BOT_TOKEN DISCORD_ALLOWED_USERS DISCORD_ALLOW_ALL_USERS DISCORD_HOME_CHANNEL DISCORD_HOME_CHANNEL_NAME DISCORD_REQUIRE_MENTION DISCORD_FREE_RESPONSE_CHANNELS \
  SLACK_BOT_TOKEN SLACK_APP_TOKEN SLACK_ALLOWED_USERS SLACK_ALLOW_ALL_USERS SLACK_HOME_CHANNEL SLACK_HOME_CHANNEL_NAME WHATSAPP_ENABLED WHATSAPP_ALLOWED_USERS \
  GATEWAY_ALLOW_ALL_USERS \
  FIRECRAWL_API_KEY NOUS_API_KEY BROWSERBASE_API_KEY BROWSERBASE_PROJECT_ID BROWSERBASE_PROXIES BROWSERBASE_ADVANCED_STEALTH BROWSER_SESSION_TIMEOUT BROWSER_INACTIVITY_TIMEOUT FAL_KEY ELEVENLABS_API_KEY VOICE_TOOLS_OPENAI_KEY \
  TINKER_API_KEY WANDB_API_KEY RL_API_URL GITHUB_TOKEN \
  TERMINAL_ENV TERMINAL_BACKEND TERMINAL_DOCKER_IMAGE TERMINAL_SINGULARITY_IMAGE TERMINAL_MODAL_IMAGE TERMINAL_CWD TERMINAL_TIMEOUT TERMINAL_LIFETIME_SECONDS TERMINAL_CONTAINER_CPU TERMINAL_CONTAINER_MEMORY TERMINAL_CONTAINER_DISK TERMINAL_CONTAINER_PERSISTENT TERMINAL_SANDBOX_DIR TERMINAL_SSH_HOST TERMINAL_SSH_USER TERMINAL_SSH_PORT TERMINAL_SSH_KEY SUDO_PASSWORD \
  WEB_TOOLS_DEBUG VISION_TOOLS_DEBUG MOA_TOOLS_DEBUG IMAGE_TOOLS_DEBUG CONTEXT_COMPRESSION_ENABLED CONTEXT_COMPRESSION_THRESHOLD CONTEXT_COMPRESSION_MODEL HERMES_MAX_ITERATIONS HERMES_TOOL_PROGRESS HERMES_TOOL_PROGRESS_MODE
do
  append_if_set "$key"
done

# Bootstrap Gmail MCP credentials from env vars
GMAIL_MCP_DIR="${HERMES_HOME}/gmail-mcp"
if [[ -n "${GMAIL_OAUTH_KEYS_JSON:-}" ]]; then
  mkdir -p "${GMAIL_MCP_DIR}"
  echo "${GMAIL_OAUTH_KEYS_JSON}" > "${GMAIL_MCP_DIR}/gcp-oauth.keys.json"
  echo "[bootstrap] Wrote Gmail OAuth keys"
fi
if [[ -n "${GMAIL_CREDENTIALS_JSON:-}" ]]; then
  mkdir -p "${GMAIL_MCP_DIR}"
  echo "${GMAIL_CREDENTIALS_JSON}" > "${GMAIL_MCP_DIR}/credentials.json"
  echo "[bootstrap] Wrote Gmail credentials"
fi

# Bootstrap gcalcli from Gmail MCP credentials (reuses same OAuth with calendar scope)
GCALCLI_DIR="${HERMES_HOME}/gcalcli"
export XDG_CONFIG_HOME="${HERMES_HOME}"
if [[ -f "${GMAIL_MCP_DIR}/credentials.json" ]]; then
  /opt/venv/bin/python /app/scripts/bootstrap_gcalcli.py "${GMAIL_MCP_DIR}" "${GCALCLI_DIR}" 2>&1 || true
fi

# Find gmail-mcp entry point
GMAIL_MCP_BIN="$(which gmail-mcp 2>/dev/null || node -e "console.log(require.resolve('@shinzolabs/gmail-mcp/dist/index.js'))" 2>/dev/null || echo "")"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[bootstrap] Creating ${CONFIG_FILE}"
  cat > "$CONFIG_FILE" <<EOF
terminal:
  backend: ${TERMINAL_ENV:-${TERMINAL_BACKEND:-local}}
  cwd: ${TERMINAL_CWD:-/data/workspace}
  timeout: ${TERMINAL_TIMEOUT:-180}
compression:
  enabled: true
  threshold: 0.85
EOF
fi

# Ensure MCP servers config is present (update on every boot)
if [[ -f "${GMAIL_MCP_DIR}/credentials.json" && -n "${GMAIL_MCP_BIN}" ]]; then
  if ! grep -q "mcp_servers:" "$CONFIG_FILE" 2>/dev/null; then
    cat >> "$CONFIG_FILE" <<EOF
mcp_servers:
  gmail:
    command: node
    args: ["${GMAIL_MCP_BIN}"]
    env:
      MCP_CONFIG_DIR: "${GMAIL_MCP_DIR}"
    timeout: 120
EOF
    echo "[bootstrap] Added Gmail MCP server to config"
  else
    echo "[bootstrap] MCP servers already configured"
  fi
fi

if [[ ! -f "$INIT_MARKER" ]]; then
  date -u +"%Y-%m-%dT%H:%M:%SZ" > "$INIT_MARKER"
  echo "[bootstrap] First-time initialization completed."
else
  echo "[bootstrap] Existing Hermes data found. Skipping one-time init."
fi

if [[ -z "${TELEGRAM_ALLOWED_USERS:-}${DISCORD_ALLOWED_USERS:-}${SLACK_ALLOWED_USERS:-}" ]]; then
  if ! is_true "${GATEWAY_ALLOW_ALL_USERS:-}" && ! is_true "${TELEGRAM_ALLOW_ALL_USERS:-}" && ! is_true "${DISCORD_ALLOW_ALL_USERS:-}" && ! is_true "${SLACK_ALLOW_ALL_USERS:-}"; then
    echo "[bootstrap] WARNING: No allowlists configured. Gateway defaults to deny-all; use DM pairing or set *_ALLOWED_USERS." >&2
  fi
fi

# Write SOUL.md if provided via env var or bundled
SOUL_FILE="${HERMES_HOME}/SOUL.md"
if [[ -n "${HERMES_SOUL_MD:-}" ]]; then
  echo "${HERMES_SOUL_MD}" > "${SOUL_FILE}"
  echo "[bootstrap] Wrote SOUL.md from env var"
elif [[ ! -f "${SOUL_FILE}" && -f /app/nikhil/SOUL.md ]]; then
  cp /app/nikhil/SOUL.md "${SOUL_FILE}"
  echo "[bootstrap] Copied bundled SOUL.md"
fi

echo "[bootstrap] Starting Hermes gateway..."
exec hermes gateway
