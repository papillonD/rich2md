#!/bin/zsh
launchctl bootout "gui/$(id -u)/local.wispr2md" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/local.wispr2md.plist"
echo "wispr2md stopped and removed from login items."
