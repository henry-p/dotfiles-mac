#!/bin/bash

# macOS System Settings for Short Animation Times and Reduced Motion
# This script configures macOS to use shorter animations and reduce motion

# Check if running with sudo privileges
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo privileges"
    echo "Usage: sudo $0"
    exit 1
fi

echo "Configuring macOS for short animation times and reduced motion..."

# Reduce motion and animations (with sudo)
echo "Setting system-wide motion reduction settings..."
defaults write com.apple.universalaccess reduceMotion -bool true
defaults write com.apple.universalaccess reduceTransparency -bool true
echo "System-wide motion reduction settings applied successfully!"

# Dock animations (these work without special permissions)
defaults write com.apple.dock expose-animation-duration -float 0.1
defaults write com.apple.dock autohide-time-modifier -float 0.1
defaults write com.apple.dock springboard-show-duration -float 0.1
defaults write com.apple.dock springboard-hide-duration -float 0.1
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock mru-spaces -bool false

# Finder animations
defaults write com.apple.finder DisableAllAnimations -bool true

# Window animations
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# Disable the "Are you sure you want to open this application?" dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Restart affected applications
echo "Restarting affected applications..."
killall Dock
killall Finder

echo "macOS animation and motion settings configured successfully!"
