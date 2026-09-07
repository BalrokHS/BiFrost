import SwiftUI

/// A restrained atmospheric canvas behind the glass. The light follows the
/// connected profile palette, but stays dim enough for long working sessions.
struct AmbientBackdrop: View {
    let accent: Color
    let secondary: Color
    var intensity: Double = 1

    var body: some View {
        ZStack {
            Theme.Palette.canvasDeep

            RadialGradient(
                colors: [accent.opacity(0.16 * intensity), .clear],
                center: .topTrailing,
                startRadius: 12,
                endRadius: 560
            )

            RadialGradient(
                colors: [secondary.opacity(0.09 * intensity), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 500
            )

            LinearGradient(
                colors: [Color.white.opacity(0.018), .clear, Color.black.opacity(0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Surfaces

extension View {
    /// A floating, interactive surface: Liquid Glass plus a lit rim so the
    /// panel keeps an edge against the very dark backdrop, which glass alone
    /// does not give you.
    func glassCard(
        radius: CGFloat = Theme.Radius.card,
        tint: Color? = nil,
        interactive: Bool = true
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return glassEffect(
            interactive ? .regular.tint(tint).interactive() : .regular.tint(tint),
            in: shape
        )
        .overlay(shape.strokeBorder(Theme.Palette.rim, lineWidth: 1))
    }

    /// A matte surface for content that sits still — settings sections, rows.
    /// Cheaper than glass and quieter next to it.
    func mattePanel(
        radius: CGFloat = Theme.Radius.panel,
        fill: Color = Theme.Palette.surface,
        stroked: Bool = true
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background(shape.fill(fill))
            .overlay(shape.strokeBorder(stroked ? Theme.Palette.hairline : .clear, lineWidth: 1))
    }

    /// Fades the view in from below. Used to stagger content on first paint.
    func appearLift(_ delay: Double) -> some View {
        modifier(AppearLift(delay: delay))
    }
}

private struct AppearLift: ViewModifier {
    let delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 10)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.9).delay(delay)) {
                    shown = true
                }
            }
    }
}

// MARK: - Text

/// Small tracked capitals that title a region without competing with it.
struct Eyebrow: View {
    let text: String
    var tone: Color = Theme.Palette.textTertiary

    init(_ text: String, tone: Color = Theme.Palette.textTertiary) {
        self.text = text
        self.tone = tone
    }

    var body: some View {
        Text(text.uppercased())
            .font(.eyebrow)
            .tracking(1.2)
            .foregroundStyle(tone)
    }
}

/// A region title with an optional count, sitting above a group of cards.
struct SectionHeading: View {
    let title: String
    var count: Int?

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.panelTitle)
                .foregroundStyle(Theme.Palette.textPrimary)

            if let count {
                Text("\(count)")
                    .font(.readoutSmall)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.Palette.surface))
                    .overlay(Capsule().strokeBorder(Theme.Palette.hairline, lineWidth: 1))
            }

            Rectangle()
                .fill(Theme.Palette.hairline)
                .frame(height: 1)
        }
    }
}

// MARK: - Status

/// The connection light. Breathes while a tunnel is up or in transition, and
/// sits perfectly still otherwise, so idle profiles never pull the eye.
struct StatusDot: View {
    let state: ConnectionState
    var size: CGFloat = 7

    @State private var expanded = false

    var body: some View {
        Circle()
            .fill(state.tone)
            .frame(width: size, height: size)
            .shadow(color: state.tone.opacity(state == .disconnected ? 0 : 0.7), radius: size * 0.8)
            .background {
                if state.animatesIndicator {
                    Circle()
                        .stroke(state.tone.opacity(0.55), lineWidth: 1)
                        .frame(width: size, height: size)
                        .scaleEffect(expanded ? 3.1 : 1)
                        .opacity(expanded ? 0 : 0.9)
                }
            }
            .task(id: state) {
                expanded = false
                guard state.animatesIndicator else { return }
                withAnimation(.easeOut(duration: 1.9).repeatForever(autoreverses: false)) {
                    expanded = true
                }
            }
    }
}

