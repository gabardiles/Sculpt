import SwiftUI

@main
struct SculptApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var theme = ThemeManager()
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(theme)
                .environmentObject(session)
                .environment(\.palette, theme.palette)
                .preferredColorScheme(theme.theme == .spartan ? .dark : .light)
                .tint(theme.palette.blushDeep)
                .task { session.start() }
        }
    }
}
