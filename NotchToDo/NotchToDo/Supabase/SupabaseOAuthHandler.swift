import Foundation
import AppKit

// MARK: - OAuth Provider Extension for SupabaseAuthManager

extension SupabaseAuthManager {
    /// Supported OAuth providers
    enum OAuthProvider: String {
        case google = "google"
        case apple = "apple"

        var displayName: String {
            switch self {
            case .google: return "Google"
            case .apple: return "Apple"
            }
        }
    }

    /// Builds the OAuth authorization URL for a given provider
    /// - Parameters:
    ///   - provider: The OAuth provider (google, apple, etc.)
    ///   - redirectTo: The custom URL scheme redirect (e.g., "notch://auth-callback")
    /// - Returns: The complete OAuth URL to open in a browser
    func buildOAuthURL(provider: OAuthProvider, redirectTo: String) -> URL? {
        guard let config = SupabaseEnvironment.configuration() else {
            DebugLog.log("Cannot build OAuth URL: Supabase configuration missing", category: .sync)
            return nil
        }

        var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false)
        components?.path = "/auth/v1/authorize"
        components?.queryItems = [
            URLQueryItem(name: "provider", value: provider.rawValue),
            URLQueryItem(name: "redirect_to", value: redirectTo)
        ]

        guard let url = components?.url else {
            DebugLog.log("Failed to construct OAuth URL", category: .sync)
            return nil
        }

        DebugLog.log("Built OAuth URL for \(provider.displayName): \(url.absoluteString)", category: .sync)
        return url
    }

    /// Initiates OAuth sign-in by opening the provider's authorization URL in the default browser
    /// - Parameter provider: The OAuth provider to use
    /// - Returns: True if the URL was successfully opened
    @discardableResult
    func signInWithOAuth(provider: OAuthProvider) -> Bool {
        let redirectURL = "notch://auth-callback"

        guard let oauthURL = buildOAuthURL(provider: provider, redirectTo: redirectURL) else {
            DebugLog.log("Cannot start OAuth: failed to build URL", category: .sync)
            return false
        }

        DebugLog.log("Starting OAuth flow for \(provider.displayName)...", category: .sync)
        NSWorkspace.shared.open(oauthURL)
        return true
    }
}
