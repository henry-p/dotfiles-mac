#!/bin/bash

# Utility functions for dotfile management scripts

# Get the dotfiles root directory (parent of scripts directory)
get_dotfiles_dir() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$(dirname "$script_dir")"
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

