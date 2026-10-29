#!/bin/bash
# Install lidmode for the current user. Safe to run again.
# Never asks for or handles a password: the one sudo step is printed for you to run.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"
DIR="$HOME/.local/share/lidmode"
AGENTS="$HOME/Library/LaunchAgents"
LABEL="com.lidmode.agent"
PLIST="$AGENTS/$LABEL.plist"
SUDOERS_SRC="$DIR/sudoers-lidmode"
SUDOERS_DST="/etc/sudoers.d/lidmode"

die() { echo "error: $*" >&2; exit 1; }
step() { echo "==> $*"; }

[ "$(uname -s)" = "Darwin" ] || die "lidmode only runs on macOS."
[ "$(uname -m)" = "arm64" ] || die "lidmode needs an Apple Silicon Mac (the brightness tool uses the Apple Silicon display stack)."
[ -d /Applications/Amphetamine.app ] || die "Amphetamine is not in /Applications. Install it from the Mac App Store first."
if ! xcode-select -p >/dev/null 2>&1 || ! xcrun --find swiftc >/dev/null 2>&1; then
  die "swiftc not found. Run: xcode-select --install   then run this script again."
fi

# These values are written into a plist and a sudoers file, so refuse anything unusual.
USER_NAME="$(id -un)"
case "$USER_NAME" in
  ""|[!A-Za-z_]*|*[!A-Za-z0-9._-]*) die "unsupported user name '$USER_NAME'." ;;
esac
case "$HOME" in
  *[\&\|\\\<\>]*|*$'\n'*) die "HOME contains a character this installer cannot write safely." ;;
esac

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

step "Compiling the brightness tool"
xcrun swiftc -O "$REPO/brightness/lidmode-brightness.swift" -o "$WORK/lidmode-brightness"

step "Installing scripts to $BIN"
mkdir -p "$BIN" "$DIR" "$AGENTS"
# Copy then rename, so a running watcher keeps its old file until it restarts.
cp "$WORK/lidmode-brightness" "$BIN/.lidmode-brightness.new"
mv "$BIN/.lidmode-brightness.new" "$BIN/lidmode-brightness"
cp "$REPO/lidmode" "$BIN/.lidmode.new"
chmod 755 "$BIN/.lidmode.new"
mv "$BIN/.lidmode.new" "$BIN/lidmode"

step "Writing and loading the LaunchAgent ($LABEL)"
sed "s|@HOME@|$HOME|g" "$REPO/launchd/com.lidmode.agent.plist.template" > "$WORK/agent.plist"
plutil -lint "$WORK/agent.plist" >/dev/null
cp "$WORK/agent.plist" "$PLIST"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

step "Preparing the sudoers file"
sed "s|@USER@|$USER_NAME|g" "$REPO/sudoers/lidmode.template" > "$WORK/sudoers"
visudo -cf "$WORK/sudoers" >/dev/null || die "generated sudoers file failed visudo -c."
rm -f "$SUDOERS_SRC"   # the previous copy is read-only
cp "$WORK/sudoers" "$SUDOERS_SRC"
chmod 440 "$SUDOERS_SRC"
visudo -cf "$SUDOERS_SRC"

echo
case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "Note: $BIN is not on your PATH. Add it to run 'lidmode' by name." ;;
esac

if sudo -n /usr/bin/pmset -g >/dev/null 2>&1; then
  echo "sudo already allows /usr/bin/pmset without a password. Nothing more to do for low power mode."
else
  echo "One step is left, and it needs your password, so run it yourself."
  echo "It lets lidmode run /usr/bin/pmset (and nothing else) through sudo without a password:"
  echo
  echo "  sudo sh -c \"visudo -cf '$SUDOERS_SRC' && install -m 0440 -o root -g wheel '$SUDOERS_SRC' $SUDOERS_DST\""
  echo
  echo "Until then brightness and mute work, but low power mode does not change."
fi

echo
echo "Installed. In Amphetamine, enable closed-display mode for your sessions and set it to start at login."
echo "Check with: lidmode status      Log: ~/Library/Logs/lidmode.log"
