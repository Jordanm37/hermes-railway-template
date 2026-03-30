#!/usr/bin/env bash
# Nikhil-specific bootstrap — source this from entrypoint.sh or run standalone
# Writes SOUL.md to Hermes home if NIKHIL_SOUL_MD env var is set

HERMES_HOME="${HERMES_HOME:-/data/.hermes}"
SOUL_FILE="${HERMES_HOME}/SOUL.md"

if [[ -n "${NIKHIL_SOUL_MD:-}" ]]; then
  echo "${NIKHIL_SOUL_MD}" > "${SOUL_FILE}"
  echo "[nikhil-bootstrap] Wrote SOUL.md from env var"
elif [[ ! -f "${SOUL_FILE}" ]]; then
  # Fallback: copy bundled SOUL.md
  if [[ -f /app/nikhil/SOUL.md ]]; then
    cp /app/nikhil/SOUL.md "${SOUL_FILE}"
    echo "[nikhil-bootstrap] Copied bundled SOUL.md"
  fi
fi
