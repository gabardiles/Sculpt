import SwiftUI

// Design tokens ported from src/app/globals.css. The web app swaps CSS
// variables between two themes; here a Palette struct carries the same values
// and ThemeManager publishes the active one.

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        let r, g, b: Double
        if h.count == 6 {
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
        } else { r = 0; g = 0; b = 0 }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

struct Palette {
    let bg: Color
    let blush: Color
    let blushDeep: Color
    let ink: Color
    let inkSoft: Color
    let sage: Color
    let sageDeep: Color
    let onAccent: Color
    let glass: Color
    let surface: Color
    let surfaceStrong: Color
    let surfaceSoft: Color
    let edge: Color
    /// Tint behind a completed card (glass-done).
    let doneFill: Color
    let doneEdge: Color
    /// Dark surfaces want light glass borders; light surfaces want white.
    let isDark: Bool

    static let sculpt = Palette(
        bg: Color(hex: "FBF7F6"),
        blush: Color(hex: "E8C8C4"),
        blushDeep: Color(hex: "B97D77"),
        ink: Color(hex: "2B2422"),
        inkSoft: Color(hex: "6F635E"),
        sage: Color(hex: "A9BCA4"),
        sageDeep: Color(hex: "5F7A58"),
        onAccent: Color(hex: "2B2422"),
        glass: Color.white.opacity(0.55),
        surface: Color.white.opacity(0.60),
        surfaceStrong: Color.white.opacity(0.88),
        surfaceSoft: Color.white.opacity(0.45),
        edge: Color.white.opacity(0.65),
        doneFill: Color(hex: "A9BCA4").opacity(0.35),
        doneEdge: Color(hex: "A9BCA4").opacity(0.40),
        isDark: false
    )

    static let spartan = Palette(
        bg: Color(hex: "141414"),
        blush: Color(hex: "F08226"),
        blushDeep: Color(hex: "FB9D3F"),
        ink: Color(hex: "F0EFED"),
        inkSoft: Color(hex: "9B9892"),
        sage: Color(hex: "5D7355"),
        sageDeep: Color(hex: "A8C49B"),
        onAccent: Color(hex: "171411"),
        glass: Color.white.opacity(0.05),
        surface: Color.white.opacity(0.07),
        surfaceStrong: Color(hex: "181818").opacity(0.92),
        surfaceSoft: Color.white.opacity(0.045),
        edge: Color.white.opacity(0.09),
        doneFill: Color(hex: "5F7A58").opacity(0.22),
        doneEdge: Color(hex: "5F7A58").opacity(0.35),
        isDark: true
    )

    static func of(_ theme: AppTheme) -> Palette {
        theme == .spartan ? .spartan : .sculpt
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    @Published var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "sculpt-theme") }
    }
    var palette: Palette { Palette.of(theme) }

    init() {
        let stored = UserDefaults.standard.string(forKey: "sculpt-theme")
        theme = AppTheme(rawValue: stored ?? "sculpt") ?? .sculpt
    }
}

// Read the active palette anywhere via @Environment(\.palette).
private struct PaletteKey: EnvironmentKey {
    static let defaultValue: Palette = .sculpt
}
extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
