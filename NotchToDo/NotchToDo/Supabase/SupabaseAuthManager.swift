import Foundation

final class SupabaseAuthManager {
    struct Session {
        let accessToken: String
        let refreshToken: String?
        let expiresAt: Date?
    }

    private enum Keys {
        static let accessToken = "SupabaseAccessToken"
        static let refreshToken = "SupabaseRefreshToken"
        static let expiresAt = "SupabaseAccessTokenExpiry"
    }
    private let service: SupabaseService
    private let queue = DispatchQueue(label: "com.notchtodo.supabase.auth", qos: .utility)
    
    // Thread-safe session storage
    private let sessionLock = NSLock()
    private var _currentSession: Session?
    
    /// Thread-safe access to the current session
    private(set) var currentSession: Session? {
        get {
            sessionLock.lock()
            defer { sessionLock.unlock() }
            return _currentSession
        }
        set {
            sessionLock.lock()
            let oldValue = _currentSession
            _currentSession = newValue
            sessionLock.unlock()
            
            // Only post notification if session actually changed
            guard oldValue?.accessToken != newValue?.accessToken else { return }
            
            // Post notification on main thread for UI safety
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .supabaseAuthSessionChanged, object: newValue)
            }
        }
    }

    init(service: SupabaseService) {
        self.service = service
        loadPersistedSession()
    }

    func bootstrapWithDeveloperToken(_ token: String) {
        queue.async {
            self.persistSession(accessToken: token, refreshToken: nil, expiresAt: nil)
        }
    }

    func clearSession() {
        queue.async {
            self.persistSession(accessToken: nil, refreshToken: nil, expiresAt: nil)
        }
    }

    func signIn(email: String, password: String) async throws {
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        let request = try service.makeAuthRequest(
            path: "token",
            queryItems: [URLQueryItem(name: "grant_type", value: "password")],
            body: body
        )
        let response: AuthResponse = try await service.performAuth(request, decode: AuthResponse.self)
        persistSessionAsync(from: response)
    }

    func signUp(email: String, password: String) async throws {
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "data": [:]
        ]
        let request = try service.makeAuthRequest(path: "signup", body: body)
        let response: AuthResponse = try await service.performAuth(request, decode: AuthResponse.self)
        persistSessionAsync(from: response)
    }

    func refreshSessionIfNeeded() async {
        guard let session = currentSession,
              let expiresAt = session.expiresAt,
              let refreshToken = session.refreshToken else { return }

        let needsRefresh = expiresAt.timeIntervalSinceNow < 300
        guard needsRefresh else { return }

        do {
            let body: [String: Any] = ["refresh_token": refreshToken]
            let request = try service.makeAuthRequest(
                path: "token",
                queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")],
                body: body
            )
            let response: AuthResponse = try await service.performAuth(request, decode: AuthResponse.self)
            persistSessionAsync(from: response)
        } catch {
            DebugLog.log("Supabase token refresh failed: \(error)", category: .sync)
            clearSession()
        }
    }

    @discardableResult
    func handleOAuthRedirect(url: URL) -> Bool {
        guard url.scheme == "notch", url.host == "auth-callback" else { return false }

        let fragmentParams = parse(url.fragment)
        let queryParams = parse(url.query)
        let params = fragmentParams.merging(queryParams) { current, _ in current }

        guard let accessToken = params["access_token"] else {
            DebugLog.log("OAuth redirect missing access_token", category: .sync)
            return false
        }

        let refreshToken = params["refresh_token"]
        let expiresAt: Date?
        if let expiresAtString = params["expires_at"], let timestamp = Double(expiresAtString) {
            expiresAt = Date(timeIntervalSince1970: timestamp)
        } else if let expiresInString = params["expires_in"], let delta = Double(expiresInString) {
            expiresAt = Date().addingTimeInterval(delta)
        } else {
            expiresAt = nil
        }

        persistSessionAsync(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt)
        return true
    }

    func setSession(accessToken: String, refreshToken: String?, expiresAt: Date?) {
        persistSessionAsync(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt)
    }

    private func loadPersistedSession() {
        let accessToken = KeychainHelper.string(for: Keys.accessToken)
        if let accessToken {
            let refreshToken = KeychainHelper.string(for: Keys.refreshToken)
            let expiryInterval = UserDefaults.standard.double(forKey: Keys.expiresAt)
            let expiry = expiryInterval > 0 ? Date(timeIntervalSince1970: expiryInterval) : nil
            currentSession = Session(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiry)
        } else {
            currentSession = nil
        }
    }

    private func persistSession(accessToken: String?, refreshToken: String?, expiresAt: Date?) {
        if let accessToken {
            KeychainHelper.setString(accessToken, for: Keys.accessToken)
        } else {
            KeychainHelper.setString(nil, for: Keys.accessToken)
        }
        if let refreshToken {
            KeychainHelper.setString(refreshToken, for: Keys.refreshToken)
        } else {
            KeychainHelper.setString(nil, for: Keys.refreshToken)
        }

        if let expiresAt {
            UserDefaults.standard.set(expiresAt.timeIntervalSince1970, forKey: Keys.expiresAt)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.expiresAt)
        }

        currentSession = accessToken.map { Session(accessToken: $0, refreshToken: refreshToken, expiresAt: expiresAt) }
    }

    private func persistSessionAsync(from response: AuthResponse) {
        let expiresAt: Date?
        if let epoch = response.expiresAt {
            expiresAt = Date(timeIntervalSince1970: epoch)
        } else if let delta = response.expiresIn {
            expiresAt = Date().addingTimeInterval(delta)
        } else {
            expiresAt = nil
        }
        persistSessionAsync(accessToken: response.accessToken, refreshToken: response.refreshToken, expiresAt: expiresAt)
    }

    private func persistSessionAsync(accessToken: String?, refreshToken: String?, expiresAt: Date?) {
        queue.async {
            self.persistSession(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt)
        }
    }

    private func parse(_ component: String?) -> [String: String] {
        guard let component, !component.isEmpty else { return [:] }
        return component
            .split(separator: "&")
            .reduce(into: [String: String]()) { dict, pair in
                let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { return }
                let key = parts[0].removingPercentEncoding ?? parts[0]
                let value = parts[1].removingPercentEncoding ?? parts[1]
                dict[key] = value
            }
    }
}

private struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: TimeInterval?
    let expiresAt: TimeInterval?

    private struct RawResponse: Decodable {
        struct Session: Decodable {
            let accessToken: String?
            let refreshToken: String?
            let expiresIn: TimeInterval?
            let expiresAt: TimeInterval?
        }

        struct DataContainer: Decodable {
            let session: Session?
        }

        let accessToken: String?
        let refreshToken: String?
        let expiresIn: TimeInterval?
        let expiresAt: TimeInterval?
        let session: Session?
        let data: DataContainer?
    }

    init(from decoder: Decoder) throws {
        let raw = try RawResponse(from: decoder)

        if let token = raw.accessToken {
            accessToken = token
            refreshToken = raw.refreshToken
            expiresIn = raw.expiresIn
            expiresAt = raw.expiresAt
            return
        }

        if let session = raw.session ?? raw.data?.session, let token = session.accessToken {
            accessToken = token
            refreshToken = session.refreshToken
            expiresIn = session.expiresIn
            expiresAt = session.expiresAt
            return
        }

        throw DecodingError.dataCorrupted(
            .init(codingPath: decoder.codingPath, debugDescription: "No access token found in response")
        )
    }
}
