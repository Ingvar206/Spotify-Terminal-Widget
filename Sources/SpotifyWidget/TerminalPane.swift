import AppKit
import SwiftTerm
import SwiftUI

// MARK: - Terminal side of the widget
// A real, fully functional zsh login shell via SwiftTerm.
// The shell session persists when flipping back.

struct TerminalPane: View {
    var onBack: () -> Void
    @State private var hovering = false

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.08, blue: 0.10)

            TerminalWrapper()
                .padding(.top, 34)
                .padding([.leading, .trailing, .bottom], 8)

            // Header bar
            VStack {
                HStack(spacing: 8) {
                    CornerButton(systemName: "xmark", help: "Quit widget") {
                        NSApp.terminate(nil)
                    }
                    Text("zsh")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    CornerButton(systemName: "music.note", help: "Back to player") {
                        onBack()
                    }
                }
                .padding(8)
                .background(
                    LinearGradient(colors: [.black.opacity(0.5), .clear],
                                   startPoint: .top, endPoint: .bottom)
                )
                Spacer()
            }
        }
    }
}

// MARK: - SwiftTerm bridge

struct TerminalWrapper: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = LocalProcessTerminalView(frame: .zero)
        context.coordinator.terminal = terminal
        terminal.processDelegate = context.coordinator

        terminal.font = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
        terminal.nativeBackgroundColor = NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.10, alpha: 1)
        terminal.nativeForegroundColor = NSColor(calibratedWhite: 0.92, alpha: 1)

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        terminal.startProcess(executable: shell, args: ["-l"])

        // Give the terminal focus so typing works immediately
        DispatchQueue.main.async {
            terminal.window?.makeFirstResponder(terminal)
        }
        return terminal
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}

    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        weak var terminal: LocalProcessTerminalView?

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            // Shell exited (e.g. via `exit`) -> start a new session
            DispatchQueue.main.async { [weak self] in
                guard let terminal = self?.terminal else { return }
                let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
                terminal.startProcess(executable: shell, args: ["-l"])
            }
        }
    }
}
