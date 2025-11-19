import Foundation

// MARK: - Snapshot Models (for Core Data bridging)

struct OrbSnapshot {
    var id: UUID
    var name: String
    var colorHex: String
    var sortOrder: Double
    var createdAt: Date
    var updatedAt: Date?
    var tasks: [TaskSnapshot]
}

struct TaskSnapshot {
    var id: UUID
    var title: String
    var notes: String
    var isCompleted: Bool
    var priority: Int
    var status: Int16
    var createdAt: Date
    var dueDate: Date?
    var sortOrder: Double
}
