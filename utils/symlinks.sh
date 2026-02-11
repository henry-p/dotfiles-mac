#!/bin/bash

# Utility functions for dotfile management scripts

# Get the dotfiles root directory.
# Priority:
#   1) DOTFILES_REPO env var (if set)
#   2) Parent of the repo's utility scripts directory (auto-detected)
get_dotfiles_dir() {
    if [[ -n "${DOTFILES_REPO:-}" ]]; then
        echo "$DOTFILES_REPO"
        return 0
    fi

    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$(dirname "$script_dir")"
}

# Ensure a directory exists, creating it if necessary
# Usage: ensure_directory <path>
ensure_directory() {
    local dir_path="$1"

    if [[ ! -d "$dir_path" ]]; then
        echo "Creating directory: $dir_path"
        mkdir -p "$dir_path"
        return $?
    fi
    return 0
}

# Check if a path is already a symlink pointing to the expected target
# Usage: is_symlinked <path> <expected_target>
# Returns: 0 if correctly symlinked, 1 otherwise
is_symlinked() {
    local path="$1"
    local expected_target="$2"

    if [[ -L "$path" ]]; then
        local current_target="$(readlink "$path")"
        if [[ "$current_target" == "$expected_target" ]]; then
            return 0
        fi
    fi
    return 1
}

# Create a timestamped backup of a file or directory
# Usage: backup_with_timestamp <path>
backup_with_timestamp() {
    local path="$1"

    if [[ ! -e "$path" ]]; then
        return 0  # Nothing to backup
    fi

    local timestamp="$(date +%Y%m%d_%H%M%S)"
    local backup_path="${path}.backup_${timestamp}"

    echo "Creating backup: $backup_path"
    if cp -r "$path" "$backup_path"; then
        echo "Backup created successfully: $backup_path"
        return 0
    else
        echo "Error: Failed to create backup"
        return 1
    fi
}

# Create a relative symlink from target to source
# Usage: create_relative_symlink <source_path> <target_path>
create_relative_symlink() {
    local source_path="$1"
    local target_path="$2"

    # Ensure the target directory exists
    local target_dir="$(dirname "$target_path")"
    ensure_directory "$target_dir" || return 1

    # Check if already correctly symlinked
    if is_symlinked "$target_path" "$source_path"; then
        echo "Already correctly symlinked: $target_path -> $source_path"
        return 0
    fi

    # Handle existing file/symlink
    if [[ -e "$target_path" || -L "$target_path" ]]; then
        backup_with_timestamp "$target_path" || return 1
        if [[ -d "$target_path" && ! -L "$target_path" ]]; then
            rm -rf "$target_path"
        else
            rm "$target_path"
        fi
    fi

    # Create the symlink
    echo "Creating symlink: $target_path -> $source_path"
    if ln -s "$source_path" "$target_path"; then
        echo "Successfully created symlink"
        return 0
    else
        echo "Error: Failed to create symlink"
        return 1
    fi
}

# Move a file/directory from live location to repo and create symlink back
# Usage: move_to_repo_and_symlink <live_path> <repo_path>
move_to_repo_and_symlink() {
    local live_path="$1"
    local repo_path="$2"

    if [[ ! -e "$live_path" ]]; then
        echo "No existing file to move: $live_path"
        return 0
    fi

    # Ensure repo directory exists
    local repo_dir="$(dirname "$repo_path")"
    ensure_directory "$repo_dir" || return 1

    # Move the file to repo
    echo "Moving $live_path to $repo_path"
    if mv "$live_path" "$repo_path"; then
        echo "Successfully moved to repo"
        # Create symlink back
        create_relative_symlink "$repo_path" "$live_path"
        return $?
    else
        echo "Error: Failed to move file to repo"
        return 1
    fi
}

# Export VS Code extensions to a file in the repo
# Usage: export_vscode_extensions <repo_extensions_file>
export_vscode_extensions() {
    local extensions_file="$1"

    echo "Exporting VS Code extensions to: $extensions_file"

    # Ensure the directory exists
    local extensions_dir="$(dirname "$extensions_file")"
    ensure_directory "$extensions_dir" || return 1

    # Export extensions list
    if command -v code >/dev/null 2>&1; then
        code --list-extensions > "$extensions_file"
        echo "Successfully exported $(wc -l < "$extensions_file") VS Code extensions"
        return 0
    else
        echo "Error: VS Code command 'code' not found"
        return 1
    fi
}

