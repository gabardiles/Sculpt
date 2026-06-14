import UIKit

/// Small, tasteful haptics for the moments that earn them — the sage
/// completion check, a new PB, a friend's cheer. Mirrors the web's micro-
/// animations (heart-pop, check-draw) with feedback you can feel.
enum Haptics {
    /// A workout / set marked done — a soft success tap.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    /// A new personal best — the biggest moment, a heavier double.
    static func celebrate() {
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { gen.impactOccurred(intensity: 0.8) }
    }
    /// A cheer / light interaction — the heart-pop.
    static func pop() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    /// Selection moved (phase pill, theme switch).
    static func select() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
