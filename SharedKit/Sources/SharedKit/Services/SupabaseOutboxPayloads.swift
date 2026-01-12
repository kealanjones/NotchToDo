import Foundation

public struct OrbOutboxPayload: Codable {
    public let localID: UUID
    public let remoteID: UUID?
    public let name: String
    public let colorHex: String
    public let sortOrder: Double
    public let createdAt: Date
    public let updatedAt: Date?
    public let deletedAt: Date?
    public let remoteVersion: Int64?
    
    public init(
        localID: UUID,
        remoteID: UUID?,
        name: String,
        colorHex: String,
        sortOrder: Double,
        createdAt: Date,
        updatedAt: Date?,
        deletedAt: Date?,
        remoteVersion: Int64?
    ) {
        self.localID = localID
        self.remoteID = remoteID
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.remoteVersion = remoteVersion
    }
}

public struct TaskOutboxPayload: Codable {
    public let localID: UUID
    public let remoteID: UUID?
    public let orbLocalID: UUID
    public let orbRemoteID: UUID?
    public let title: String
    public let notes: String?
    public let isCompleted: Bool
    public let priority: Int
    public let status: Int16
    public let createdAt: Date
    public let updatedAt: Date?
    public let deletedAt: Date?
    public let dueDate: Date?
    public let sortOrder: Double
    public let remoteVersion: Int64?
    
    public init(
        localID: UUID,
        remoteID: UUID?,
        orbLocalID: UUID,
        orbRemoteID: UUID?,
        title: String,
        notes: String?,
        isCompleted: Bool,
        priority: Int,
        status: Int16,
        createdAt: Date,
        updatedAt: Date?,
        deletedAt: Date?,
        dueDate: Date?,
        sortOrder: Double,
        remoteVersion: Int64?
    ) {
        self.localID = localID
        self.remoteID = remoteID
        self.orbLocalID = orbLocalID
        self.orbRemoteID = orbRemoteID
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.priority = priority
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.dueDate = dueDate
        self.sortOrder = sortOrder
        self.remoteVersion = remoteVersion
    }
}

public struct DeletionOutboxPayload: Codable {
    public let localID: UUID
    public let remoteID: UUID?
    
    public init(localID: UUID, remoteID: UUID?) {
        self.localID = localID
        self.remoteID = remoteID
    }
}

public enum SyncOutboxOperation: Int16 {
    case insert = 0
    case update = 1
    case delete = 2

    public var name: String {
        switch self {
        case .insert: return "INSERT"
        case .update: return "UPDATE"
        case .delete: return "DELETE"
        }
    }
}
