import Foundation
import CoreData

extension TaskEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TaskEntity> {
        return NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
    }

    @NSManaged public var createdAt: Date
    @NSManaged public var deletedAt: Date?
    @NSManaged public var dueDate: Date?
    @NSManaged public var id: UUID
    @NSManaged public var isCompleted: Bool
    @NSManaged public var needsSync: Bool
    @NSManaged public var notes: String?
    @NSManaged public var priority: Int16
    @NSManaged public var remoteID: UUID?
    @NSManaged public var remoteVersion: Int64
    @NSManaged public var sortOrder: Double
    @NSManaged public var status: Int16
    @NSManaged public var title: String
    @NSManaged public var orb: OrbEntity

}

extension TaskEntity : Identifiable {

}
