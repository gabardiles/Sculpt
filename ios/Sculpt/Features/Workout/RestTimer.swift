import SwiftUI

/// A small countdown tag — Swift version of src/components/workout/RestTimer.tsx.
struct RestTimer: View {
    let until: Date
    let nextName: String?
    let onDismiss: () -> Void
    @Environment(\.palette) private var palette
    @State private var remaining = 0
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer")
            MonoText(format(remaining), size: 15, weight: .medium)
            if let nextName { Text("· next: \(nextName)").font(.sans(12, weight: .light)).lineLimit(1) }
            Button { onDismiss() } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)) }
        }
        .padding(.vertical, 8).padding(.horizontal, 14)
        .background(Capsule().fill(palette.surfaceStrong))
        .overlay(Capsule().strokeBorder(palette.edge))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .onReceive(tick) { _ in
            remaining = max(0, Int(until.timeIntervalSinceNow.rounded()))
            if remaining == 0 { onDismiss() }
        }
        .onAppear { remaining = max(0, Int(until.timeIntervalSinceNow.rounded())) }
    }

    private func format(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}
