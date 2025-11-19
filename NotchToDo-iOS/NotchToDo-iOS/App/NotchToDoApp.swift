import SwiftUI

@main
struct NotchToDoApp: App {
    @StateObject private var dataManager = DataManager.shared

    var body: some Scene {
        WindowGroup {
            if dataManager.isAuthenticated {
                MainTabView()
                    .environmentObject(dataManager)
            } else {
                AuthView()
                    .environmentObject(dataManager)
            }
        }
    }
}
