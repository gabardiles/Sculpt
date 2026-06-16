import SwiftUI

/// The five-tab shell — Today, Program, Report, Friends, You. Mirrors
/// src/components/nav/TabBar.tsx. The "You" tab fans out to Weight, Photos,
/// and Goals (as the web does).
struct MainTabView: View {
    @Environment(\.palette) private var palette
    @State private var selection = 0

    init() {
        // Crisp, thin tab icons: SF Symbols (outline) render lighter than the
        // old custom raster glyphs. Selected stays the brand tint (set via
        // .tint below); unselected is a clean grey rather than a faded tint.
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        let inactive = UIColor.systemGray
        appearance.stackedLayoutAppearance.normal.iconColor = inactive
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: inactive]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { DashboardView() }
                // Custom thin house-heart vector (Assets/tab-today).
                .tabItem { Label("Today", image: "tab-today") }.tag(0)
            NavigationStack { ProgramView() }
                .tabItem { Label("Program", systemImage: "calendar") }.tag(1)
            NavigationStack { ReportView() }
                .tabItem { Label("Report", systemImage: "sparkles") }.tag(2)
            NavigationStack { FriendsView() }
                .tabItem { Label("Friends", systemImage: "heart") }.tag(3)
            NavigationStack { YouView() }
                .tabItem { Label("You", systemImage: "person.crop.circle") }.tag(4)
        }
        .tint(palette.blushDeep)
    }
}
