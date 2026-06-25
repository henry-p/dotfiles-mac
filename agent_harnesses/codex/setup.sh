#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_SOURCE="${SCRIPT_DIR}/.codex-linked"
TARGET_PATH="${HOME}/.codex"

source "${SCRIPT_DIR}/../../utils/symlinks.sh"

if [ ! -d "${CODEX_SOURCE}" ]; then
  echo "Missing Codex source directory: ${CODEX_SOURCE}" >&2
  exit 1
fi

create_relative_symlink "${CODEX_SOURCE}" "${TARGET_PATH}"
