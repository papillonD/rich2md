#!/bin/zsh
# Builds Rich 2 MD and installs it as a login item (LaunchAgent) that runs in the background.
# Run it again at any time to rebuild and restart after an update.
set -e
DIR="${0:A:h}"
LABEL="local.rich2md"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"
BIN="$DIR/build/rich2md"
BIN_XML="${${${BIN//&/&amp;}//</&lt;}//>/&gt;}"   # the path as it must appear inside the plist

# Remove the earlier version of this tool (installed as local.wispr2md) if it's there.
OLD_PLIST="$HOME/Library/LaunchAgents/local.wispr2md.plist"
if [[ -f "$OLD_PLIST" ]]; then
  launchctl bootout "$DOMAIN/local.wispr2md" 2>/dev/null || true
  rm -f "$OLD_PLIST" "$DIR/wispr2md"
  echo "Removed the earlier version."
fi

# Older versions built in the project folder itself, which made codesign treat the whole
# folder as an app bundle. Remove what that left behind.
rm -f "$DIR/rich2md" "$DIR/_CodeSignature/CodeResources"
[[ -d "$DIR/_CodeSignature" ]] && rmdir "$DIR/_CodeSignature" 2>/dev/null || true

# Build in its own folder so only the binary is signed.
echo "Building…"
mkdir -p "$DIR/build"
swiftc -O "$DIR/rich2md.swift" -o "$BIN" \
  -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$DIR/Info.plist"
codesign --force --sign - --identifier "$LABEL" "$BIN" 2>/dev/null

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>$BIN_XML</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>ProcessType</key><string>Interactive</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/rich2md.log</string>
</dict>
</plist>
PLIST

# Stop the running copy (if any) and wait for it to exit before starting the new one.
launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
for _ in {1..25}; do
  launchctl print "$DOMAIN/$LABEL" &>/dev/null || break
  sleep 0.2
done
launchctl bootstrap "$DOMAIN" "$PLIST"

echo "Rich 2 MD is installed and running. Look for the clipboard icon in your menu bar."
echo "It starts automatically when you log in. Log: ~/Library/Logs/rich2md.log"
