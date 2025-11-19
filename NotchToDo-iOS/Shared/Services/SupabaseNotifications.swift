import Foundation

extension Notification.Name {
    static let supabaseOutboxDidChange = Notification.Name("SupabaseOutboxDidChange")
    static let supabaseAuthSessionChanged = Notification.Name("SupabaseAuthSessionChanged")
    static let supabaseDataDidPull = Notification.Name("SupabaseDataDidPull")
}
