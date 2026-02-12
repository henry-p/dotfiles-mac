#!/bin/bash
set -euo pipefail

# iTerm2 preferences setup
# - Back up ~/Library/Preferences/com.googlecode.iterm2.plist into the repo
# - Create a stable symlink in $HOME that you can point iTerm2 at as a custom prefs folder

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/symlinks.sh"

DRY_RUN=false

show_help() {
  cat <<'EOF'
iTerm2 Preferences Setup

USAGE:
  bash terminals/iterm2/setup.sh [--dry-run]

WHAT IT DOES:
  1) Copies ~/Library/Preferences/com.googlecode.iterm2.plist into the dotfiles repo:
       terminals/iterm2/com.googlecode.iterm2.plist
     (backs up an existing repo copy with a timestamp if it would be overwritten)
  2) Creates a symlink in $HOME:
       ~/.iterm2-prefs -> <dotfiles repo>/terminals/iterm2

NEXT STEP (manual in iTerm2):
  Preferences > General > Preferences
    - Enable "Load preferences from a custom folder or URL"
    - Point it at: ~/.iterm2-prefs
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        echo "🔍 Running in DRY RUN mode - no changes will be made"
        shift
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

backup_plist_into_repo() {
  local live_plist="$1"
  local repo_plist="$2"

  if [[ ! -e "$live_plist" ]]; then
    echo "ℹ️  iTerm2 prefs plist not found at: $live_plist"
    echo "    Skipping backup step."
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] ensure_directory \"$(dirname "$repo_plist")\""
  else
    ensure_directory "$(dirname "$repo_plist")"
  fi

  if [[ -e "$repo_plist" ]]; then
    if cmp -s "$live_plist" "$repo_plist"; then
      echo "✅ Repo plist already matches live plist: $repo_plist"
      return 0
    fi

    echo "⚠️  Repo plist differs; creating timestamped backup before overwrite"
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[DRY RUN] backup_with_timestamp $repo_plist"
      echo "[DRY RUN] cp -p \"$live_plist\" \"$repo_plist\""
      return 0
    fi

    backup_with_timestamp "$repo_plist"
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] cp -p \"$live_plist\" \"$repo_plist\""
    return 0
  fi

  echo "📦 Backing up iTerm2 prefs plist into repo"
  cp -p "$live_plist" "$repo_plist"
  echo "✅ Wrote: $repo_plist"
}

main() {
  parse_args "$@"

  local dotfiles_dir
  dotfiles_dir="$(get_dotfiles_dir)"

  local repo_dir="$dotfiles_dir/terminals/iterm2"
  local prefs_link="$HOME/.iterm2-prefs"

  local plist_name="com.googlecode.iterm2.plist"
  local live_plist="$HOME/Library/Preferences/$plist_name"
  local repo_plist="$repo_dir/$plist_name"

  echo "=========================================="
  echo "🧰 Setting up iTerm2 preferences"
  echo "=========================================="
  echo "Dotfiles directory: $dotfiles_dir"
  echo "Repo dir:           $repo_dir"
  echo "Home symlink:       $prefs_link"
  echo "Live plist:         $live_plist"
  echo "Repo plist:         $repo_plist"
  echo ""

  backup_plist_into_repo "$live_plist" "$repo_plist"

  echo ""
  echo "🔗 Ensuring symlink exists for iTerm2 custom prefs folder"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] create_relative_symlink \"$repo_dir\" \"$prefs_link\""
  else
    create_relative_symlink "$repo_dir" "$prefs_link"
  fi

  echo ""
  echo "Next: in iTerm2, set Preferences > General > Preferences >"
  echo "  Load preferences from a custom folder or URL: ~/.iterm2-prefs"
}

main "$@"
