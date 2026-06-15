import WidgetKit
import SwiftUI

/// The widget extension's entry point. Bundles the home/lock-screen
/// "next session" widget and (on iOS 16.1+) the rest-timer Live Activity.
@main
struct SculptWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextSessionWidget()
        if #available(iOS 16.1, *) {
            RestLiveActivity()
        }
    }
}

/// Minimal, self-contained palette for the extension — it can't pull in the
/// app's design system, so the two brand looks are reproduced here.
enum WidgetPalette {
    static func bg(_ theme: String) -> Color { theme == "spartan" ? Color(hex: "141414") : Color(hex: "FBF7F6") }
    static func ink(_ theme: String) -> Color { theme == "spartan" ? Color(hex: "F0EFED") : Color(hex: "2B2422") }
    static func inkSoft(_ theme: String) -> Color { theme == "spartan" ? Color(hex: "9B9892") : Color(hex: "6F635E") }
    static func accent(_ theme: String) -> Color { theme == "spartan" ? Color(hex: "F08226") : Color(hex: "B97D77") }
    static func accentSoft(_ theme: String) -> Color { theme == "spartan" ? Color(hex: "F08226").opacity(0.18) : Color(hex: "E8C8C4") }
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0; Scanner(string: h).scanHexInt64(&v)
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255, opacity: 1)
    }
}
