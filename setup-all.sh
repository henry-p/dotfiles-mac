#!/bin/bash

# Main script to set up all dotfiles
# This script calls all individual setup scripts in order

set -e  # Exit on any error

# Change to the directory where this script is located
cd "$(dirname "$0")"

echo "=========================================="
echo "Starting dotfile setup process..."
echo "=========================================="

# ==========================================
# SYSTEM CONFIGURATIONS
# ==========================================
echo ""
echo "🖥️  Setting up system configurations..."
echo "=========================================="

# macOS system settings
echo "🍎 Setting up macOS system settings..."
./macos/setup.sh

# ==========================================
# WINDOW MANAGERS
# ==========================================
echo ""
echo "🔲 Setting up window manager configurations..."
echo "=========================================="

# Aerospace window manager
echo "📱 Setting up Aerospace configuration..."
./aerospace/setup.sh

# ==========================================
# TERMINAL CONFIGURATIONS
# ==========================================
echo ""
echo "🧰 Setting up terminal configurations..."
echo "=========================================="

# tmux
echo "🧩 Setting up tmux configuration..."
./tmux/setup.sh

# zsh
echo "🐚 Setting up zsh configuration..."
./zsh/setup.sh

# ==========================================
# EDITOR CONFIGURATIONS
# ==========================================
echo ""
echo "🎨 Setting up editor configurations..."
echo "=========================================="

# Editor settings (VS Code & Cursor)
echo "⚙️  Setting up editor settings..."
./editors/setup.sh

# ==========================================
# CODING ASSISTANTS
# ==========================================
echo ""
echo "🤖 Setting up coding assistant configurations..."
echo "=========================================="

# Codex configuration
echo "💡 Setting up Codex configuration..."
./coding_assistants/codex/setup.sh

# ==========================================
# COMPLETION
# ==========================================
echo ""
echo "✅ Dotfile setup completed successfully!"
echo "=========================================="
echo "All configurations have been set up in their appropriate locations."
echo ""
echo "Note: You may need to restart your applications or reload your shell"
echo "for some changes to take effect."
