#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SOURCE="${SCRIPT_DIR}/config.toml"
TARGET_DIR="${HOME}/.codex"
TARGET_PATH="${TARGET_DIR}/config.toml"

mkdir -p "${TARGET_DIR}"

if [ -e "${TARGET_PATH}" ] || [ -L "${TARGET_PATH}" ]; then
  rm -f "${TARGET_PATH}"
fi

ln -s "${CONFIG_SOURCE}" "${TARGET_PATH}"

echo "Created symlink: ${TARGET_PATH} -> ${CONFIG_SOURCE}"
