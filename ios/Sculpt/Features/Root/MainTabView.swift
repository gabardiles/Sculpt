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
                .tabItem { Label("Today", systemImage: "house") }.tag(0)
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
