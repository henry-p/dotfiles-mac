#!/bin/bash

# zsh configuration unlink
# Replaces ~/.zshrc symlink with a real file copied from the repo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/symlinks.sh"

DOTFILES_DIR="$(get_dotfiles_dir)"
SOURCE_PATH="$DOTFILES_DIR/zsh/.zshrc"
TARGET_PATH="$HOME/.zshrc"

echo "=========================================="
echo "🔗 Unlinking zsh configuration"
echo "=========================================="
echo "Source: $SOURCE_PATH"
echo "Target: $TARGET_PATH"

if is_symlinked "$TARGET_PATH" "$SOURCE_PATH"; then
  rm "$TARGET_PATH"
  cp "$SOURCE_PATH" "$TARGET_PATH"
  echo "✅ Replaced symlink with real file at ~/.zshrc"
  exit 0
fi

if [[ -L "$TARGET_PATH" ]]; then
  echo "ℹ️ ~/.zshrc is symlinked elsewhere; leaving unchanged"
  exit 0
fi

if [[ -e "$TARGET_PATH" ]]; then
  echo "✅ ~/.zshrc is already a real file; nothing to do"
  exit 0
fi

if [[ -e "$SOURCE_PATH" ]]; then
  cp "$SOURCE_PATH" "$TARGET_PATH"
  echo "✅ Restored ~/.zshrc from repo"
else
  echo "ℹ️ No ~/.zshrc found in repo; nothing to restore"
fi