/// Dot plus label in a tinted capsule. The app's single way of saying what a
/// connection is doing.
struct StatusPill: View {
    let state: ConnectionState
    var compact = false

    var body: some View {
        HStack(spacing: 6) {
            StatusDot(state: state, size: compact ? 6 : 7)
            Text(state.shortLabel)
                .font(.system(size: compact ? 10.5 : 11.5, weight: .medium))
                .foregroundStyle(state.tone)
                .fixedSize()
        }
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 3 : 4.5)
        .background(Capsule().fill(state.tone.opacity(0.13)))
        .overlay(Capsule().strokeBorder(state.tone.opacity(0.24), lineWidth: 1))
    }
}

// MARK: - Glyphs

/// A provider or feature glyph in a gradient-lit squircle.
struct IconBadge: View {
    let symbol: String
    var tint: Color = Theme.Palette.brand
    var highlight: Color?
    var size: CGFloat = 38

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(
                LinearGradient(
                    colors: [highlight ?? tint, tint],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size, height: size)
            .background(
                shape.fill(
                    LinearGradient(
                        colors: [tint.opacity(0.24), tint.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .overlay(shape.strokeBorder(tint.opacity(0.28), lineWidth: 1))
            .shadow(color: tint.opacity(0.22), radius: 8, y: 3)
    }
}

// MARK: - Readouts

/// A label/value pair. Values are monospaced so hostnames, interface names and
/// timers stay aligned down the column and do not jitter as they update.
struct MetricRow<Value: View>: View {
    let label: String
    var tone: Color = Theme.Palette.textSecondary
    var symbol: String?
    var labelWidth: CGFloat = 66
    @ViewBuilder var value: () -> Value

    init(
        label: String,
        tone: Color = Theme.Palette.textSecondary,
        symbol: String? = nil,
        labelWidth: CGFloat = 66,
        @ViewBuilder value: @escaping () -> Value
    ) {
        self.label = label
        self.tone = tone
        self.symbol = symbol
        self.labelWidth = labelWidth
        self.value = value
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption11)
                .foregroundStyle(Theme.Palette.textTertiary)
                .frame(width: labelWidth, alignment: .leading)

            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tone.opacity(0.8))
                    .frame(width: 12)
            }

            value()
                .font(.readout)
                .foregroundStyle(tone)
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
    }
}

extension MetricRow where Value == Text {
    init(
        label: String,
        value: String,
        tone: Color = Theme.Palette.textSecondary,
        symbol: String? = nil,
        labelWidth: CGFloat = 66
    ) {
        self.init(label: label, tone: tone, symbol: symbol, labelWidth: labelWidth) {
            Text(value)
        }
    }
}

/// A running `hh:mm:ss` counter since a fixed instant.
struct ElapsedTime: View {
    let since: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(Self.formatted(context.date.timeIntervalSince(since)))
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

/// The one call to action in a region: filled, tinted, and lit from behind.
struct AccentActionStyle: ButtonStyle {
    var tint: Color = Theme.Palette.brand
    var filled = true
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, tint: tint, filled: filled, compact: compact)
    }

    private struct StyleBody: View {
        let configuration: ButtonStyleConfiguration
        let tint: Color
        let filled: Bool
        let compact: Bool

