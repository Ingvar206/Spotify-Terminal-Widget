import AppKit
import SwiftUI

// MARK: - Window that can accept keyboard focus despite being .borderless
// (needed so text can be typed into the terminal)
final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Central window control (animates size on flip)
enum WidgetWindow {
    static weak var window: NSWindow?

    // 338x158pt matches Apple's "Medium" system-widget size on macOS,
    // so the player side reads as a real desktop widget, not a custom panel.
    static let playerSize = CGSize(width: 338, height: 158)
    static let terminalSize = CGSize(width: 620, height: 400)

    static func resize(to size: CGSize) {
        guard let win = window else { return }
        var frame = win.frame
        // anchor top-left so the widget doesn't "jump"
        frame.origin.y += frame.size.height - size.height
        frame.size = size
        win.setFrame(frame, display: true, animate: true)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: KeyableWindow!

    private static let topLeftDefaultsKey = "WidgetTopLeftOrigin"
    private static let hasConfiguredLoginItemKey = "WidgetHasConfiguredLoginItem"
    // Invisible grid the widget snaps to when dropped, approximating the
    // desktop icon grid real macOS desktop widgets align themselves to.
    private static let gridSize: CGFloat = 80

    private var snapTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let size = WidgetWindow.playerSize
        window = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        // Backmost level: one step ABOVE the desktop icons (otherwise
        // Finder's invisible icon window swallows all clicks), but still
        // BELOW every normal window - like a real desktop widget.
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        window.isMovableByWindowBackground = true      // draggable via the background
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.contentView = NSHostingView(rootView: RootView())
        window.delegate = self

        WidgetWindow.window = window

        // Restore the last position the user dragged the widget to, if any.
        if let topLeft = Self.loadSavedTopLeft() {
            window.setFrameOrigin(Self.snappedOrigin(forTopLeft: topLeft, size: size))
        } else if let screen = NSScreen.main {
            // First launch: place in the top-right corner of the main screen.
            let vf = screen.visibleFrame
            let origin = NSPoint(
                x: vf.maxX - size.width - 24,
                y: vf.maxY - size.height - 24
            )
            let topLeft = NSPoint(x: origin.x, y: origin.y + size.height)
            window.setFrameOrigin(Self.snappedOrigin(forTopLeft: topLeft, size: size))
        } else {
            window.center()
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // First-ever launch: start automatically at login. Users can turn
        // this off again via the right-click menu; we won't force it back on.
        if !UserDefaults.standard.bool(forKey: Self.hasConfiguredLoginItemKey) {
            LaunchAtLogin.enable()
            UserDefaults.standard.set(true, forKey: Self.hasConfiguredLoginItemKey)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: - Position persistence & grid snapping

    func windowDidMove(_ notification: Notification) {
        saveTopLeft()

        // Snap once the drag settles (debounced) rather than on every pixel
        // of movement, so dragging still feels smooth and only the final
        // drop position snaps into the grid - like the real desktop widgets.
        snapTimer?.invalidate()
        snapTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            self?.snapToGrid()
        }
    }

    private func snapToGrid() {
        guard let win = window else { return }
        let frame = win.frame
        let topLeft = NSPoint(x: frame.origin.x, y: frame.origin.y + frame.size.height)
        let target = Self.snappedOrigin(forTopLeft: topLeft, size: frame.size)

        guard abs(target.x - frame.origin.x) > 0.5 || abs(target.y - frame.origin.y) > 0.5 else { return }

        var newFrame = frame
        newFrame.origin = target
        win.setFrame(newFrame, display: true, animate: true)
    }

    private func saveTopLeft() {
        guard let win = window else { return }
        let topLeft = NSPoint(x: win.frame.origin.x, y: win.frame.origin.y + win.frame.size.height)
        UserDefaults.standard.set(["x": Double(topLeft.x), "y": Double(topLeft.y)],
                                   forKey: Self.topLeftDefaultsKey)
    }

    private static func loadSavedTopLeft() -> NSPoint? {
        guard let dict = UserDefaults.standard.dictionary(forKey: topLeftDefaultsKey),
              let x = dict["x"] as? Double, let y = dict["y"] as? Double else { return nil }
        return NSPoint(x: x, y: y)
    }

    /// Snaps a dropped top-left point onto the invisible desktop grid and
    /// keeps it on-screen even if the display setup changed (e.g. an
    /// external monitor got disconnected) since the last run.
    private static func snappedOrigin(forTopLeft topLeft: NSPoint, size: CGSize) -> NSPoint {
        let containing = NSScreen.screens.first { $0.frame.contains(topLeft) } ?? NSScreen.main
        guard let vf = containing?.visibleFrame else {
            return NSPoint(x: topLeft.x, y: topLeft.y - size.height)
        }

        let relativeX = topLeft.x - vf.minX
        let relativeTopY = vf.maxY - topLeft.y
        let snappedX = (relativeX / gridSize).rounded() * gridSize + vf.minX
        let snappedTopY = vf.maxY - (relativeTopY / gridSize).rounded() * gridSize

        var origin = NSPoint(x: snappedX, y: snappedTopY - size.height)
        origin.x = min(max(origin.x, vf.minX), vf.maxX - size.width)
        origin.y = min(max(origin.y, vf.minY), vf.maxY - size.height)
        return origin
    }
}

// Entry point (SwiftPM executable)
let app = NSApplication.shared
app.setActivationPolicy(.accessory) // no dock icon, no menu - real widget feel
let delegate = AppDelegate()
app.delegate = delegate
app.run()
