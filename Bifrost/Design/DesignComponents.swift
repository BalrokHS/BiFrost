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

/// A provider glyph in a flat square. Grey until `tint` is given.
struct IconBadge: View {
    let symbol: String
    var tint: Color = Theme.Palette.textSecondary
    var size: CGFloat = 28

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(shape.fill(Theme.Palette.surfaceRaised))
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
