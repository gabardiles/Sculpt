import SwiftUI

/// Top-level router — the Swift counterpart of src/middleware.ts + the (app)
/// layout. Signed-out → login, signed-in but un-onboarded → onboarding,
/// otherwise → the tab bar.
struct RootView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.palette) private var palette

    var body: some View {
        Group {
            switch session.phase {
            case .loading:
                ZStack { SculptBackground(); ProgressView().tint(palette.blushDeep) }
            case .signedOut:
                LoginView()
            case .onboarding(let userId):
                OnboardingView(userId: userId)
            case .ready(let profile):
                MainTabView()
                    .onAppear { syncTheme(profile.theme) }
                    .task { await setupNotifications() }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.phase)
    }

    private func syncTheme(_ remote: AppTheme?) {
        if let remote, remote != theme.theme { theme.theme = remote }
    }

    /// Ask for notification permission once signed in, arm the training-
    /// reminder nudges, and (when push is provisioned) register for APNs.
    private func setupNotifications() async {
        let granted = await LocalNotifications.shared.requestAuthorization()
        guard granted else { return }
        await LocalNotifications.shared.scheduleTrainingReminders()
        PushNotifications.shared.enable()   // no-op until APNs is set up
    }
}
