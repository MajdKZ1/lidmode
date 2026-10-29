# lidmode

A small background watcher for MacBooks that are kept awake with the lid shut. When the lid closes, it turns on low power mode, sets the screen brightness to 0 and mutes the audio. When the lid opens, it puts all three back exactly as they were. The point is a MacBook carried closed in a bag, awake because of Amphetamine, that runs cooler and quieter while it works.

**lidmode requires [Amphetamine](https://apps.apple.com/app/amphetamine/id937984704) and only acts while an Amphetamine session is active.** If the lid closes and no session is running, it does nothing, and it does nothing on open either.

## Requirements

- An Apple Silicon MacBook
- macOS 27.2 (the version it was tested on)
- Amphetamine, installed in /Applications
- Xcode command line tools (`xcode-select --install`), needed to compile the brightness tool

## Install

```
git clone https://github.com/MajdKZ1/lidmode.git
cd lidmode
./install.sh
```

The installer checks the requirements, compiles the brightness tool, copies `lidmode` and `lidmode-brightness` to `~/.local/bin`, and writes and loads a LaunchAgent (`com.lidmode.agent`) that starts at login and restarts if it stops. It is safe to run again.

Low power mode needs `pmset`, which needs root. The installer generates a sudoers file that allows `/usr/bin/pmset` without a password and nothing else, checks it with `visudo -c`, and prints one `sudo` command for you to run yourself. The installer never asks for or handles a password. Until you run that command, brightness and mute work and low power mode does not change.

## Amphetamine setup

lidmode cannot change these for you:

- Enable closed-display mode for the sessions you start.
- Set Amphetamine to start at login, so it is running when the lid closes.

## Usage

```
lidmode status          lid, Amphetamine detection, saved state, current values
lidmode close           pretend the lid closed (respects the session check)
lidmode close --force   pretend the lid closed, ignoring the session check
lidmode open            pretend the lid opened
lidmode auto            go back to following the real lid
lidmode uninstall       restore any saved state and remove everything
```

Add `~/.local/bin` to your PATH if `lidmode` is not found by name.

### Testing without closing the lid

Start an Amphetamine session, then:

```
lidmode close      # low power mode on, brightness 0, muted
lidmode status
lidmode open       # everything restored
lidmode auto
```

With no session, `lidmode close` does nothing and `lidmode status` shows `saved: ACTED=0`. To see the actions anyway, use `lidmode close --force`. Simulating a close turns the screen black until you run `lidmode open`.

The log is `~/Library/Logs/lidmode.log`.

## Uninstall

```
./uninstall.sh
```

This restores any saved state and removes the agent, the scripts and the state. It leaves the log and the sudoers file. Remove the sudoers file with:

```
sudo rm /etc/sudoers.d/lidmode
```

## How it works

- Every 2 seconds the watcher reads `AppleClamshellState` from `ioreg` and acts only when it changes.
- On close it runs `pmset -g assertions` and looks for an assertion owned by the `Amphetamine` process. The assertion's name varies by session type, and the app running with no session holds none, so the owner is what it matches.
- If a session is active, it writes `$TMPDIR/lidmode.state` beginning with `ACTED=1`, followed by the low power mode setting (battery and AC separately), the mute state and the brightness. Then it runs `sudo pmset -a lowpowermode 1`, sets brightness to 0 and mutes.
- If no session is active, it writes `ACTED=0`, changes nothing and logs `close: skipped, no Amphetamine session active`.
- On open it restores only when the state file says `ACTED=1`, then deletes the file. Low power mode and mute that were already on before the close stay on.
- Brightness is the last nonzero value seen while the lid was open, because the panel is already off by the time the close is noticed. It is set through Apple's private DisplayServices framework by a small Swift tool, since the Homebrew `brightness` tool does not work on Apple Silicon built-in displays.

## Known limits

- The session check happens at the moment the lid closes. A session started or ended while the lid is shut changes nothing until the next close.
- The lid is polled every 2 seconds, so closing and reopening faster than that is not seen.
- Brightness control uses a private Apple framework and could break in a future macOS release.
- Tested only on a MacBook Pro M5 running macOS 27.2.

## License

MIT
