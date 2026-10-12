import SwiftUI

// MARK: - Brand

/// The Bifrost mark and wordmark, from the trimmed brand artwork. The only
/// full-colour element in the app, so it is the one thing that reads as brand.
struct BrandLockup: View {
    var height: CGFloat = 28

    var body: some View {
        Image("BifrostFullLogo")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Bifrost")
    }
}

/// The mark alone, trimmed to its content, for tight spots and empty states.
struct BrandMark: View {
    var height: CGFloat = 24

    var body: some View {
        Image("BifrostMark")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityHidden(true)
    }
}

// MARK: - Surfaces

extension View {
    /// A matte surface for content that sits still: settings sections, the
    /// profile list. Flat fill, hairline edge, no shadow.
    func mattePanel(
        radius: CGFloat = Theme.Radius.panel,
        fill: Color = Theme.Palette.surface,
        stroked: Bool = true
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background(shape.fill(fill))
            .overlay(shape.strokeBorder(stroked ? Theme.Palette.hairline : .clear, lineWidth: 1))
    }
}

// MARK: - Status

/// The connection light: one small flat dot, still in every state.
struct StatusDot: View {
    let tone: Color
    var size: CGFloat = 7

    init(tone: Color, size: CGFloat = 7) {
        self.tone = tone
        self.size = size
    }

    init(state: ConnectionState, size: CGFloat = 7) {
        self.init(tone: state.tone, size: size)
    }

    var body: some View {
        Circle()
            .fill(tone)
            .frame(width: size, height: size)
    }
}

/// Dot plus grey label. The app's single way of saying what a connection or an
/// engine is doing; only the dot carries the status colour.
struct StatusLabel: View {
    let title: String
    let tone: Color

    init(title: String, tone: Color) {
        self.title = title
        self.tone = tone
    }

    init(state: ConnectionState) {
        self.init(title: state.shortLabel, tone: state.tone)
    }

    var body: some View {
        HStack(spacing: 6) {
            StatusDot(tone: tone, size: 6)
            Text(title)
                .font(.caption12)
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Glyphs


/// A profile's icon: an imported picture, a chosen symbol, or an avatar of
/// initials drawn from its name. Symbols and initials sit on a soft tint of the
/// profile's accent; a dot in the corner marks a connected profile.
struct ProfileAvatar: View {
    let name: String
    let icon: ProfileIcon
    var image: NSImage?
    var tint: Color = Theme.Palette.textSecondary
    var connected = false
    var size: CGFloat = 40

    var body: some View {
        let shape = Circle()
        Group {
            if icon == .image, let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(shape)
                    .overlay(shape.strokeBorder(Theme.Palette.hairlineBright, lineWidth: 1))
            } else if case .symbol(let name) = icon {
                Image(systemName: name)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: size, height: size)
                    .background(shape.fill(tint.opacity(0.16)))
            } else {
                Text(Self.initials(for: name))
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .frame(width: size, height: size)
                    .background(shape.fill(tint.opacity(0.16)))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if connected {
                Circle()
                    .fill(ConnectionState.connected.tone)
                    .frame(width: size * 0.24, height: size * 0.24)
                    .overlay(Circle().strokeBorder(Theme.Palette.canvas, lineWidth: 2))
                    .offset(x: -size * 0.03, y: -size * 0.03)
            }
        }
        .animation(Theme.Motion.state, value: connected)
        .accessibilityHidden(true)
    }

    /// First letters of the first two words, or the first two letters of a single word.
    static func initials(for name: String) -> String {
        let words = name.split { !$0.isLetter && !$0.isNumber }
        let letters: [Character]
        if words.count >= 2 {
            letters = words.prefix(2).compactMap(\.first)
        } else {
            letters = words.first.map { Array($0.prefix(2)) } ?? []
        }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

/// A numbered step that turns into a check once it is done.
struct StepMarker: View {
    let number: Int
    let done: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(done ? Theme.Palette.textSecondary : Theme.Palette.hairlineBright, lineWidth: 1)

            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
            } else {
                Text("\(number)")
                    .font(.system(size: 10.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .frame(width: 20, height: 20)
        .accessibilityLabel(done ? "Step \(number), done" : "Step \(number)")
    }
}

// MARK: - Readouts

/// A running `hh:mm:ss` counter since a fixed instant.
struct ElapsedTime: View {
    let since: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(Self.formatted(context.date.timeIntervalSince(since)))
                .monospacedDigit()
        }
    }

    static func formatted(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - Buttons

/// The one call to action in a region: a flat brand fill.
struct AccentActionStyle: ButtonStyle {
    var tint: Color = Theme.Palette.brand
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, tint: tint, compact: compact)
    }

    private struct StyleBody: View {
        let configuration: ButtonStyleConfiguration
        let tint: Color
        let compact: Bool

        @State private var hovering = false

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            configuration.label
                .font(.system(size: compact ? 11.5 : 12.5, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, compact ? 10 : 12)
                .frame(minHeight: compact ? 26 : 30)
                .background(shape.fill(hovering ? Theme.Palette.brandHover : tint))
                .contentShape(shape)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(Theme.Motion.hover, value: hovering)
                .animation(Theme.Motion.press, value: configuration.isPressed)
                .onHover { hovering = $0 }
        }
    }
}

/// Everything that is not the call to action: an outlined, transparent button.
struct QuietActionStyle: ButtonStyle {
    var compact = false
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, compact: compact, destructive: destructive)
    }

    private struct StyleBody: View {
        let configuration: ButtonStyleConfiguration
        let compact: Bool
        let destructive: Bool

        @State private var hovering = false

        private var foreground: Color {
            if destructive { return Theme.Palette.danger }
            return hovering ? Theme.Palette.textPrimary : Theme.Palette.textSecondary
        }

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            configuration.label
                .font(.system(size: compact ? 11.5 : 12.5, weight: .medium))
                .foregroundStyle(foreground)
                .padding(.horizontal, compact ? 9 : 11)
                .frame(minHeight: compact ? 26 : 30)
                .background(
                    shape.fill(
                        hovering
                            ? (destructive ? Theme.Palette.danger.opacity(0.12) : Theme.Palette.surfaceHover)
                            : .clear
                    )
                )
                .overlay(
                    shape.strokeBorder(
                        destructive ? Theme.Palette.danger.opacity(0.3) : Theme.Palette.hairlineBright,
                        lineWidth: 1
                    )
                )
                .contentShape(shape)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(Theme.Motion.hover, value: hovering)
                .animation(Theme.Motion.press, value: configuration.isPressed)
                .onHover { hovering = $0 }
        }
    }
}

