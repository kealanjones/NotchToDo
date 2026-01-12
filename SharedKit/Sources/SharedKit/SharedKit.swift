// SharedKit - Cross-platform shared code for NotchToDo
//
// This package provides shared models, services, and utilities
// that work across iOS and macOS platforms.

// Re-export all public APIs
@_exported import Foundation

// Version information
public enum SharedKit {
    public static let version = "1.0.0"
    
    /// Platform identifier
    public static var platform: String {
        #if os(macOS)
        return "macOS"
        #elseif os(iOS)
        return "iOS"
        #else
        return "Unknown"
        #endif
    }
}
