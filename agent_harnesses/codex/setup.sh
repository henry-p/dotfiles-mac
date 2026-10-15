#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CODEX_SOURCE="${SCRIPT_DIR}/.codex-linked"
TARGET_PATH="${HOME}/.codex"

source "${SCRIPT_DIR}/../../utils/symlinks.sh"

if [ ! -d "${CODEX_SOURCE}" ]; then
  echo "Missing Codex source directory: ${CODEX_SOURCE}" >&2
  exit 1
fi

create_relative_symlink "${CODEX_SOURCE}" "${TARGET_PATH}"

# GUI apps inherit their environment from launchd, not .zshrc.
CODEX_SOURCE="$(cd "${CODEX_SOURCE}" && pwd -P)"
AGENT_LABEL="com.henry.codex-environment"
AGENT_PATH="${HOME}/Library/LaunchAgents/${AGENT_LABEL}.plist"
AGENT_DOMAIN="gui/$(id -u)"

python3 - "${SCRIPT_DIR}" "${CODEX_SOURCE}" "${AGENT_PATH}" <<'PY'
import json
import pathlib
import plistlib
import re
import sys

script_dir, codex_source, agent_path = map(pathlib.Path, sys.argv[1:])
template = script_dir / "launchagents/com.henry.codex-environment.plist"
agent = plistlib.loads(template.read_bytes())
agent["ProgramArguments"][-1] = str(codex_source)
agent_path.parent.mkdir(parents=True, exist_ok=True)
agent_path.write_bytes(plistlib.dumps(agent, sort_keys=False))
agent_path.chmod(0o644)

# Keep the existing marketplace registration consistent with CODEX_HOME.
config_path = codex_source / "config.toml"
if config_path.is_file():
    original = config_path.read_text()
    source = str(codex_source / ".tmp/bundled-marketplaces/openai-bundled")
    updated = re.sub(
        r'(?ms)(^\[marketplaces\.openai-bundled\][^\[]*?^source\s*=\s*)[^\n]*',
        lambda match: match[1] + json.dumps(source),
        original,
        count=1,
    )
    if updated != original:
        config_path.write_text(updated)
PY

plutil -lint "${AGENT_PATH}"
if launchctl print "${AGENT_DOMAIN}/${AGENT_LABEL}" >/dev/null 2>&1; then
  launchctl bootout "${AGENT_DOMAIN}/${AGENT_LABEL}"
fi
launchctl bootstrap "${AGENT_DOMAIN}" "${AGENT_PATH}"
launchctl setenv CODEX_HOME "${CODEX_SOURCE}"
echo "Installed Codex login environment: ${CODEX_SOURCE}"
echo "Fully quit and reopen ChatGPT/Codex to use it."
