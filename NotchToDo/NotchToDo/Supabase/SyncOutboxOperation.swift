import Foundation

enum SyncOutboxOperation: Int16 {
    case insert = 0
    case update = 1
    case delete = 2

    var name: String {
        switch self {
        case .insert: return "insert"
        case .update: return "update"
        case .delete: return "delete"
        }
    }
}