/// A square, icon-only control for secondary affordances.
struct IconActionStyle: ButtonStyle {
    var size: CGFloat = 28

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, size: size)
    }

    private struct StyleBody: View {
        let configuration: ButtonStyleConfiguration
        let size: CGFloat

        @State private var hovering = false

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            configuration.label
                .labelStyle(.iconOnly)
                .font(.system(size: size * 0.46, weight: .medium))
                .foregroundStyle(hovering ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                .frame(width: size, height: size)
                .background(shape.fill(hovering ? Theme.Palette.surfaceHover : .clear))
                .contentShape(shape)
                .scaleEffect(configuration.isPressed ? 0.94 : 1)
                .animation(Theme.Motion.hover, value: hovering)
                .animation(Theme.Motion.press, value: configuration.isPressed)
                .onHover { hovering = $0 }
        }
    }
}

extension ButtonStyle where Self == AccentActionStyle {
    static func accent(_ tint: Color, compact: Bool = false) -> Self {
        AccentActionStyle(tint: tint, compact: compact)
    }

    static var accentCompact: Self { AccentActionStyle(compact: true) }

    static var accent: Self { AccentActionStyle() }
}

extension ButtonStyle where Self == QuietActionStyle {
    static var quiet: Self { QuietActionStyle() }
    static var quietCompact: Self { QuietActionStyle(compact: true) }
    static var quietDestructive: Self { QuietActionStyle(destructive: true) }
}

extension ButtonStyle where Self == IconActionStyle {
    static var iconAction: Self { IconActionStyle() }
    static func iconAction(size: CGFloat) -> Self { IconActionStyle(size: size) }
}

// MARK: - Settings layout

/// A titled panel. Settings and the profile editor are built from these rather
/// than from `Form`, whose grouped background does not match the flat canvas.
struct SettingsCard<Content: View>: View {
    let title: String
    var spacing: CGFloat?
    var dense = false
    var fillsHeight = false
    @ViewBuilder var content: () -> Content

