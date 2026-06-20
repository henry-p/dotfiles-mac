#!/bin/bash

# Script to set up OmniWM configuration
# Links dotfiles-mac/window_managers/omniwm to $HOME/.config/omniwm

# Change to the script directory
cd "$(dirname "$0")"

# Source the utility functions
source ../../utils/symlinks.sh

# Link the whole config directory so OmniWM GUI saves rewrite files inside the repo
source_path="$(get_dotfiles_dir)/window_managers/omniwm"
target_path="$HOME/.config/omniwm"

create_relative_symlink "$source_path" "$target_path"
