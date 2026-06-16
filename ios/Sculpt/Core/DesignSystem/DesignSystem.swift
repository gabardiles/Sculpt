import SwiftUI

// Reusable building blocks — Swift equivalents of src/components/ui/*.
// The Alo Yoga aesthetic: glass cards, soft blush, mono numerals.
//
// Typography note: the web app uses Geist Sans + Geist Mono. We default to the
// system font (SF Pro) and a monospaced design for "every number is mono". To
// match exactly, drop Geist .ttf files into Resources/, register them in
// Info.plist (UIAppFonts), and swap the helpers below.

extension Font {
    /// Monospaced — used for every number, per the design system.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

/// Mono numerals — `<MonoNumber>` in the web app.
struct MonoText: View {
    let text: String
    var size: CGFloat = 17
    var weight: Font.Weight = .regular
    init(_ text: String, size: CGFloat = 17, weight: Font.Weight = .regular) {
        self.text = text; self.size = size; self.weight = weight
    }
    var body: some View {
        Text(text).font(.mono(size, weight: weight))
    }
}

/// Uppercase, letter-spaced label — the `.eyebrow` class.
struct Eyebrow: View {
    let text: String
    @Environment(\.palette) private var palette
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.mono(12))
            .tracking(1.7)
            .foregroundStyle(palette.inkSoft)
    }
}

/// Frosted-glass card — the `.glass` / `.glass-done` classes.
struct GlassCard<Content: View>: View {
    enum Style { case normal, done, spotlight }
    var style: Style = .normal
    @ViewBuilder var content: () -> Content
    @Environment(\.palette) private var palette

    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(fill)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(border, lineWidth: style == .spotlight ? 2 : 1)
            )
            .shadow(color: shadowColor, radius: style == .spotlight ? 18 : 16, x: 0, y: 8)
    }

    private var fill: Color {
        switch style {
        case .normal: return palette.glass
        case .done: return palette.doneFill
        case .spotlight: return palette.isDark ? palette.blush.opacity(0.10) : palette.glass
        }
    }
    private var border: Color {
        switch style {
        case .normal: return palette.edge
        case .done: return palette.doneEdge
        case .spotlight: return palette.blushDeep
        }
    }
    private var shadowColor: Color {
        if style == .spotlight { return palette.blushDeep.opacity(0.3) }
        return palette.isDark ? .black.opacity(0.5) : Color(hex: "2B2422").opacity(0.06)
    }
}

/// Animated "ghost loader" — a soft shimmer over `surfaceSoft`. Used as the
/// placeholder while async images load so cells fade in instead of blinking.
struct Shimmer: View {
    @Environment(\.palette) private var palette
    @State private var animating = false

    var body: some View {
        palette.surfaceSoft
            .overlay {
                GeometryReader { geo in
                    let highlight = palette.isDark ? Color.white.opacity(0.06)
                                                   : Color.white.opacity(0.55)
                    LinearGradient(colors: [.clear, highlight, .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.7)
                        .offset(x: animating ? geo.size.width * 1.3 : -geo.size.width * 1.3)
                }
            }
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    animating = true
                }
            }
    }
}

/// Pill-shaped button — the `PillButton` component.
struct PillButton: View {
    enum Kind { case accent, ghost, sage }
    let title: String
    var kind: Kind = .accent
    var fullWidth: Bool = true
    var icon: String? = nil
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title).font(.sans(16, weight: .medium))
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 14)
            .padding(.horizontal, 22)
            .foregroundStyle(fg)
            .background(Capsule().fill(bg))
            .overlay(Capsule().strokeBorder(border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var bg: Color {
        switch kind {
        case .accent: return palette.blush
        case .ghost: return palette.surface
        case .sage: return palette.sage.opacity(0.4)
        }
    }
    private var fg: Color {
        switch kind {
        case .accent: return palette.onAccent
        case .ghost, .sage: return palette.ink
        }
    }
    private var border: Color {
        kind == .ghost ? palette.edge : .clear
    }
}

/// Circular progress — the `ProgressRing` component.
struct ProgressRing: View {
    var progress: Double         // 0..1
    var size: CGFloat = 64
    var lineWidth: CGFloat = 6
    var label: String? = nil
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            Circle().stroke(palette.edge, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(palette.blushDeep, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: progress)
            if let label {
                Text(label).font(.mono(13, weight: .medium)).foregroundStyle(palette.ink)
            }
        }
        .frame(width: size, height: size)
    }
}

/// The warm app-shell background — radial blush glow at the top.
struct SculptBackground: View {
    @Environment(\.palette) private var palette
    var body: some View {
        ZStack {
            palette.bg
            if palette.isDark {
                RadialGradient(
                    colors: [palette.blush.opacity(0.06), .clear],
                    center: .top, startRadius: 0, endRadius: 320
                )
            } else {
                LinearGradient(
                    colors: [palette.blush.opacity(0.55), palette.blush.opacity(0.12), .clear],
                    startPoint: .topLeading, endPoint: .bottom
                )
                .frame(height: 360)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .ignoresSafeArea()
    }
}

/// Convenience: a screen scaffold with the themed background + scrolling body.
struct Screen<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: () -> Content
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            SculptBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let title {
                        Text(title).font(.sans(28, weight: .light)).tracking(1)
                            .foregroundStyle(palette.ink)
                    }
                    content()
                }
                .padding(20)
                .padding(.bottom, 90) // clears the tab bar
            }
        }
        .foregroundStyle(palette.ink)
    }
}
