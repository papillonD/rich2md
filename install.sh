#!/bin/zsh
# Builds wispr2md and installs it as a login item (LaunchAgent) that runs in the background.
# Pass --slack-bold to use *single* asterisks instead of **double**.
set -e
DIR="${0:A:h}"
PLIST="$HOME/Library/LaunchAgents/local.wispr2md.plist"
EXTRA=""; [[ "$1" == "--slack-bold" ]] && EXTRA="<string>--bold</string><string>slack</string>"

swiftc -O "$DIR/wispr2md.swift" -o "$DIR/wispr2md"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>local.wispr2md</string>
  <key>ProgramArguments</key>
  <array><string>$DIR/wispr2md</string>$EXTRA</array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>ProcessType</key><string>Interactive</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/wispr2md.log</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)/local.wispr2md" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "wispr2md installed and running. Log: ~/Library/Logs/wispr2md.log"
