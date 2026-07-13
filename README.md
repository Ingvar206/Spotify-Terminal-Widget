# Spotify Widget for macOS

A floating desktop widget (native SwiftUI) that shows an animated now-playing
view of Spotify, and flips into a real zsh terminal on click.

## Features

**Player side**
- Title, artist, cover art, live from the local Spotify app (AppleScript, no API key)
- Blurred cover art and a slowly rotating color haze as background
- Accent color automatically extracted from the album cover
- Pulsing glow around the cover and animated equalizer bars while playing
- Marquee scrolling for long titles
- Smooth progress bar, clickable to seek
- Play/pause, previous/next
- Window sits at desktop level (behind all normal windows), draggable, no dock icon
- Snaps into an invisible desktop grid when you drop it (like real macOS desktop widgets) and reopens there next time
- Starts automatically when you log into your Mac (toggle via right-click)

**Terminal side** (terminal button top right, appears on hover)
- 3D card-flip animation, window resizes automatically
- Full zsh login shell (VT100/xterm via [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm))
- Session persists when flipping back; `exit` automatically starts a new shell
- Return to the player via the player button

## Requirements

- macOS 13 (Ventura) or newer
- Xcode or Command Line Tools (`xcode-select --install`)
- Spotify desktop app installed

## Build & Run

```bash
cd SpotifyWidget
chmod +x build_app.sh
./build_app.sh
open "/Applications/SpotifyWidget.app"
```

`build_app.sh` copies the built app into `/Applications` - this is
required so that the "start at login" registration stays valid even if
you later delete this project folder or move the build directory.

On first launch, macOS will ask: *"SpotifyWidget wants to control Spotify"* -> Allow.
(If the prompt didn't appear or was denied: System Settings -> Privacy &
Security -> Automation -> SpotifyWidget -> enable Spotify.)

The widget registers itself to start at login automatically the very
first time it runs. Right-click the widget any time to toggle this off
again, or check System Settings -> General -> Login Items.

Alternatively, open the project directly in Xcode (double-click `Package.swift`)
and run it with Cmd+R.

## Usage

| Action | How |
|---|---|
| Move | Drag the background (position is remembered) |
| Open terminal | Hover, then click the terminal icon top right |
| Back to player | Player icon top right in the terminal |
| Quit | Hover, then click the close icon top left, or right-click -> Widget beenden |
| Toggle autostart | Right-click the widget |
| Seek | Click the progress bar |

## Troubleshooting

- **"Spotify is not running"** -> Start the Spotify app (the widget polls every second and recovers on its own).
- **No track data despite Spotify running** -> Check the Automation permission (see above), then restart the widget.
- **`swift build` fails (SwiftTerm)** -> Requires an internet connection (SwiftPM fetches SwiftTerm from GitHub). If a newer SwiftTerm version breaks the API, pin `Package.swift` to `.exact("1.2.0")`.
- **Terminal doesn't accept input** -> Click into the terminal once to focus it.
- **Doesn't start at login** -> Check System Settings -> General -> Login Items; make sure `SpotifyWidget.app` is listed and enabled, and that it's running from `/Applications` (not a temporary build folder).

## Project structure

```
SpotifyWidget/
+-- Package.swift                      # SwiftPM manifest (+ SwiftTerm dependency)
+-- Info.plist                         # Bundle info, including Automation permission
+-- build_app.sh                       # Builds, signs and installs SpotifyWidget.app to /Applications
+-- Sources/SpotifyWidget/
    +-- main.swift                     # App setup, borderless desktop-level window, position persistence
    +-- LaunchAtLogin.swift            # SMAppService-based autostart at login
    +-- SpotifyController.swift        # AppleScript polling, artwork, accent color
    +-- PlayerView.swift               # Player UI and all animations
    +-- TerminalPane.swift             # zsh terminal (SwiftTerm bridge)
```
