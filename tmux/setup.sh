#!/bin/bash

# Script to set up tmux configuration
# Links dotfiles-mac/tmux/.tmux.conf to $HOME/.tmux.conf

# Change to the script directory
cd "$(dirname "$0")"

# Source the utility functions
source ../utils/symlinks.sh

# Create the symlink using the utility function
create_symlink "tmux/.tmux.conf" "$HOME/.tmux.conf"

