#!/bin/bash

# zsh configuration setup
# Symlinks repo zsh/.zshrc to ~/.zshrc
# Optionally symlinks repo zsh/secrets.zsh to ~/.config/dotfiles/secrets.zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/symlinks.sh"

DOTFILES_DIR="$(get_dotfiles_dir)"
SOURCE_ZSHRC_PATH="$DOTFILES_DIR/zsh/.zshrc"
TARGET_ZSHRC_PATH="$HOME/.zshrc"
SOURCE_SECRETS_PATH="$DOTFILES_DIR/zsh/secrets.zsh"
TARGET_SECRETS_PATH="$HOME/.config/dotfiles/secrets.zsh"
EXAMPLE_SECRETS_PATH="$DOTFILES_DIR/zsh/secrets.example.zsh"

echo "=========================================="
echo "🐚 Setting up zsh configuration"
echo "=========================================="
echo "zshrc source:   $SOURCE_ZSHRC_PATH"
echo "zshrc target:   $TARGET_ZSHRC_PATH"
echo "secrets source: $SOURCE_SECRETS_PATH"
echo "secrets target: $TARGET_SECRETS_PATH"

if [[ ! -e "$SOURCE_ZSHRC_PATH" ]]; then
  if [[ -e "$TARGET_ZSHRC_PATH" || -L "$TARGET_ZSHRC_PATH" ]]; then
    echo "Repo file missing. Moving existing ~/.zshrc into dotfiles repo."
    move_to_repo_and_symlink "$TARGET_ZSHRC_PATH" "$SOURCE_ZSHRC_PATH"
    exit $?
  fi

  echo "Error: No source zshrc found in repo and no existing ~/.zshrc to migrate."
  exit 1
fi

create_relative_symlink "$SOURCE_ZSHRC_PATH" "$TARGET_ZSHRC_PATH"

if [[ -e "$SOURCE_SECRETS_PATH" ]]; then
  chmod 600 "$SOURCE_SECRETS_PATH"
  create_relative_symlink "$SOURCE_SECRETS_PATH" "$TARGET_SECRETS_PATH"
elif [[ -e "$TARGET_SECRETS_PATH" && ! -L "$TARGET_SECRETS_PATH" ]]; then
  echo "Repo secrets file missing. Moving existing ~/.config/dotfiles/secrets.zsh into dotfiles repo."
  move_to_repo_and_symlink "$TARGET_SECRETS_PATH" "$SOURCE_SECRETS_PATH"
  chmod 600 "$SOURCE_SECRETS_PATH"
elif [[ -L "$TARGET_SECRETS_PATH" ]]; then
  echo "ℹ️ ~/.config/dotfiles/secrets.zsh is symlinked elsewhere and repo secrets are missing; leaving unchanged"
else
  cat <<EOF
ℹ️ No zsh secrets file found.
   If you want this repo to manage local shell secrets, copy:
     $EXAMPLE_SECRETS_PATH
   to:
     $SOURCE_SECRETS_PATH
   and re-run this script.
EOF
fi

echo "✅ zsh setup complete"
