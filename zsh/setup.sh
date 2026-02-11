#!/bin/bash

# zsh configuration setup
# Symlinks repo zsh/.zshrc to ~/.zshrc

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/symlinks.sh"

DOTFILES_DIR="$(get_dotfiles_dir)"
SOURCE_PATH="$DOTFILES_DIR/zsh/.zshrc"
TARGET_PATH="$HOME/.zshrc"

echo "=========================================="
echo "🐚 Setting up zsh configuration"
echo "=========================================="
echo "Source: $SOURCE_PATH"
echo "Target: $TARGET_PATH"

if [[ ! -e "$SOURCE_PATH" ]]; then
  if [[ -e "$TARGET_PATH" || -L "$TARGET_PATH" ]]; then
    echo "Repo file missing. Moving existing ~/.zshrc into dotfiles repo."
    move_to_repo_and_symlink "$TARGET_PATH" "$SOURCE_PATH"
    exit $?
  fi

  echo "Error: No source zshrc found in repo and no existing ~/.zshrc to migrate."
  exit 1
fi

create_relative_symlink "$SOURCE_PATH" "$TARGET_PATH"

echo "✅ zsh setup complete"
