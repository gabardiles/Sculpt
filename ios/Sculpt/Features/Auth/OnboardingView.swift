import SwiftUI

/// First-run setup — mirrors /onboarding. A few details set the suggested
/// program and theme (men → Spartan + Strong & Built; women/unspecified →
/// Sculpt + Lean & Sculpted). Everything is changeable later.
struct OnboardingView: View {
    let userId: String
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.palette) private var palette

    @State private var name = ""
    @State private var gender: Gender? = nil
    @State private var age = ""
    @State private var height = ""
    @State private var weight = ""
    @State private var busy = false

    var body: some View {
        ZStack {
            SculptBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(spacing: 8) {
                        Eyebrow("Welcome")
                        Text("Let's get you set up").font(.sans(28, weight: .light)).tracking(1)
                        Text("A few quick details — we'll suggest a program and a look that fit you.")
                            .font(.sans(14, weight: .light)).foregroundStyle(palette.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)

                    GlassCard {
                        VStack(alignment: .leading, spacing: 18) {
                            field("Your name") {
                                TextField("Alex", text: $name).fieldStyle(palette)
                            }
                            field("You train as") {
                                VStack(spacing: 8) {
                                    genderRow(.female, "Woman — lean & toned")
                                    genderRow(.male, "Man — athletic & strong")
                                    genderRow(.unspecified, "Prefer not to say")
                                }
                            }
                            HStack(spacing: 10) {
                                field("Age") {
                                    TextField("28", text: $age).keyboardType(.numberPad).fieldStyle(palette)
                                }
                                field("Height (cm)") {
                                    TextField("175", text: $height).keyboardType(.decimalPad).fieldStyle(palette)
                                }
                                field("Weight") {
                                    TextField("70", text: $weight).keyboardType(.decimalPad).fieldStyle(palette)
                                }
                            }
                            PillButton(title: busy ? "Building…" : "Build my program") {
                                Task { await submit() }
                            }
                            .disabled(busy || name.isEmpty || gender == nil)
                        }
                        .padding(20)
                    }
                }
                .padding(24)
            }
        }
    }

    @ViewBuilder private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) { Eyebrow(label); content() }
    }

    private func genderRow(_ g: Gender, _ label: String) -> some View {
        Button { gender = g } label: {
            HStack {
                Text(label).font(.sans(15, weight: .light))
                Spacer()
                if gender == g { Image(systemName: "checkmark").foregroundStyle(palette.blushDeep) }
            }
            .padding(.vertical, 12).padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(gender == g ? palette.blush.opacity(0.3) : palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.edge))
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.ink)
    }

    private func submit() async {
        guard let gender else { return }
        busy = true
        let input = Repository.OnboardingInput(
            name: name.trimmingCharacters(in: .whitespaces),
            gender: gender,
            age: Int(age),
            heightCm: Double(height.replacingOccurrences(of: ",", with: ".")),
            weightKg: Double(weight.replacingOccurrences(of: ",", with: "."))
        )
        let newTheme = try? await Repository.shared.completeOnboarding(userId: userId, input: input)
        if let newTheme { theme.theme = newTheme }
        await session.loadProfile(userId: userId)
        busy = false
    }
}
