import SwiftUI

@main
struct NotchToDoApp: App {
    @StateObject private var dataManager = DataManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if dataManager.isAuthenticated {
                    MainTabView()
                        .environmentObject(dataManager)
                } else {
                    AuthView()
                        .environmentObject(dataManager)
                }
            }
            .onOpenURL { url in
                dataManager.authManager?.handleOAuthRedirect(url: url)
            }
        }
    }
}
