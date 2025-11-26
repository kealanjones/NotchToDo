import Foundation

// MARK: - Snapshot Models (for Core Data bridging)

public struct OrbSnapshot {
    public var id: UUID
    public var name: String
    public var colorHex: String
    public var sortOrder: Double
    public var createdAt: Date
    public var updatedAt: Date?
    public var tasks: [TaskSnapshot]
    
    public init(
        id: UUID,
        name: String,
        colorHex: String,
        sortOrder: Double,
        createdAt: Date,
        updatedAt: Date?,
        tasks: [TaskSnapshot]
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tasks = tasks
    }
}

public struct TaskSnapshot {
    public var id: UUID
    public var title: String
    public var notes: String
    public var isCompleted: Bool
    public var priority: Int
    public var status: Int16
    public var createdAt: Date
    public var dueDate: Date?
    public var sortOrder: Double
    
    public init(
        id: UUID,
        title: String,
        notes: String,
        isCompleted: Bool,
        priority: Int,
        status: Int16,
        createdAt: Date,
        dueDate: Date?,
        sortOrder: Double
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.priority = priority
        self.status = status
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.sortOrder = sortOrder
    }
}
