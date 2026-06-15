import SwiftUI

/// The five-tab shell — Today, Program, Report, Friends, You. Mirrors
/// src/components/nav/TabBar.tsx. The "You" tab fans out to Weight, Photos,
/// and Goals (as the web does).
struct MainTabView: View {
    @Environment(\.palette) private var palette
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { DashboardView() }
                .tabItem { Label("Today", image: "tab-today") }.tag(0)
            NavigationStack { ProgramView() }
                .tabItem { Label("Program", image: "tab-program") }.tag(1)
            NavigationStack { ReportView() }
                .tabItem { Label("Report", image: "tab-report") }.tag(2)
            NavigationStack { FriendsView() }
                .tabItem { Label("Friends", image: "tab-friends") }.tag(3)
            NavigationStack { YouView() }
                .tabItem { Label("You", image: "tab-you") }.tag(4)
        }
        .tint(palette.blushDeep)
    }
}
