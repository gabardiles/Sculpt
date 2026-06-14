import SwiftUI

/// A tiny line chart — Swift version of src/components/weight/Sparkline.tsx.
struct Sparkline: View {
    var values: [Double]
    var height: CGFloat = 36
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let lo = values.min() ?? 0
            let hi = values.max() ?? 1
            let span = hi - lo
            Path { p in
                guard values.count >= 2 else { return }
                for (i, v) in values.enumerated() {
                    let x = w * CGFloat(i) / CGFloat(values.count - 1)
                    let norm = span == 0 ? 0.5 : (v - lo) / span
                    let y = h - CGFloat(norm) * h
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(palette.blushDeep, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .frame(height: height)
    }
}
