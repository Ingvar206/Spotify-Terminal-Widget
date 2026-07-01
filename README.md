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
open SpotifyWidget.app
```

On first launch, macOS will ask: *"SpotifyWidget wants to control Spotify"* -> Allow.
(If the prompt didn't appear or was denied: System Settings -> Privacy &
Security -> Automation -> SpotifyWidget -> enable Spotify.)

Alternatively, open the project directly in Xcode (double-click `Package.swift`)
and run it with Cmd+R.

## Usage

| Action | How |
|---|---|
| Move | Drag the background |
| Open terminal | Hover, then click the terminal icon top right |
| Back to player | Player icon top right in the terminal |
| Quit | Hover, then click the close icon top left |
| Seek | Click the progress bar |

## Troubleshooting

- **"Spotify is not running"** -> Start the Spotify app (the widget polls every second and recovers on its own).
- **No track data despite Spotify running** -> Check the Automation permission (see above), then restart the widget.
- **`swift build` fails (SwiftTerm)** -> Requires an internet connection (SwiftPM fetches SwiftTerm from GitHub). If a newer SwiftTerm version breaks the API, pin `Package.swift` to `.exact("1.2.0")`.
- **Terminal doesn't accept input** -> Click into the terminal once to focus it.

## Project structure

```
SpotifyWidget/
+-- Package.swift                      # SwiftPM manifest (+ SwiftTerm dependency)
+-- Info.plist                         # Bundle info, including Automation permission
+-- build_app.sh                       # Builds and signs SpotifyWidget.app
+-- Sources/SpotifyWidget/
    +-- main.swift                     # App setup, borderless desktop-level window
    +-- SpotifyController.swift        # AppleScript polling, artwork, accent color
    +-- PlayerView.swift               # Player UI and all animations
    +-- TerminalPane.swift             # zsh terminal (SwiftTerm bridge)
```
