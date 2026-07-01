import AppKit
import SwiftUI

// MARK: - Root: card flip between player and terminal

struct RootView: View {
    @StateObject private var spotify = SpotifyController()
    @State private var flipped = false
    @State private var terminalCreated = false // only start the shell on the first flip

    var body: some View {
        ZStack {
            PlayerView(spotify: spotify) { flip(to: true) }
                .opacity(flipped ? 0 : 1)
                .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .allowsHitTesting(!flipped)

            if terminalCreated {
                TerminalPane { flip(to: false) }
                    // pre-mirror the content so it reads correctly after the flip
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity(flipped ? 1 : 0)
                    .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                    .allowsHitTesting(flipped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        )
        .onAppear { spotify.start() }
    }

    private func flip(to showTerminal: Bool) {
        if showTerminal { terminalCreated = true }
        WidgetWindow.resize(to: showTerminal ? WidgetWindow.terminalSize
                                             : WidgetWindow.playerSize)
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            flipped = showTerminal
        }
    }
}

// MARK: - Player

struct PlayerView: View {
    @ObservedObject var spotify: SpotifyController
    var onTerminal: () -> Void
    @State private var hovering = false

    var body: some View {
        ZStack {
            PlayerBackground(artwork: spotify.artwork, accent: spotify.accent)

            HStack(spacing: 16) {
                ArtworkView(artwork: spotify.artwork,
                            accent: spotify.accent,
                            isPlaying: spotify.track.isPlaying)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            MarqueeText(text: spotify.track.title,
                                        font: .system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            MarqueeText(text: spotify.track.artist.isEmpty
                                            ? " " : spotify.track.artist,
                                        font: .system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer(minLength: 8)
                        EqualizerBars(playing: spotify.track.isPlaying, color: spotify.accent)
                    }

                    Spacer(minLength: 2)

                    ProgressBar(spotify: spotify)

                    ControlsRow(spotify: spotify)
                }
                .padding(.vertical, 2)
            }
            .padding(18)

            // Corner buttons (only visible on hover)
            VStack {
                HStack {
                    CornerButton(systemName: "xmark", help: "Quit widget") {
                        NSApp.terminate(nil)
                    }
                    Spacer()
                    CornerButton(systemName: "terminal.fill", help: "Open terminal") {
                        onTerminal()
                    }
                }
                Spacer()
            }
            .padding(10)
            .opacity(hovering ? 1 : 0)
            .animation(.easeInOut(duration: 0.18), value: hovering)
        }
        .onHover { hovering = $0 }
    }
}

// MARK: - Background: blurred cover art + slowly rotating color gradient

struct PlayerBackground: View {
    let artwork: NSImage?
    let accent: Color

    var body: some View {
        ZStack {
            VisualEffect() // system blur behind the window

            // IMPORTANT: the cover art as an .overlay on a sizeless shape +
            // .clipped() - this way the .fill image can't blow up the layout
            // (otherwise it pushes all the content out on re-layout).
            if let artwork {
                Color.clear
                    .overlay(
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    )
                    .clipped()
                    .blur(radius: 42)
                    .saturation(1.4)
                    .opacity(0.55)
                    .transition(.opacity)
            }

            // gently "breathing" color haze in the accent color
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                AngularGradient(
                    gradient: Gradient(colors: [
                        accent.opacity(0.30),
                        .clear,
                        accent.opacity(0.16),
                        .clear,
                        accent.opacity(0.30)
                    ]),
                    center: .center,
                    angle: .degrees(t.truncatingRemainder(dividingBy: 24) * 15)
                )
                .blur(radius: 30)
            }

            Color.black.opacity(0.35)
        }
    }
}

// MARK: - Cover art with pulsing glow

struct ArtworkView: View {
    let artwork: NSImage?
    let accent: Color
    let isPlaying: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let pulse = isPlaying ? 0.5 + 0.5 * abs(sin(t * 1.6)) : 0.0

            Group {
                if let artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.white.opacity(0.08))
                        Image(systemName: "music.note")
                            .font(.system(size: 34))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .frame(width: 118, height: 118)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: accent.opacity(0.35 + 0.35 * pulse),
                    radius: 10 + 10 * pulse)
            .scaleEffect(isPlaying ? 1.0 : 0.96)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isPlaying)
        }
        .frame(width: 118, height: 118)
    }
}

