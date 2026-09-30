import SwiftUI

/// Shared visual language for the macOS app. The palette is intentionally
/// quiet; hierarchy comes from translucency, fine rims and small temperature
/// shifts rather than bright blocks of colour.
enum Theme {
    enum Palette {
        static let canvasDeep = Color(hex: 0x05070A)
        static let canvas = Color(hex: 0x090C12)
        static let sidebar = Color(hex: 0x080A0F)

        static let surface = Color.white.opacity(0.045)
        static let surfaceRaised = Color.white.opacity(0.072)
        static let surfaceHover = Color.white.opacity(0.092)
        static let surfaceActive = Color.white.opacity(0.13)
        static let well = Color.black.opacity(0.28)

        static let hairline = Color.white.opacity(0.075)
        static let hairlineBright = Color.white.opacity(0.13)
        static let rim = Color.white.opacity(0.16)

        static let border = hairline
        static let borderStrong = hairlineBright

        static let textPrimary = Color(hex: 0xF4F6FA)
        static let textSecondary = Color(hex: 0xA5ABB7)
        static let textTertiary = Color(hex: 0x69717F)

        static let brand = Color(hex: 0x596BFF)
        static let brandBright = Color(hex: 0x00D5F2)
        static let brandHover = Color(hex: 0x7280FF)
        static let danger = Color(hex: 0xF05D68)
    }

    enum Radius {
        static let control: CGFloat = 8
        static let row: CGFloat = 10
        static let panel: CGFloat = 12
        static let card: CGFloat = 16
        static let sheet: CGFloat = 18
    }

    enum Metrics {
        static let headerHeight: CGFloat = 52
        static let gutter: CGFloat = 24
    }

    enum Motion {
        static let hover = Animation.easeOut(duration: 0.14)
        static let press = Animation.easeOut(duration: 0.09)
        static let state = Animation.spring(response: 0.34, dampingFraction: 0.86)
        static let ambient = Animation.easeInOut(duration: 0.7)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension ConnectionState {
    var tone: Color {
        switch self {
        case .connected: Color(hex: 0x52D49A)
        case .connecting, .disconnecting, .waitingForAuthentication: Color(hex: 0xF0B85B)
        case .degraded: Color(hex: 0xE8CE63)
        case .failed: Theme.Palette.danger
        case .disconnected: Color(hex: 0x5C6470)
        }
    }

    var shortLabel: String {
        switch self {
        case .waitingForAuthentication: "Auth needed"
        default: rawValue
        }
    }

    var animatesIndicator: Bool {
        switch self {
        case .connected, .connecting, .disconnecting, .waitingForAuthentication: true
        case .degraded, .failed, .disconnected: false
        }
    }
}

extension ProfileAccent {
    var tint: Color {
        switch self {
        case .blue: Color(hex: 0x5CB5FF)
        case .purple: Color(hex: 0x9185FF)
        case .teal: Color(hex: 0x45CFBA)
        case .orange: Color(hex: 0xF3A15A)
        case .pink: Color(hex: 0xEE88BE)
        }
    }

    var highlight: Color { tint.opacity(0.95) }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [highlight, tint.opacity(0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Font {
    static let heroTitle = Font.system(size: 30, weight: .semibold, design: .rounded)
    static let panelTitle = Font.system(size: 13, weight: .semibold)
    static let cardTitle = Font.system(size: 15, weight: .semibold)
    static let rowTitle = Font.system(size: 12.5, weight: .medium)
    static let body13 = Font.system(size: 13, weight: .regular)
    static let caption12 = Font.system(size: 12, weight: .regular)
    static let caption11 = Font.system(size: 11, weight: .regular)
    static let eyebrow = Font.system(size: 10, weight: .semibold)
    static let readout = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let readoutSmall = Font.system(size: 10.5, weight: .regular, design: .monospaced)

    static let uiTitle = panelTitle
    static let uiSectionLabel = caption12
    static let uiLabel = rowTitle
    static let uiBody = body13
    static let uiSecondary = caption12
    static let uiMeta = caption11
    static let uiMono = readout
    static let uiMonoSmall = readoutSmall
}
