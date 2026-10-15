#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# setup-all.sh may be run with sudo for macos/setup.sh. Install this service
# for the original user, never in root's Library or preferences.
if [[ "$EUID" -eq 0 ]]; then
    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != root ]]; then
        exec /usr/bin/sudo -H -u "$SUDO_USER" /bin/bash "$SCRIPT_DIR/setup.sh" "$@"
    fi
    echo "Run this installer as the user who uses Mail, not root." >&2
    exit 1
fi

if [[ "$(uname -s)" != Darwin ]]; then
    echo "This automation requires macOS." >&2
    exit 1
fi

exec python3 "$SCRIPT_DIR/install.py" "$@"
