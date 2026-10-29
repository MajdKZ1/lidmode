#!/bin/bash
# Remove lidmode: the agent, the scripts and the state. The sudoers file is left for you to remove.
set -uo pipefail

BIN="$HOME/.local/bin"
DIR="$HOME/.local/share/lidmode"
LABEL="com.lidmode.agent"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

# Restores any saved low power mode, brightness and mute state, then removes its own files.
hint=1
if [ -x "$BIN/lidmode" ]; then "$BIN/lidmode" uninstall; hint=0; fi

# Whatever that left behind, or everything if lidmode was already gone.
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
rm -f "$PLIST" "$BIN/lidmode" "$BIN/lidmode-brightness" "${TMPDIR:-/tmp}/lidmode.state"
rm -rf "$DIR"

echo "lidmode removed. The log was kept at ~/Library/Logs/lidmode.log."
[ "$hint" = 1 ] && echo "To remove the sudoers rule: sudo rm /etc/sudoers.d/lidmode"
exit 0
