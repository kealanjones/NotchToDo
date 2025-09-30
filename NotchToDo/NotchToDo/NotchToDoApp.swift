import SwiftUI

@main
struct NotchToDoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // No window scene - this is a status bar app
        Settings {
            EmptyView()
        }
    }
}

