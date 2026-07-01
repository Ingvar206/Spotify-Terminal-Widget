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

    static let playerSize = CGSize(width: 400, height: 190)
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

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: KeyableWindow!

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

        WidgetWindow.window = window

        // place in the top-right corner of the main screen
        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            let origin = NSPoint(
                x: vf.maxX - size.width - 24,
                y: vf.maxY - size.height - 24
            )
            window.setFrameOrigin(origin)
        } else {
            window.center()
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

// Entry point (SwiftPM executable)
let app = NSApplication.shared
app.setActivationPolicy(.accessory) // no dock icon, no menu - real widget feel
let delegate = AppDelegate()
app.delegate = delegate
app.run()
