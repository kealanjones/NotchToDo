import Foundation

struct OrbOutboxPayload: Codable {
    let localID: UUID
    let remoteID: UUID?
    let name: String
    let colorHex: String
    let sortOrder: Double
    let createdAt: Date
    let updatedAt: Date?
    let deletedAt: Date?
    let remoteVersion: Int64?
}

struct TaskOutboxPayload: Codable {
    let localID: UUID
    let remoteID: UUID?
    let orbLocalID: UUID
    let orbRemoteID: UUID?
    let title: String
    let notes: String?
    let isCompleted: Bool
    let priority: Int
    let status: Int16
    let createdAt: Date
    let updatedAt: Date?
    let deletedAt: Date?
    let dueDate: Date?
    let sortOrder: Double
    let remoteVersion: Int64?
}

struct DeletionOutboxPayload: Codable {
    let localID: UUID
    let remoteID: UUID?
}
