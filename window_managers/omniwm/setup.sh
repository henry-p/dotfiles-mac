#!/bin/bash

# Script to set up OmniWM configuration
# Links dotfiles-mac/window_managers/omniwm/settings.toml to $HOME/.config/omniwm/settings.toml

# Change to the script directory
cd "$(dirname "$0")"

# Source the utility functions
source ../../utils/symlinks.sh

# Ensure OmniWM config directory exists before linking the file
mkdir -p "$HOME/.config/omniwm"

# Create the symlink using the utility function
create_symlink "window_managers/omniwm/settings.toml" "$HOME/.config/omniwm/settings.toml"
