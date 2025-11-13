import Foundation
import CoreData

extension OrbEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<OrbEntity> {
        NSFetchRequest<OrbEntity>(entityName: "OrbEntity")
    }

    @NSManaged public var colorHex: String
    @NSManaged public var createdAt: Date
    @NSManaged public var deletedAt: Date?
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var remoteID: UUID?
    @NSManaged public var remoteVersion: Int64
    @NSManaged public var sortOrder: Double
    @NSManaged public var updatedAt: Date?
    @NSManaged public var needsSync: Bool
    @NSManaged public var tasks: Set<TaskEntity>?
}

extension OrbEntity: Identifiable { }
