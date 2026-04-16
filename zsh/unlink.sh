#!/bin/bash

# zsh configuration unlink
# Replaces ~/.zshrc and ~/.config/dotfiles/secrets.zsh symlinks with real files copied from the repo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/symlinks.sh"

DOTFILES_DIR="$(get_dotfiles_dir)"
SOURCE_ZSHRC_PATH="$DOTFILES_DIR/zsh/.zshrc"
TARGET_ZSHRC_PATH="$HOME/.zshrc"
SOURCE_SECRETS_PATH="$DOTFILES_DIR/zsh/secrets.zsh"
TARGET_SECRETS_PATH="$HOME/.config/dotfiles/secrets.zsh"

restore_real_file_from_repo() {
  local label="$1"
  local source_path="$2"
  local target_path="$3"
  local file_mode="${4:-}"

  echo ""
  echo "Restoring $label"
  echo "Source: $source_path"
  echo "Target: $target_path"

  if is_symlinked "$target_path" "$source_path"; then
    rm "$target_path"
    ensure_directory "$(dirname "$target_path")"
    cp "$source_path" "$target_path"
    if [[ -n "$file_mode" ]]; then
      chmod "$file_mode" "$target_path"
    fi
    echo "✅ Replaced symlink with real file at $target_path"
    return 0
  fi

  if [[ -L "$target_path" ]]; then
    echo "ℹ️ $target_path is symlinked elsewhere; leaving unchanged"
    return 0
  fi

  if [[ -e "$target_path" ]]; then
    echo "✅ $target_path is already a real file; nothing to do"
    return 0
  fi

  if [[ -e "$source_path" ]]; then
    ensure_directory "$(dirname "$target_path")"
    cp "$source_path" "$target_path"
    if [[ -n "$file_mode" ]]; then
      chmod "$file_mode" "$target_path"
    fi
    echo "✅ Restored $target_path from repo"
  else
    echo "ℹ️ No repo file found for $target_path; nothing to restore"
  fi
}

echo "=========================================="
echo "🔗 Unlinking zsh configuration"
echo "=========================================="
restore_real_file_from_repo "~/.zshrc" "$SOURCE_ZSHRC_PATH" "$TARGET_ZSHRC_PATH"
restore_real_file_from_repo "~/.config/dotfiles/secrets.zsh" "$SOURCE_SECRETS_PATH" "$TARGET_SECRETS_PATH" "600"
