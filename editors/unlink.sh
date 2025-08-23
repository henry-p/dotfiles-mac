#!/bin/bash

# Editor Settings Unlink Script
# Removes symlinks and restores real files from the repo to the app's User folders

set -e  # Exit on any error

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/symlinks.sh"

# Configuration
DOTFILES_DIR="$(get_dotfiles_dir)"
VSCODE_LIVE_DIR="$HOME/Library/Application Support/Code/User"
CURSOR_LIVE_DIR="$HOME/Library/Application Support/Cursor/User"
VSCODE_REPO_DIR="$DOTFILES_DIR/editors/vscode/User"
# Cursor inherits VS Code settings (no separate repo directory)

# Files to manage
MANAGED_FILES=("settings.json" "keybindings.json" "locale.json")
MANAGED_DIRS=("snippets")

# Global flags
DRY_RUN=false
ACTIONS_PERFORMED=()

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                echo "🔍 Running in DRY RUN mode - no changes will be made"
                echo ""
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

# Show help message
show_help() {
    cat << EOF
Editor Settings Unlink Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --dry-run    Show what would be done without making changes
    -h, --help   Show this help message

DESCRIPTION:
    This script removes symlinks created by setup.sh and restores
    real files from the dotfiles repository to the applications' User directories.

    The script will:
    - Remove symlinks pointing to the dotfiles repo
    - Copy files from the repo back to the live locations
    - Backup any conflicting files with timestamps
    - Skip files that are already real files (not symlinks)

    This is useful for:
    - Temporarily disconnecting from version control
    - Troubleshooting symlink issues
    - Preparing for a different dotfiles management approach

PATHS:
    VS Code Live:  ~/Library/Application Support/Code/User
    Cursor Live:   ~/Library/Application Support/Cursor/User
    Repo:          $DOTFILES_DIR/editors/vscode/User (shared by both editors)
EOF
}

# Log an action (for dry run or real execution)
log_action() {
    local action="$1"
    ACTIONS_PERFORMED+=("$action")
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] $action"
    else
        echo "$action"
    fi
}

# Execute a command (skip in dry run mode)
execute_if_not_dry_run() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    else
        "$@"
    fi
}

# Restore a single file for an editor
restore_file() {
    local editor_name="$1"
    local live_dir="$2"
    local repo_dir="$3"
    local file_name="$4"

    local live_path="$live_dir/$file_name"
    local repo_path="$repo_dir/$file_name"

    echo "Processing $editor_name $file_name..."

    # Check if it's a symlink pointing to our repo
    if is_symlinked "$live_path" "$repo_path"; then
        if [[ -e "$repo_path" ]]; then
            log_action "🔄 Replacing symlink with real file for $editor_name $file_name"
            if [[ "$DRY_RUN" == "false" ]]; then
                if [[ -L "$live_path" ]]; then
                    rm "$live_path"  # Symlinks can always be removed with rm
                fi
            fi
            execute_if_not_dry_run cp -r "$repo_path" "$live_path"
        else
            log_action "⚠️  Symlink exists but repo file missing for $editor_name $file_name - removing symlink"
            if [[ "$DRY_RUN" == "false" ]]; then
                if [[ -L "$live_path" ]]; then
                    rm "$live_path"  # Symlinks can always be removed with rm
                fi
            fi
        fi
        return $?
    fi

    # Check if it's a symlink pointing elsewhere
    if [[ -L "$live_path" ]]; then
        local current_target="$(readlink "$live_path")"
        log_action "ℹ️  $editor_name $file_name is symlinked to different target: $current_target - skipping"
        return 0
    fi

    # Check if it's already a real file
    if [[ -f "$live_path" || -d "$live_path" ]]; then
        log_action "✅ $editor_name $file_name is already a real file - no action needed"
        return 0
    fi

    # File doesn't exist in live location but exists in repo
    if [[ ! -e "$live_path" && -e "$repo_path" ]]; then
        log_action "📋 Copying $editor_name $file_name from repo to live location"
        execute_if_not_dry_run ensure_directory "$live_dir"
        execute_if_not_dry_run cp -r "$repo_path" "$live_path"
        return $?
    fi

    # Neither exists
    if [[ ! -e "$live_path" && ! -e "$repo_path" ]]; then
        log_action "ℹ️  $editor_name $file_name doesn't exist in either location - skipping"
        return 0
    fi

    log_action "⚠️  Unexpected state for $editor_name $file_name - manual review needed"
    return 1
}

# Restore all files for a specific editor
restore_editor() {
    local editor_name="$1"
    local live_dir="$2"
    local repo_dir="$3"

    echo ""
    echo "==========================================="
    echo "🔗 Unlinking $editor_name settings"
    echo "==========================================="
    echo "Live directory: $live_dir"
    echo "Repo directory: $repo_dir"
    echo ""

    # Check if repo directory exists
    if [[ ! -d "$repo_dir" ]]; then
        echo "ℹ️  No repo directory found for $editor_name - skipping"
        return 0
    fi

    # Ensure live directory exists
    if [[ "$DRY_RUN" == "false" ]]; then
        ensure_directory "$live_dir"
    else
        log_action "Creating directory: $live_dir"
    fi

    # Process individual files
    for file in "${MANAGED_FILES[@]}"; do
        restore_file "$editor_name" "$live_dir" "$repo_dir" "$file"
    done

    # Process directories
    for dir in "${MANAGED_DIRS[@]}"; do
        restore_file "$editor_name" "$live_dir" "$repo_dir" "$dir"
    done
}

# Print summary of actions
print_summary() {
    echo ""
    echo "==========================================="
    echo "📋 SUMMARY"
    echo "==========================================="

    if [[ ${#ACTIONS_PERFORMED[@]} -eq 0 ]]; then
        echo "No actions were needed - no symlinks found to remove!"
    else
        echo "Actions performed:"
        for action in "${ACTIONS_PERFORMED[@]}"; do
            echo "  $action"
        done
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo "This was a dry run. To apply these changes, run:"
        echo "  bash $0"
    else
        echo ""
        echo "✅ Editor settings unlink completed!"
        echo ""
        echo "Your editor settings are now real files, no longer symlinked to the repo."
        echo "To re-enable symlink management, run:"
        echo "  bash $(dirname "$0")/setup.sh"
    fi
}

# Main execution
main() {
    parse_args "$@"

    echo "🔗 Editor Settings Unlink"
    echo "==========================================="
    echo "Dotfiles directory: $DOTFILES_DIR"
    echo ""

    # Process VS Code if live directory exists or repo has files
    if [[ -d "$VSCODE_LIVE_DIR" || -d "$VSCODE_REPO_DIR" ]]; then
        restore_editor "VS Code" "$VSCODE_LIVE_DIR" "$VSCODE_REPO_DIR"
    else
        echo "ℹ️  No VS Code installation or repo files found - skipping"
    fi

    # Process Cursor if live directory exists or repo has files (inherits VS Code settings)
    if [[ -d "$CURSOR_LIVE_DIR" || -d "$VSCODE_REPO_DIR" ]]; then
        restore_editor "Cursor" "$CURSOR_LIVE_DIR" "$VSCODE_REPO_DIR"
    else
        echo "ℹ️  No Cursor installation or repo files found - skipping"
    fi

    print_summary
}

# Run main function with all arguments
main "$@"