# Sync extensions from VS Code to Cursor
# Usage: sync_extensions_to_cursor [--dry-run]
sync_extensions_to_cursor() {
    local dry_run=false

    # Parse arguments
    if [[ "$1" == "--dry-run" ]]; then
        dry_run=true
        echo "🔍 DRY RUN: Extension sync preview"
    fi

    # Check if both editors are available
    if ! command -v code >/dev/null 2>&1; then
        echo "Error: VS Code command 'code' not found"
        return 1
    fi

    if ! command -v cursor >/dev/null 2>&1; then
        echo "Error: Cursor command 'cursor' not found"
        return 1
    fi

    echo "🔄 Analyzing extension differences..."

    # Get extensions lists
    local vscode_extensions=$(mktemp)
    local cursor_extensions=$(mktemp)

    code --list-extensions | sort > "$vscode_extensions"
    cursor --list-extensions | sort > "$cursor_extensions"

    # Find extensions to install (in VS Code but not in Cursor)
    local missing_in_cursor=$(mktemp)
    comm -23 "$vscode_extensions" "$cursor_extensions" > "$missing_in_cursor"

    local missing_count=$(wc -l < "$missing_in_cursor")

    if [[ $missing_count -eq 0 ]]; then
        echo "✅ Cursor already has all VS Code extensions"
        rm -f "$vscode_extensions" "$cursor_extensions" "$missing_in_cursor"
        return 0
    fi

    echo "📦 Found $missing_count extensions to install in Cursor:"
    cat "$missing_in_cursor" | sed 's/^/  - /'

    if [[ "$dry_run" == "true" ]]; then
        echo ""
        echo "[DRY RUN] Would install these extensions in Cursor"
        rm -f "$vscode_extensions" "$cursor_extensions" "$missing_in_cursor"
        return 0
    fi

    echo ""
    echo "🚀 Installing missing extensions in Cursor..."

    local installed_count=0
    local failed_count=0

    while IFS= read -r extension; do
        if [[ -n "$extension" ]]; then
            echo "Installing: $extension"
            if cursor --install-extension "$extension" >/dev/null 2>&1; then
                echo "  ✅ Success"
                ((installed_count++))
            else
                echo "  ❌ Failed"
                ((failed_count++))
            fi
        fi
    done < "$missing_in_cursor"

    echo ""
    echo "📊 Extension sync summary:"
    echo "  ✅ Successfully installed: $installed_count"
    if [[ $failed_count -gt 0 ]]; then
        echo "  ❌ Failed to install: $failed_count"
    fi

    # Cleanup
    rm -f "$vscode_extensions" "$cursor_extensions" "$missing_in_cursor"

    if [[ $failed_count -eq 0 ]]; then
        echo "🎉 All VS Code extensions are now available in Cursor!"
        return 0
    else
        echo "⚠️  Some extensions failed to install"
        return 1
    fi
}

# Create a symlink from source to target
# Usage: create_symlink <source_relative_path> <target_path>
create_symlink() {
    local source_relative_path="$1"
    local target_path="$2"

    local dotfiles_dir="$(get_dotfiles_dir)"
    local source_path="$dotfiles_dir/$source_relative_path"

    echo "Creating symlink for: $source_relative_path"

    # Check if source file exists
    if [[ ! -f "$source_path" ]]; then
        echo "Error: Source file does not exist: $source_path"
        return 1
    fi

    # Remove existing target if it exists (file or symlink)
    if [[ -e "$target_path" ]]; then
        echo "Warning: Target already exists: $target_path"
        read -p "Do you want to remove it and create a new symlink? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Removing existing file/symlink: $target_path"
            rm "$target_path"
        else
            echo "Skipping symlink creation for: $source_relative_path"
            return 0
        fi
    fi

    # Create the symlink
    ln -s "$source_path" "$target_path"

    if [[ $? -eq 0 ]]; then
        echo "Successfully created symlink: $target_path -> $source_path"
        return 0
    else
        echo "Error: Failed to create symlink"
        return 1
    fi
}
