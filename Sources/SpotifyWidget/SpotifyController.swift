import AppKit
import CoreImage
import SwiftUI

// MARK: - Track model

struct TrackInfo: Equatable {
    var title: String = "Spotify is not running"
    var artist: String = ""
    var album: String = ""
    var artworkURL: String = ""
    var duration: Double = 0      // seconds
    var position: Double = 0      // seconds (as of the last poll)
    var isPlaying: Bool = false
    var isRunning: Bool = false
}

// MARK: - Controller
// Fetches all data via AppleScript from the local Spotify app (no API key needed).
// osascript runs in its own process on a background queue so the UI is
// never blocked.

@MainActor
final class SpotifyController: ObservableObject {
    @Published var track = TrackInfo()
    @Published var artwork: NSImage?
    @Published var accent: Color = Color(red: 0.11, green: 0.73, blue: 0.33) // Spotify green as fallback
    @Published var lastPoll = Date()

    private var timer: Timer?
    private var lastArtworkURL = ""
    private var polling = false

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    deinit { timer?.invalidate() }

    // Currently displayed position: interpolate between polls so the
    // progress bar moves smoothly.
    func displayedPosition(now: Date = Date()) -> Double {
        guard track.isPlaying else { return track.position }
        return min(track.position + now.timeIntervalSince(lastPoll), track.duration)
    }

    // MARK: Controls

    func playPause()  { runControl("tell application \"Spotify\" to playpause") }
    func nextTrack()  { runControl("tell application \"Spotify\" to next track") }
    func prevTrack()  { runControl("tell application \"Spotify\" to previous track") }

    func seek(to seconds: Double) {
        track.position = seconds
        lastPoll = Date()
        runControl("tell application \"Spotify\" to set player position to \(Int(seconds))")
    }

    private func runControl(_ script: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = Self.osascript(script)
            Task { @MainActor in self.refresh() }
        }
    }

    // MARK: Polling

    func refresh() {
        guard !polling else { return }
        polling = true

        // Return numbers as millisecond integers -> avoids decimal
        // separator issues across locales.
        let script = """
        if application "Spotify" is running then
            tell application "Spotify"
                try
                    set trackName to name of current track
                    set trackArtist to artist of current track
                    set trackAlbum to album of current track
                    set trackArt to artwork url of current track
                    set trackDur to duration of current track
                    set trackPos to (player position * 1000) as integer
                    set playState to (player state as string)
                    return trackName & "\\n" & trackArtist & "\\n" & trackAlbum & "\\n" & trackArt & "\\n" & trackDur & "\\n" & trackPos & "\\n" & playState
                on error
                    return "NO_TRACK"
                end try
            end tell
        else
            return "NOT_RUNNING"
        end if
        """

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let output = Self.osascript(script)
            Task { @MainActor in
                self?.parse(output)
                self?.polling = false
            }
        }
    }

    private func parse(_ output: String?) {
        lastPoll = Date()

        guard let output, output != "NOT_RUNNING" else {
            track = TrackInfo()
            artwork = nil
            return
        }
        guard output != "NO_TRACK" else {
            track = TrackInfo(title: "No track", isRunning: true)
            return
        }

        let parts = output.components(separatedBy: "\n")
        guard parts.count >= 7 else { return }

        var t = TrackInfo()
        t.title = parts[0]
        t.artist = parts[1]
        t.album = parts[2]
        t.artworkURL = parts[3]
        t.duration = (Double(parts[4]) ?? 0) / 1000.0
        t.position = (Double(parts[5]) ?? 0) / 1000.0
        t.isPlaying = parts[6].lowercased().contains("playing")
        t.isRunning = true
        track = t

        if t.artworkURL != lastArtworkURL, let url = URL(string: t.artworkURL) {
            lastArtworkURL = t.artworkURL
            fetchArtwork(url: url)
        }
    }

    private func fetchArtwork(url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = NSImage(data: data) else { return }
            let color = Self.dominantColor(of: image)
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.6)) {
                    self?.artwork = image
                    if let color { self?.accent = Color(nsColor: color) }
                }
            }
        }.resume()
    }

    // MARK: Helpers

    /// osascript as its own process - thread-safe, doesn't block the app.
    private static func osascript(_ source: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    /// Average color of the cover art (CIAreaAverage), slightly boosted
    /// so it works well as an accent color.
    private static func dominantColor(of image: NSImage) -> NSColor? {
        guard let tiff = image.tiffRepresentation,
              let ciImage = CIImage(data: tiff) else { return nil }

        let extent = ciImage.extent
        guard let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [kCIInputImageKey: ciImage,
                         kCIInputExtentKey: CIVector(cgRect: extent)]
        ), let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(outputImage,
                       toBitmap: &bitmap,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: nil)

        let base = NSColor(red: CGFloat(bitmap[0]) / 255.0,
                           green: CGFloat(bitmap[1]) / 255.0,
                           blue: CGFloat(bitmap[2]) / 255.0,
                           alpha: 1.0)

        // Boost saturation and brightness, otherwise it often ends up a dull gray
        guard let hsb = base.usingColorSpace(.deviceRGB) else { return base }
        return NSColor(hue: hsb.hueComponent,
                       saturation: min(1.0, hsb.saturationComponent * 1.6 + 0.15),
                       brightness: min(1.0, max(0.65, hsb.brightnessComponent * 1.3)),
                       alpha: 1.0)
    }
}

/// mm:ss format for time labels
func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let s = Int(seconds)
    return String(format: "%d:%02d", s / 60, s % 60)
}
