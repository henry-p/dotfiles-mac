#!/bin/bash

# Script to set up aerospace configuration
# Links dotfiles-mac/aerospace/.aerospace.toml to $HOME/.aerospace.toml

# Change to the script directory
cd "$(dirname "$0")"

# Source the utility functions
source ../utils/symlinks.sh

# Create the symlink using the utility function
create_symlink "aerospace/.aerospace.toml" "$HOME/.aerospace.toml"
