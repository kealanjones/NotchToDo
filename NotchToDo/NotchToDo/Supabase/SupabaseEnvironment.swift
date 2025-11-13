import Foundation

enum SupabaseEnvironment {
    private static let urlKey = "SupabaseURL"
    private static let anonKeyKey = "SupabaseAnonKey"
    private static let storageBucketKey = "SupabaseStorageBucket"
    private static let devAccessTokenKey = "SupabaseDevAccessToken"

    static func configuration() -> SupabaseService.Configuration? {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: urlKey) as? String,
              let url = URL(string: urlString),
              let anonKey = Bundle.main.object(forInfoDictionaryKey: anonKeyKey) as? String else {
            DebugLog.log("Supabase configuration missing from Info.plist", category: .sync)
            return nil
        }

        let bucket = (Bundle.main.object(forInfoDictionaryKey: storageBucketKey) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let bucketName = bucket?.isEmpty == false ? bucket! : "attachments"

        return SupabaseService.Configuration(
            projectURL: url,
            anonKey: anonKey,
            storageBucket: bucketName
        )
    }

    static func developerAccessToken() -> String? {
        guard let token = Bundle.main.object(forInfoDictionaryKey: devAccessTokenKey) as? String else {
            return nil
        }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
