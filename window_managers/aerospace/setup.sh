#!/bin/bash

# Script to set up aerospace configuration
# Links dotfiles-mac/window_managers/aerospace/.aerospace-linked/.aerospace.toml to $HOME/.aerospace.toml

# Change to the script directory
cd "$(dirname "$0")"

# Source the utility functions
source ../../utils/symlinks.sh

# Link the managed config file from the repo-side linked payload folder
source_path="$(get_dotfiles_dir)/window_managers/aerospace/.aerospace-linked/.aerospace.toml"
target_path="$HOME/.aerospace.toml"

create_relative_symlink "$source_path" "$target_path"
