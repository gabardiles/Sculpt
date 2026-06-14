import SwiftUI

/// "How Sculpt works" — a quiet reader for ProgramCopy.howItWorks plus the
/// swapping rationale. Mirrors src/app/(app)/you/how-it-works/page.tsx.
/// Pushed onto the parent NavigationStack, so the back button is the system one.
struct HowItWorksView: View {
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            SculptBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("The method")
                        Text("How Sculpt works")
                            .font(.sans(28, weight: .light)).tracking(0.5)
                        Text("Nothing here is random. The program was designed and audited against current evidence on how muscle is actually built.")
                            .font(.sans(14, weight: .light))
                            .foregroundStyle(palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(ProgramCopy.howItWorks) { item in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title).font(.sans(16, weight: .regular))
                                Text(item.body)
                                    .font(.sans(14, weight: .light))
                                    .foregroundStyle(palette.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(18)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Swapping exercises")
                        GlassCard {
                            Text(ProgramCopy.whySwaps)
                                .font(.sans(14, weight: .light))
                                .foregroundStyle(palette.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(18)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(20)
                .padding(.bottom, 90)
            }
        }
        .foregroundStyle(palette.ink)
        .navigationBarTitleDisplayMode(.inline)
    }
}