    init(
        _ title: String,
        spacing: CGFloat? = nil,
        dense: Bool = false,
        fillsHeight: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.spacing = spacing
        self.dense = dense
        self.fillsHeight = fillsHeight
        self.content = content
    }

    private var inset: CGFloat { dense ? 12 : 14 }
    private var rowSpacing: CGFloat { spacing ?? 10 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.panelTitle)
                .foregroundStyle(Theme.Palette.textPrimary)
                .padding(.horizontal, inset)
                .frame(height: 36, alignment: .leading)

            HairlineRule()

            VStack(alignment: .leading, spacing: rowSpacing) {
                content()
            }
            .padding(inset)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: fillsHeight ? .infinity : nil,
            alignment: .topLeading
        )
        .mattePanel()
    }
}

/// A label on the left, a control on the right. The workhorse of both the
/// settings screen and the profile editor.
struct SettingsRow<Control: View>: View {
    let label: String
    var detail: String?
    @ViewBuilder var control: () -> Control

    init(_ label: String, detail: String? = nil, @ViewBuilder control: @escaping () -> Control) {
        self.label = label
        self.detail = detail
        self.control = control
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body13)
                    .foregroundStyle(Theme.Palette.textPrimary)
                if let detail {
                    Text(detail)
                        .font(.caption11)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            control()
        }
    }
}

/// Explanatory prose under a control. Quiet on purpose — it is there when you
/// go looking for it and invisible when you are not.
struct SettingsNote: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption11)
            .foregroundStyle(Theme.Palette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HairlineRule: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Palette.hairline)
            .frame(height: 1)
    }
}

extension View {
    /// Input chrome: a recessed well rather than a raised control.
    func fieldChrome(focused: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
        return font(.body13)
            .foregroundStyle(Theme.Palette.textPrimary)
            .padding(.horizontal, 10)
            .frame(minHeight: 30)
            .background(shape.fill(Theme.Palette.canvasDeep))
            .overlay(
                shape.strokeBorder(
                    focused ? Theme.Palette.brand : Theme.Palette.hairlineBright,
                    lineWidth: 1
                )
            )
            .animation(Theme.Motion.hover, value: focused)
    }
}

// MARK: - Connection waves

/// Slow colour waves along the bottom of the window, one layer per open
/// connection. Layers differ in height, speed and phase (derived from the
/// profile id, so they stay put between launches) and fade in and out as
/// connections start and stop. Idle, nothing is drawn.
struct ConnectionWaves: View {
    let profiles: [VPNProfile]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(profiles) { profile in
                WaveLayer(seed: profile.id, tint: profile.accent.tint, animated: !reduceMotion)
                    .transition(.opacity)
            }
        }
        .animation(Theme.Motion.state.speed(0.35), value: profiles.map(\.id))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct WaveLayer: View {
    let seed: UUID
    let tint: Color
    let animated: Bool

    var body: some View {
        let bytes = seed.uuid
        // Stable per-profile variation in 0...1.
        let a = Double(bytes.0) / 255
        let b = Double(bytes.1) / 255
        let c = Double(bytes.2) / 255

        TimelineView(.animation(minimumInterval: nil, paused: !animated)) { timeline in
            let t = animated ? timeline.date.timeIntervalSinceReferenceDate : 0
            Canvas { context, size in
                let baseline = size.height * (0.80 - 0.10 * a)
                let amplitude = size.height * (0.035 + 0.035 * b)
                let wavelength = size.width * (0.55 + 0.6 * c)
                let phase = t * (0.18 + 0.14 * a) * (b > 0.5 ? 1 : -1) + c * 6.28

                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height))
                var x: CGFloat = 0
                while x <= size.width + 8 {
                    let angle = Double(x / wavelength) * 2 * .pi + phase
                    // A second, slower harmonic keeps the crest from looking mechanical.
                    let y = baseline
                        + amplitude * sin(angle)
                        + amplitude * 0.45 * sin(angle * 0.5 + phase * 0.6)
                    path.addLine(to: CGPoint(x: x, y: y))
                    x += 8
                }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()

                context.fill(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [tint.opacity(0.16), tint.opacity(0)]),
                        startPoint: CGPoint(x: 0, y: baseline - amplitude),
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
            }
        }
    }
}
