# homebrew-jotraw

A [Homebrew tap](https://docs.brew.sh/Taps) for the `jotraw` command-line
tool and the `JotSync` iCloud sync agent that pair with the
[JotRaw](https://apps.apple.com/app/jotraw) iOS app.

JotRaw on macOS is the iOS app installed via the App Store ("Designed for
iPad"). This tap adds two pieces that aren't in the App Store distribution:

| What | Where it lands |
|------|----------------|
| `jotraw` CLI | `/opt/homebrew/bin/jotraw` |
| `JotSync.app` faceless sync agent | `/Applications/JotSync.app` |
| launchd plist that keeps the agent alive at login | `~/Library/LaunchAgents/io.evorio.jotsync.plist` |

## Install

```sh
brew trust evorio-io/jotraw
brew tap evorio-io/jotraw
brew install --cask jotraw
```
> [!NOTE]
> Homebrew requires user to trust the tap. Required for casks from
> third-party taps that run install-time scripts.

After install, `jotraw` is available in any new shell. The sync agent is
already running — no logout/login needed.

## Use

```sh
# Read the current scratchpad
jotraw

# Write a new value
printf "hello from terminal" | jotraw

# Suppress the echo on write
printf "quiet write" | jotraw --no-output

# Edit the scratchpad contents
nvim "$(jotraw file)"
```

If the JotRaw iOS app is open on this Mac (or on another device signed into
the same iCloud account), the value updates there within a few seconds.

## How it shares state

```
iPhone / iPad / Mac (JotRaw iOS app)
                       |
                       v
            CloudKit private database  <--->  iCloud
                       ^
                       |   CKSyncEngine, runs in JotSync.app
                       v
            ~/Library/Group Containers/group.io.evorio.jotraw/scratchpad.txt
                       ^
                       |
                       v
                   jotraw CLI
```

`JotSync.app` is the part with iCloud entitlements. It mirrors changes
between the local file (which `jotraw` reads/writes) and a CloudKit
private-database record (which iCloud syncs across your devices) in
both directions. The CLI itself has no iCloud entitlements and doesn't
need them — the agent handles the sync.

Either side can be installed first. The CLI works standalone (with no
sync) until the iOS app or another instance of JotSync brings iCloud
into the picture.

## Uninstall

```sh
brew uninstall --cask jotraw
```

This stops and unregisters the sync agent, removes the binary, the app,
and the launchd plist. The scratchpad file at
`~/Library/Group Containers/group.io.evorio.jotraw/scratchpad.txt` is left
in place — `brew uninstall --cask --zap jotraw` removes that too.

## Source code

The CLI and agent sources live in a private repo. Issues and feature
requests welcome at the tap repo:
<https://github.com/evorio-io/homebrew-jotraw/issues>.

## License

The cask and this README are MIT-licensed (see `LICENSE`). The bundled
binaries (`jotraw`, `JotSync.app`) are distributed under the JotRaw EULA
shipped inside the app.
```
