import ServiceManagement

// MARK: - Start at login
// Uses SMAppService (macOS 13+) so the widget itself registers as a login
// item - no separate helper app or /Library/LaunchAgents plist needed.

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func enable() {
        guard !isEnabled else { return }
        do {
            try SMAppService.mainApp.register()
        } catch {
            print("LaunchAtLogin: failed to register - \(error)")
        }
    }

    static func disable() {
        guard isEnabled else { return }
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            print("LaunchAtLogin: failed to unregister - \(error)")
        }
    }

    static func toggle() {
        isEnabled ? disable() : enable()
    }
}
