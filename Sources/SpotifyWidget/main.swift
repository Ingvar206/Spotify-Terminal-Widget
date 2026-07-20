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
    // Real desktop widgets never sit flush against the screen edge - they
    // always keep a bit of breathing room, even when dragged as far as
    // possible in one direction.
    private static let edgeMargin: CGFloat = 16

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
            window.setFrameOrigin(Self.clampedOrigin(forTopLeft: topLeft, size: size))
        } else if let screen = NSScreen.main {
            // First launch: place in the top-right corner of the main screen.
            let vf = screen.visibleFrame
            let origin = NSPoint(
                x: vf.maxX - size.width - Self.edgeMargin,
                y: vf.maxY - size.height - Self.edgeMargin
            )
            window.setFrameOrigin(origin)
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

    // MARK: - Position persistence & screen-edge margin

    func windowDidMove(_ notification: Notification) {
        clampToScreenEdges()
        saveTopLeft()
    }

    // Stops the widget right at the margin instead of letting it be dragged
    // flush against (or past) the screen edge, like real desktop widgets.
    private func clampToScreenEdges() {
        guard let win = window, let screen = win.screen ?? NSScreen.main else { return }
        let frame = win.frame
        let clamped = Self.clampedOrigin(frame.origin, size: frame.size, in: screen.visibleFrame)
        guard clamped != frame.origin else { return }
        win.setFrameOrigin(clamped)
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

    /// Keeps a restored top-left point on-screen (respecting the edge margin)
    /// even if the display setup changed (e.g. an external monitor got
    /// disconnected) since the last run.
    private static func clampedOrigin(forTopLeft topLeft: NSPoint, size: CGSize) -> NSPoint {
        let containing = NSScreen.screens.first { $0.frame.contains(topLeft) } ?? NSScreen.main
        let origin = NSPoint(x: topLeft.x, y: topLeft.y - size.height)
        guard let vf = containing?.visibleFrame else { return origin }
        return clampedOrigin(origin, size: size, in: vf)
    }

    /// Keeps `origin` within `visibleFrame`, leaving `edgeMargin` of breathing
    /// room on every side - real desktop widgets never sit flush against the
    /// screen edge.
    private static func clampedOrigin(_ origin: NSPoint, size: CGSize, in visibleFrame: NSRect) -> NSPoint {
        var origin = origin
        let minX = visibleFrame.minX + edgeMargin
        let maxX = visibleFrame.maxX - edgeMargin - size.width
        let minY = visibleFrame.minY + edgeMargin
        let maxY = visibleFrame.maxY - edgeMargin - size.height

        // If the widget is wider/taller than the screen minus margins, fall
        // back to centering it rather than producing an inverted range.
        origin.x = minX <= maxX ? min(max(origin.x, minX), maxX) : (visibleFrame.minX + visibleFrame.maxX - size.width) / 2
        origin.y = minY <= maxY ? min(max(origin.y, minY), maxY) : (visibleFrame.minY + visibleFrame.maxY - size.height) / 2
        return origin
    }
}

// Entry point (SwiftPM executable)
let app = NSApplication.shared
app.setActivationPolicy(.accessory) // no dock icon, no menu - real widget feel
let delegate = AppDelegate()
app.delegate = delegate
app.run()
