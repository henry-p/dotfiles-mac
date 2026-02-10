# macOS Dotfiles

A comprehensive dotfiles repository for macOS that manages system configurations, window manager settings, and editor configurations through symlinks.

## Overview

This repository provides automated setup scripts for:
- **macOS System Settings**: Animation timings, motion reduction, and system preferences
- **Aerospace Window Manager**: Tiling window manager configuration
- **tmux**: Terminal multiplexer configuration
- **Editor Settings**: VS Code and Cursor settings managed via symlinks

## Quick Start

```bash
# Clone the repository
git clone <your-repo-url> ~/coding/dotfiles-mac
cd ~/coding/dotfiles-mac

# Run complete setup
bash setup-all.sh

# Or run individual components
bash macos/setup.sh     # macOS system settings only
bash aerospace/setup.sh # Aerospace window manager
bash tmux/setup.sh      # tmux configuration
bash editors/setup.sh   # Editor configurations
```

## Editor Settings Management

### Why Symlinks Instead of Gists?

This repository uses symlinks instead of VS Code Settings Sync or GitHub Gists because:

- **Version Control**: Full git history of all configuration changes
- **Offline Access**: No dependency on external services or internet connectivity
- **Atomic Changes**: All settings changes are tracked together in commits
- **Backup Integration**: Settings are automatically backed up with the rest of your dotfiles
- **Multi-Editor Support**: Cursor inherits VS Code settings automatically
- **Transparency**: Clear visibility into what settings are being managed

### Managed Files

The following files and directories are managed (VS Code settings, inherited by Cursor):

- `settings.json` - Main editor settings
- `keybindings.json` - Custom keyboard shortcuts
- `locale.json` - Language/locale settings (if present)
- `snippets/` - Code snippets directory
- `extensions.txt` - VS Code extensions list (auto-synced to Cursor)

### Directory Structure

```
~/coding/dotfiles-mac/
├── editors/
│   ├── setup.sh          # Setup symlinks
│   ├── unlink.sh         # Remove symlinks
│   └── vscode/User/      # VS Code settings (shared by Cursor)
```

### Live Paths (Symlink Sources)

- **VS Code**: `~/Library/Application Support/Code/User/`
- **Cursor**: `~/Library/Application Support/Cursor/User/`

### How It Works

1. **Bootstrap**: Run `bash editors/setup.sh`
   - Existing live settings are moved to the repo (VS Code settings)
   - Symlinks are created from both VS Code and Cursor to the same repo files
   - VS Code extensions are exported to `extensions.txt`
   - Missing extensions are automatically installed in Cursor
   - Conflicts are backed up with timestamps

2. **Daily Usage**:
   - Edit settings normally in VS Code/Cursor
   - Changes are written through symlinks directly to repo files
   - Install new extensions in VS Code, then re-run setup to sync to Cursor
   - Commit changes to version control as needed

3. **Updates Flow**:
   ```
   Editor Settings → Symlink → Repo File → Git Commit
   VS Code Extensions → Auto-sync → Cursor Extensions
   ```

### Commands

#### Setup Symlinks & Extensions
```bash
# Set up symlinks and sync extensions for both editors
bash editors/setup.sh

# Preview what would be done (dry run)
bash editors/setup.sh --dry-run
```

#### Remove Symlinks
```bash
# Remove symlinks and restore real files
bash editors/unlink.sh

# Preview what would be done (dry run)
bash editors/unlink.sh --dry-run
```

#### Help
```bash
bash editors/setup.sh --help
bash editors/unlink.sh --help
```

### Extension Synchronization

The system automatically keeps Cursor extensions in sync with VS Code:

#### How Extension Sync Works
- **VS Code as Source**: VS Code extensions are the "source of truth"
- **Automatic Export**: Current VS Code extensions are saved to `extensions.txt` in the repo
- **Auto-Install**: Missing extensions are automatically installed in Cursor
- **Partial Sync**: Some extensions may fail to install due to marketplace differences

#### Extension Sync Results
After running the setup, you'll see a summary like:
```
📊 Extension sync summary:
  ✅ Successfully installed: 8
  ❌ Failed to install: 8
```

Failed installations are normal - some extensions may not be available in Cursor's marketplace.

#### Managing Extensions

**Standalone Extension Sync** (Recommended):
```bash
# Sync extensions bidirectionally (both directions)
bash editors/sync-extensions.sh

# Sync only from VS Code to Cursor
bash editors/sync-extensions.sh --to-cursor

# Sync only from Cursor to VS Code
bash editors/sync-extensions.sh --to-vscode

# Preview what would be synced
bash editors/sync-extensions.sh --dry-run
```

**Manual Management**:
1. **Add Extensions**: Install in either editor, then run sync script
2. **Remove Extensions**: Uninstall from either editor, then run sync script
3. **Bulk Setup**: Use `bash editors/setup.sh` for initial setup with extension sync

### Safety Features

- **Automatic Backups**: Existing files are backed up with timestamps before changes
- **Idempotent Operations**: Safe to run multiple times
- **Dry Run Mode**: Preview changes before applying them
- **Conflict Detection**: Handles cases where files exist in both locations
- **Rollback Support**: Easy to remove symlinks and restore original files

### Troubleshooting

#### Settings Not Syncing
If changes in your editor aren't appearing in the repo:
1. Check if symlinks are correctly created: `ls -la ~/Library/Application\ Support/Code/User/`
2. Re-run setup: `bash editors/setup.sh`

#### Want to Temporarily Disconnect
To temporarily stop using symlinks:
```bash
bash editors/unlink.sh
```

To re-enable:
```bash
bash editors/setup.sh
```

#### Manual Symlink Check
```bash
# Check VS Code symlinks
ls -la ~/Library/Application\ Support/Code/User/

# Check Cursor symlinks
ls -la ~/Library/Application\ Support/Cursor/User/
```

## Repository Structure

```
~/coding/dotfiles-mac/
├── aerospace/
│   └── setup.sh          # Aerospace window manager setup
├── tmux/
│   ├── .tmux.conf        # tmux configuration
│   └── setup.sh          # tmux setup (symlink)
├── editors/
│   ├── setup.sh          # Editor symlink management
│   ├── sync-extensions.sh # Bidirectional extension sync
│   ├── unlink.sh         # Remove editor symlinks
│   └── vscode/User/      # VS Code settings (shared by Cursor)
├── macos/
│   └── setup.sh          # macOS system settings only
├── utils/
│   └── symlinks.sh       # Utility functions for symlink management
├── .gitignore           # Excludes noisy editor files
├── README.md            # This file
└── setup-all.sh         # Main setup script
```