// MARK: - Progress bar (clickable to seek)

struct ProgressBar: View {
    @ObservedObject var spotify: SpotifyController

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
            let position = spotify.displayedPosition(now: timeline.date)
            let duration = max(spotify.track.duration, 1)
            let fraction = min(max(position / duration, 0), 1)

            VStack(spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.18))
                        Capsule()
                            .fill(spotify.accent)
                            .frame(width: max(4, geo.size.width * fraction))
                            .shadow(color: spotify.accent.opacity(0.7), radius: 4)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                let f = min(max(value.location.x / geo.size.width, 0), 1)
                                spotify.seek(to: f * spotify.track.duration)
                            }
                    )
                }
                .frame(height: 5)

                HStack {
                    Text(formatTime(position))
                    Spacer()
                    Text(formatTime(spotify.track.duration))
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(height: 22)
    }
}

// MARK: - Controls

struct ControlsRow: View {
    @ObservedObject var spotify: SpotifyController

    var body: some View {
        HStack(spacing: 22) {
            Spacer()
            ControlButton(systemName: "backward.fill", size: 15) { spotify.prevTrack() }
            ControlButton(systemName: spotify.track.isPlaying ? "pause.fill" : "play.fill",
                          size: 21, prominent: true, accent: spotify.accent) {
                spotify.playPause()
            }
            ControlButton(systemName: "forward.fill", size: 15) { spotify.nextTrack() }
            Spacer()
        }
    }
}

struct ControlButton: View {
    let systemName: String
    var size: CGFloat
    var prominent: Bool = false
    var accent: Color = .white
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: prominent ? 42 : 32, height: prominent ? 42 : 32)
                .background(
                    Circle().fill(prominent ? accent.opacity(0.85)
                                            : .white.opacity(hovering ? 0.16 : 0.0))
                )
                .scaleEffect(hovering ? 1.12 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { hovering = h }
        }
    }
}

struct CornerButton: View {
    let systemName: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(hovering ? 1 : 0.7))
                .frame(width: 24, height: 24)
                .background(Circle().fill(.black.opacity(hovering ? 0.55 : 0.35)))
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering = $0 }
    }
}

// MARK: - Equalizer bars

struct EqualizerBars: View {
    let playing: Bool
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    let phase = Double(i) * 0.9
                    let speed = 2.2 + Double(i) * 0.45
                    let height: CGFloat = playing
                        ? 5 + 15 * abs(sin(t * speed + phase))
                        : 4
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: 4, height: height)
                        .animation(.easeOut(duration: 0.3), value: playing)
                }
            }
        }
        .frame(width: 32, height: 22, alignment: .bottom)
    }
}

// MARK: - Marquee for long titles

struct MarqueeText: View {
    let text: String
    let font: Font

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var animate = false

    private var overflow: Bool { textWidth > containerWidth + 1 }

    var body: some View {
        GeometryReader { geo in
            let label = Text(text).font(font).lineLimit(1).fixedSize()

            label
                .background(
                    GeometryReader { textGeo in
                        Color.clear.onAppear { textWidth = textGeo.size.width }
                            .onChange(of: text) { _ in textWidth = textGeo.size.width }
                    }
                )
                .offset(x: animate && overflow ? -(textWidth - containerWidth) : 0)
                .animation(
                    overflow
                        ? .linear(duration: Double(max(textWidth - containerWidth, 1)) / 28)
                            .delay(1.2)
                            .repeatForever(autoreverses: true)
                        : .default,
                    value: animate
                )
                .onAppear {
                    containerWidth = geo.size.width
                    animate = true
                }
                .onChange(of: geo.size.width) { containerWidth = $0 }
                .onChange(of: text) { _ in
                    animate = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { animate = true }
                }
        }
        .frame(height: fontLineHeight)
        .clipped()
    }

    private var fontLineHeight: CGFloat { 22 }
}

// MARK: - System blur (NSVisualEffectView)

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
