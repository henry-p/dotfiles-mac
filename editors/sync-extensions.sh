#!/bin/bash

# Bidirectional Extension Sync Script
# Syncs extensions between VS Code and Cursor in both directions

set -e  # Exit on any error

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/symlinks.sh"

# Configuration
DOTFILES_DIR="$(get_dotfiles_dir)"
VSCODE_REPO_DIR="$DOTFILES_DIR/editors/vscode/User"

# Global flags
DRY_RUN=false
SYNC_DIRECTION="both"  # both, to-cursor, to-vscode

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
            --to-cursor)
                SYNC_DIRECTION="to-cursor"
                shift
                ;;
            --to-vscode)
                SYNC_DIRECTION="to-vscode"
                shift
                ;;
            --both)
                SYNC_DIRECTION="both"
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
Bidirectional Extension Sync Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --dry-run        Show what would be done without making changes
    --to-cursor      Sync extensions from VS Code to Cursor only
    --to-vscode      Sync extensions from Cursor to VS Code only
    --both           Sync extensions in both directions (default)
    -h, --help       Show this help message

DESCRIPTION:
    This script syncs extensions between VS Code and Cursor bidirectionally.
    It will attempt to install missing extensions in both editors and provide
    detailed logging of successes and failures.

    The script:
    - Analyzes extension differences between both editors
    - Installs missing extensions in the target editor(s)
    - Exports the final VS Code extension list to the repo
    - Provides detailed success/failure reporting
    - Handles marketplace compatibility issues gracefully

EXAMPLES:
    $0                    # Sync both directions
    $0 --to-cursor        # Only install VS Code extensions in Cursor
    $0 --to-vscode        # Only install Cursor extensions in VS Code
    $0 --dry-run          # Preview what would be synced
EOF
}

# Check if editors are available
check_editors() {
    local missing_editors=()

    if ! command -v code >/dev/null 2>&1; then
        missing_editors+=("VS Code (command 'code')")
    fi

    if ! command -v cursor >/dev/null 2>&1; then
        missing_editors+=("Cursor (command 'cursor')")
    fi

    if [[ ${#missing_editors[@]} -gt 0 ]]; then
        echo "❌ Missing editor commands:"
        for editor in "${missing_editors[@]}"; do
            echo "  - $editor"
        done
        echo ""
        echo "Please ensure both editors are installed and their CLI commands are available."
        return 1
    fi

    return 0
}

# Sync extensions from source to target
sync_extensions_direction() {
    local source_name="$1"
    local target_name="$2"
    local source_cmd="$3"
    local target_cmd="$4"

    echo "🔄 Syncing from $source_name to $target_name..."
    echo "=========================================="

    # Get extensions lists
    local source_extensions=$(mktemp)
    local target_extensions=$(mktemp)

    $source_cmd --list-extensions | sort > "$source_extensions"
    $target_cmd --list-extensions | sort > "$target_extensions"

    # Find extensions to install
    local missing_extensions=$(mktemp)
    comm -23 "$source_extensions" "$target_extensions" > "$missing_extensions"

    local missing_count=$(wc -l < "$missing_extensions")
    local source_total=$(wc -l < "$source_extensions")
    local target_total=$(wc -l < "$target_extensions")

    echo "📊 Extension Analysis:"
    echo "  $source_name has: $source_total extensions"
    echo "  $target_name has: $target_total extensions"
    echo "  Missing in $target_name: $missing_count extensions"
    echo ""

    if [[ $missing_count -eq 0 ]]; then
        echo "✅ $target_name already has all $source_name extensions"
        rm -f "$source_extensions" "$target_extensions" "$missing_extensions"
        return 0
    fi

    echo "📦 Extensions to install in $target_name:"
    cat "$missing_extensions" | sed 's/^/  - /'
    echo ""

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would install $missing_count extensions in $target_name"
        rm -f "$source_extensions" "$target_extensions" "$missing_extensions"
        return 0
    fi

    echo "🚀 Installing extensions in $target_name..."
    echo ""

    local installed_count=0
    local failed_count=0
    local failed_extensions=()

    while IFS= read -r extension; do
        if [[ -n "$extension" ]]; then
            echo "Installing: $extension"
            if $target_cmd --install-extension "$extension" >/dev/null 2>&1; then
                echo "  ✅ Success"
                ((installed_count++))
            else
                echo "  ❌ Failed"
                ((failed_count++))
                failed_extensions+=("$extension")
            fi
        fi
    done < "$missing_extensions"

    echo ""
    echo "📊 $source_name → $target_name sync summary:"
    echo "  ✅ Successfully installed: $installed_count"
    if [[ $failed_count -gt 0 ]]; then
        echo "  ❌ Failed to install: $failed_count"
        echo ""
        echo "❌ Failed extensions:"
        for ext in "${failed_extensions[@]}"; do
            echo "  - $ext"
        done
    fi
    echo ""

    # Cleanup
    rm -f "$source_extensions" "$target_extensions" "$missing_extensions"

    return 0
}

# Export VS Code extensions to repo
export_extensions_to_repo() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would export VS Code extensions to repo"
        return 0
    fi

    echo "📝 Exporting VS Code extensions to repo..."
    local extensions_file="$VSCODE_REPO_DIR/extensions.txt"

    if export_vscode_extensions "$extensions_file"; then
        echo "✅ Extensions list updated in repo"
    else
        echo "⚠️  Failed to export extensions to repo"
    fi
    echo ""
}

# Main execution
main() {
    parse_args "$@"

    echo "🧩 Bidirectional Extension Sync"
    echo "==========================================="
    echo "Sync direction: $SYNC_DIRECTION"
    echo ""

    # Check if editors are available
    if ! check_editors; then
        exit 1
    fi

    # Perform sync based on direction
    case $SYNC_DIRECTION in
        "to-cursor")
            sync_extensions_direction "VS Code" "Cursor" "code" "cursor"
            ;;
        "to-vscode")
            sync_extensions_direction "Cursor" "VS Code" "cursor" "code"
            ;;
        "both")
            sync_extensions_direction "VS Code" "Cursor" "code" "cursor"
            echo ""
            sync_extensions_direction "Cursor" "VS Code" "cursor" "code"
            ;;
    esac

    # Export final VS Code extensions to repo
    export_extensions_to_repo

    # Final summary
    echo "🎉 Extension sync completed!"
    echo ""
    echo "Final state:"
    echo "  VS Code extensions: $(code --list-extensions | wc -l)"
    echo "  Cursor extensions: $(cursor --list-extensions | wc -l)"

    local shared_count=$(comm -12 <(code --list-extensions | sort) <(cursor --list-extensions | sort) | wc -l)
    echo "  Shared extensions: $shared_count"

    local vscode_only=$(comm -23 <(code --list-extensions | sort) <(cursor --list-extensions | sort) | wc -l)
    local cursor_only=$(comm -13 <(code --list-extensions | sort) <(cursor --list-extensions | sort) | wc -l)

    if [[ $vscode_only -gt 0 ]] || [[ $cursor_only -gt 0 ]]; then
        echo ""
        echo "ℹ️  Remaining differences:"
        if [[ $vscode_only -gt 0 ]]; then
            echo "  VS Code only: $vscode_only extensions"
        fi
        if [[ $cursor_only -gt 0 ]]; then
            echo "  Cursor only: $cursor_only extensions"
        fi
        echo ""
        echo "Note: Some extensions may not be available in both marketplaces."
    else
        echo ""
        echo "🎯 Perfect sync achieved! Both editors have identical extensions."
    fi
}

# Run main function with all arguments
main "$@"
