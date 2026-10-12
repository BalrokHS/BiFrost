import SwiftUI

/// Shared visual language for the macOS app: one flat near-black canvas,
/// hairline dividers and small radii. Grey by default; the brand colour marks
/// the primary action and the current selection, status colour a single dot.
enum Theme {
    enum Palette {
        static let canvasDeep = Color(hex: 0x08090B)
        static let canvas = Color(hex: 0x0E0F12)
        static let sidebar = Color(hex: 0x0B0C0F)

        static let surface = Color.white.opacity(0.03)
        static let surfaceRaised = Color.white.opacity(0.05)
        static let surfaceHover = Color.white.opacity(0.06)
        static let surfaceActive = Color.white.opacity(0.09)

        static let hairline = Color.white.opacity(0.07)
        static let hairlineBright = Color.white.opacity(0.12)

        static let textPrimary = Color(hex: 0xF4F6FA)
        static let textSecondary = Color(hex: 0xA5ABB7)
        static let textTertiary = Color(hex: 0x69717F)

        static let brand = Color(hex: 0x596BFF)
        static let brandHover = Color(hex: 0x7280FF)
        static let danger = Color(hex: 0xF05D68)
    }

    enum Radius {
        static let control: CGFloat = 6
        static let panel: CGFloat = 8
    }

    enum Metrics {
        static let headerHeight: CGFloat = 44
        static let titleBarHeight: CGFloat = 28
        static let gutter: CGFloat = 20
    }

    enum Motion {
        static let hover = Animation.easeOut(duration: 0.1)
        static let press = Animation.easeOut(duration: 0.09)
        static let state = Animation.spring(response: 0.3, dampingFraction: 1)
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
}

extension Font {
    static let panelTitle = Font.system(size: 13, weight: .semibold)
    static let viewTitle = Font.system(size: 15, weight: .semibold)
    static let rowTitle = Font.system(size: 12.5, weight: .medium)
    static let body13 = Font.system(size: 13, weight: .regular)
    static let caption12 = Font.system(size: 12, weight: .regular)
    static let caption11 = Font.system(size: 11, weight: .regular)
}
