import SwiftUI

/// The You tab — profile hub, appearance, navigation to Weight / Photos / Goals,
/// the "how it works" reader, app version and sign out.
/// Mirrors src/app/(app)/you/page.tsx.
struct YouView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.palette) private var palette

    private var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "—"
    }

    var body: some View {
        ZStack {
            SculptBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    sections
                    appearance
                    learn
                    account
                    footer
                }
                .padding(20)
                .padding(.bottom, 90) // clears the tab bar
            }
        }
        .foregroundStyle(palette.ink)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow("You")
            Text(session.profile?.name ?? "Your space")
                .font(.sans(28, weight: .light)).tracking(0.5)
            if let code = session.profile?.friendCode, !code.isEmpty {
                MonoText("Friend code · \(code)", size: 12)
                    .tracking(1.4)
                    .foregroundStyle(palette.inkSoft)
            }
        }
    }

    // MARK: - Feature links

    private var sections: some View {
        VStack(spacing: 8) {
            NavigationLink { WeightView() } label: {
                row(icon: "chart.line.uptrend.xyaxis", title: "Weight diary")
            }
            .buttonStyle(.plain)

            NavigationLink { PhotosView() } label: {
                row(icon: "camera", title: "Progress photos")
            }
            .buttonStyle(.plain)

            NavigationLink { GoalsView() } label: {
                row(icon: "target", title: "Goals")
            }
            .buttonStyle(.plain)
        }
    }

    private func row(icon: String, title: String) -> some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(palette.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(palette.blush.opacity(0.3)))
                Text(title).font(.sans(16, weight: .light))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.inkSoft)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Appearance

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Appearance")
            HStack(spacing: 8) {
                themeButton(.sculpt, label: "Sculpt")
                themeButton(.spartan, label: "Spartan")
            }
        }
    }

    private func themeButton(_ value: AppTheme, label: String) -> some View {
        let selected = theme.theme == value
        return Button {
            guard !selected else { return }
            select(value)
        } label: {
            Text(label)
                .font(.sans(15, weight: selected ? .medium : .light))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(selected ? palette.ink : palette.inkSoft)
                .background(
                    Capsule().fill(selected ? palette.blush.opacity(0.4) : palette.surfaceSoft)
                )
                .overlay(
                    Capsule().strokeBorder(
                        selected ? palette.blushDeep : palette.edge,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }

    /// Switch the look instantly, then persist for this user.
    private func select(_ value: AppTheme) {
        theme.theme = value
        Task {
            if let uid = await Repository.shared.currentUserId() {
                try? await Repository.shared.setTheme(userId: uid, theme: value)
            }
        }
    }

    // MARK: - Learn

    private var learn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Learn")
            NavigationLink { HowItWorksView() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "book")
                        .font(.system(size: 15))
                    Text("How Sculpt works")
                        .font(.sans(15, weight: .light))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.inkSoft.opacity(0.6))
                }
                .foregroundStyle(palette.inkSoft)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Account

    private var account: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Account")
            if session.profile?.isAdmin == true {
                NavigationLink { InviteView() } label: {
                    row(icon: "person.badge.plus", title: "Invite someone")
                }
                .buttonStyle(.plain)
            }
            PillButton(title: "Sign out", kind: .ghost, icon: "rectangle.portrait.and.arrow.right") {
                Task { await session.signOut() }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        MonoText("Sculpt · v\(appVersion)", size: 11)
            .tracking(1.2)
            .foregroundStyle(palette.inkSoft.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
