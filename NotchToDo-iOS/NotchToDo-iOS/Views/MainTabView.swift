import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        TabView {
            TasksView()
                .tabItem {
                    Label("Tasks", systemImage: "list.bullet")
                }

            OrbsView()
                .tabItem {
                    Label("Orbs", systemImage: "circle.hexagongrid")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(DataManager.shared)
}
