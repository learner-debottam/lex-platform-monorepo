#!/usr/bin/env bash
# Validate a Lex V2 bot configuration JSON file against the schema used by
# the Terraform lexv2-bot module.
#
# Usage:
#   ./bot/validate_bot_config.sh --config path/to/bot.json
#   ./bot/validate_bot_config.sh --config path/to/bot.json --schema path/to/schema.json
#
# Exit codes:
#   0 - configuration is valid
#   1 - configuration is invalid (schema validation failed)
#   2 - usage error or missing tools

set -euo pipefail

CONFIG_PATH=""
SCHEMA_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_PATH="$2"
      shift 2
      ;;
    --schema)
      SCHEMA_PATH="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 --config path/to/bot.json [--schema path/to/schema.json]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 --config path/to/bot.json [--schema path/to/schema.json]" >&2
      exit 2
      ;;
  esac
done

if [[ -z "${CONFIG_PATH}" ]]; then
  echo "ERROR: --config path/to/bot.json is required." >&2
  exit 2
fi

if [[ -z "${SCHEMA_PATH}" ]]; then
  # Default to modules/lexv2-bot/schema.json at repo root
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
  SCHEMA_PATH="${REPO_ROOT}/modules/lexv2-bot/schema.json"
fi

if [[ ! -f "${CONFIG_PATH}" ]]; then
  echo "ERROR: Config JSON not found: ${CONFIG_PATH}" >&2
  exit 2
fi

if [[ ! -f "${SCHEMA_PATH}" ]]; then
  echo "ERROR: Schema JSON not found: ${SCHEMA_PATH}" >&2
  exit 2
fi

# Prefer a globally installed ajv CLI if available; otherwise fall back to npx.
run_ajv() {
  local config="$1"
  local schema="$2"

  if command -v ajv >/dev/null 2>&1; then
    ajv validate -s "${schema}" -d "${config}" --spec=draft7
  elif command -v npx >/dev/null 2>&1; then
    npx --yes ajv-cli validate -s "${schema}" -d "${config}" --spec=draft7
  else
    echo "ERROR: Neither 'ajv' nor 'npx' is available on PATH." >&2
    echo "Install Node.js and either:" >&2
    echo "  - npm install -g ajv-cli   # then re-run this script" >&2
    echo "  or rely on: npx ajv-cli    # which this script will use automatically" >&2
    exit 2
  fi
}

if run_ajv "${CONFIG_PATH}" "${SCHEMA_PATH}"; then
  echo "Bot configuration is valid: ${CONFIG_PATH}"
  exit 0
else
  echo "Bot configuration is INVALID: ${CONFIG_PATH}" >&2
  exit 1
fi

