#!/bin/bash

# Editor Settings Management Script
# Manages VS Code and Cursor settings via symlinks to keep them version-controlled

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
Editor Settings Management Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --dry-run    Show what would be done without making changes
    -h, --help   Show this help message

DESCRIPTION:
    This script manages VS Code and Cursor settings by creating symlinks
    from the applications' User directories to version-controlled files
    in the dotfiles repository. Cursor inherits VS Code settings and extensions.

    Managed files: settings.json, keybindings.json, locale.json
    Managed directories: snippets/
    Extensions: VS Code extensions are synced to Cursor

    The script will:
    - Move existing live files to the repo if repo copies don't exist
    - Create symlinks from live locations to repo files
    - Backup conflicting files with timestamps
    - Skip files that are already correctly symlinked

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

# Process a single file for an editor
process_file() {
    local editor_name="$1"
    local live_dir="$2"
    local repo_dir="$3"
    local file_name="$4"

    local live_path="$live_dir/$file_name"
    local repo_path="$repo_dir/$file_name"

    echo "Processing $editor_name $file_name..."

    # Check if already correctly symlinked
    if is_symlinked "$live_path" "$repo_path"; then
        log_action "✅ $editor_name $file_name already correctly symlinked"
        return 0
    fi

    # Case 1: Repo file doesn't exist but live file does
    if [[ ! -e "$repo_path" && -e "$live_path" ]]; then
        log_action "📦 Moving $editor_name $file_name from live to repo"
        execute_if_not_dry_run move_to_repo_and_symlink "$live_path" "$repo_path"
        return $?
    fi

    # Case 2: Both exist but differ (or live is not a symlink)
    if [[ -e "$repo_path" && -e "$live_path" && ! -L "$live_path" ]]; then
        log_action "🔄 Backing up existing $editor_name $file_name and creating symlink"
        execute_if_not_dry_run create_relative_symlink "$repo_path" "$live_path"
        return $?
    fi

    # Case 3: Only repo file exists
    if [[ -e "$repo_path" && ! -e "$live_path" ]]; then
        log_action "🔗 Creating symlink for $editor_name $file_name"
        execute_if_not_dry_run create_relative_symlink "$repo_path" "$live_path"
        return $?
    fi

    # Case 4: Neither exists
    if [[ ! -e "$repo_path" && ! -e "$live_path" ]]; then
        log_action "ℹ️  $editor_name $file_name doesn't exist in either location - skipping"
        return 0
    fi

    log_action "⚠️  Unexpected state for $editor_name $file_name - manual review needed"
    return 1
}

# Process all files for a specific editor
process_editor() {
    local editor_name="$1"
    local live_dir="$2"
    local repo_dir="$3"

    echo ""
    echo "==========================================="
    echo "🎨 Processing $editor_name settings"
    echo "==========================================="
    echo "Live directory: $live_dir"
    echo "Repo directory: $repo_dir"
    echo ""

    # Ensure repo directory exists
    if [[ "$DRY_RUN" == "false" ]]; then
        ensure_directory "$repo_dir"
    else
        log_action "Creating directory: $repo_dir"
    fi

    # Process individual files
    for file in "${MANAGED_FILES[@]}"; do
        process_file "$editor_name" "$live_dir" "$repo_dir" "$file"
    done

    # Process directories
    for dir in "${MANAGED_DIRS[@]}"; do
        process_file "$editor_name" "$live_dir" "$repo_dir" "$dir"
    done
}

# Print summary of actions
print_summary() {
    echo ""
    echo "==========================================="
    echo "📋 SUMMARY"
    echo "==========================================="

    if [[ ${#ACTIONS_PERFORMED[@]} -eq 0 ]]; then
        echo "No actions were needed - all settings are already properly configured!"
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
        echo "✅ Editor settings setup completed!"
        echo ""
        echo "Your VS Code and Cursor settings are now symlinked to the dotfiles repo."
        echo "Any changes made in the editors will be automatically reflected in the repo."
        echo ""
        echo "💡 Extension Management:"
        echo "For ongoing extension synchronization, use the standalone sync script:"
        echo "  bash $(dirname "$0")/sync-extensions.sh        # Sync both directions"
        echo "  bash $(dirname "$0")/sync-extensions.sh --help # See all options"
    fi
}

# Main execution
main() {
    parse_args "$@"

    echo "🎨 Editor Settings Management"
    echo "==========================================="
    echo "Dotfiles directory: $DOTFILES_DIR"
    echo ""

    # Check if editors are installed
    if [[ ! -d "$VSCODE_LIVE_DIR" && ! -d "$CURSOR_LIVE_DIR" ]]; then
        echo "⚠️  Neither VS Code nor Cursor appears to be installed."
        echo "   VS Code directory: $VSCODE_LIVE_DIR"
        echo "   Cursor directory: $CURSOR_LIVE_DIR"
        echo ""
        echo "Install one or both editors and run this script again."
        exit 1
    fi

    # Process VS Code if installed
    if [[ -d "$VSCODE_LIVE_DIR" ]]; then
        process_editor "VS Code" "$VSCODE_LIVE_DIR" "$VSCODE_REPO_DIR"
    else
        echo "ℹ️  VS Code not found - skipping"
    fi

    # Process Cursor if installed (inherits VS Code settings)
    if [[ -d "$CURSOR_LIVE_DIR" ]]; then
        process_editor "Cursor" "$CURSOR_LIVE_DIR" "$VSCODE_REPO_DIR"
    else
        echo "ℹ️  Cursor not found - skipping"
    fi

    print_summary

    # Sync extensions after settings are set up
    sync_extensions
}

# Sync extensions using the standalone script
sync_extensions() {
    echo ""
    echo "==========================================="
    echo "🧩 Synchronizing Editor Extensions"
    echo "==========================================="

    local sync_script="$(dirname "$0")/sync-extensions.sh"

    if [[ ! -f "$sync_script" ]]; then
        echo "⚠️  Extension sync script not found: $sync_script"
        echo "Skipping extension synchronization."
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "Using standalone extension sync script with dry-run..."
        bash "$sync_script" --dry-run
    else
        echo "Using standalone extension sync script..."
        bash "$sync_script"
    fi

    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        log_action "✅ Extension synchronization completed successfully"
    else
        log_action "⚠️  Extension synchronization completed with warnings"
    fi

    return $exit_code
}

# Run main function with all arguments
main "$@"