        @State private var hovering = false

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            configuration.label
                .font(.system(size: compact ? 11.5 : 12.5, weight: .semibold))
                .foregroundStyle(filled ? .white : tint)
                .padding(.horizontal, compact ? 11 : 14)
                .padding(.vertical, compact ? 6 : 8)
                .background {
                    if filled {
                        shape.fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(hovering ? 1 : 0.94),
                                    tint.opacity(hovering ? 0.88 : 0.78)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    } else {
                        shape.fill(tint.opacity(hovering ? 0.20 : 0.12))
                    }
                }
                .overlay(
                    shape.strokeBorder(
                        filled ? .white.opacity(0.22) : tint.opacity(0.30),
                        lineWidth: 1
                    )
                )
                .shadow(
                    color: filled ? tint.opacity(hovering ? 0.45 : 0.26) : .clear,
                    radius: hovering ? 13 : 8,
                    y: 3
                )
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(Theme.Motion.hover, value: hovering)
                .animation(Theme.Motion.press, value: configuration.isPressed)
                .onHover { hovering = $0 }
        }
    }
}

/// Everything that is not the call to action.
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
            if destructive { return Color(hex: 0xF2565B) }
            return hovering ? Theme.Palette.textPrimary : Theme.Palette.textSecondary
        }

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            configuration.label
                .font(.system(size: compact ? 11.5 : 12.5, weight: .medium))
                .foregroundStyle(foreground)
                .padding(.horizontal, compact ? 10 : 13)
                .padding(.vertical, compact ? 6 : 8)
                .background(
                    shape.fill(
                        destructive
                            ? Color(hex: 0xF2565B).opacity(hovering ? 0.16 : 0.09)
                            : (hovering ? Theme.Palette.surfaceHover : Theme.Palette.surface)
                    )
                )
                .overlay(
                    shape.strokeBorder(
                        destructive ? Color(hex: 0xF2565B).opacity(0.28) : Theme.Palette.hairline,
                        lineWidth: 1
                    )
                )
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(Theme.Motion.hover, value: hovering)
                .animation(Theme.Motion.press, value: configuration.isPressed)
                .onHover { hovering = $0 }
        }
    }
}

/// A square, icon-only control for secondary affordances on a card.
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
            let shape = RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
            configuration.label
                .labelStyle(.iconOnly)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(hovering ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                .frame(width: size, height: size)
                .background(shape.fill(hovering ? Theme.Palette.surfaceHover : Theme.Palette.surface))
                .overlay(shape.strokeBorder(Theme.Palette.hairline, lineWidth: 1))
                .scaleEffect(configuration.isPressed ? 0.94 : 1)
                .animation(Theme.Motion.hover, value: hovering)
                .animation(Theme.Motion.press, value: configuration.isPressed)
                .onHover { hovering = $0 }
        }
    }
}

extension ButtonStyle where Self == AccentActionStyle {
    static func accent(_ tint: Color, filled: Bool = true, compact: Bool = false) -> Self {
        AccentActionStyle(tint: tint, filled: filled, compact: compact)
    }

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
/// than from `Form`, whose grouped background fights the ambient backdrop.
struct SettingsCard<Content: View>: View {
    let title: String
    var symbol: String?
    var tint: Color = Theme.Palette.brand
    var spacing: CGFloat = 14
    @ViewBuilder var content: () -> Content

    init(
        _ title: String,
        symbol: String? = nil,
        tint: Color = Theme.Palette.brand,
        spacing: CGFloat = 14,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                if let symbol {
                    IconBadge(symbol: symbol, tint: tint, size: 26)
                }
                Text(title)
                    .font(.panelTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.top, 15)
            .padding(.bottom, 13)

            Rectangle()
                .fill(Theme.Palette.hairline)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: spacing) {
                content()
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    /// Input chrome: a recessed well rather than a raised control, so fields
    /// read as holes cut into the panel.
    func fieldChrome(focused: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
        return font(.body13)
            .foregroundStyle(Theme.Palette.textPrimary)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(shape.fill(Theme.Palette.canvasDeep.opacity(0.55)))
            .overlay(
                shape.strokeBorder(
                    focused ? Theme.Palette.brand.opacity(0.7) : Theme.Palette.hairlineBright,
                    lineWidth: 1
                )
            )
            .animation(Theme.Motion.hover, value: focused)
    }
}
