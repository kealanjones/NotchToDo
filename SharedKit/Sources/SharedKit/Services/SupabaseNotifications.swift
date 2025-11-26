import Foundation

public extension Notification.Name {
    /// Posted when the Supabase outbox has pending changes to sync
    static let supabaseOutboxDidChange = Notification.Name("SupabaseOutboxDidChange")
    
    /// Posted when data has been pulled from Supabase
    static let supabaseDataDidPull = Notification.Name("SupabaseDataDidPull")
}
