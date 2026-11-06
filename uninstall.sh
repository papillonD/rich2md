#!/bin/zsh
# Stops Rich 2 MD and removes it from your login items. Your settings are kept unless you pass --all.
DOMAIN="gui/$(id -u)"
for label in local.rich2md local.wispr2md; do   # local.wispr2md = earlier version
  launchctl bootout "$DOMAIN/$label" 2>/dev/null || true
  rm -f "$HOME/Library/LaunchAgents/$label.plist"
done
if [[ "$1" == "--all" ]]; then
  rm -rf "$HOME/Library/Application Support/Rich 2 MD" "$HOME/Library/Logs/rich2md.log" "$HOME/Library/Logs/wispr2md.log"
  echo "Rich 2 MD removed, along with its settings and log."
else
  echo "Rich 2 MD stopped and removed from login items. Settings are kept in ~/Library/Application Support/Rich 2 MD."
fi
