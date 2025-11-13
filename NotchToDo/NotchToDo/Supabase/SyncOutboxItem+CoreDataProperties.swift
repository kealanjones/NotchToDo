import Foundation
import CoreData

extension SyncOutboxItem {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SyncOutboxItem> {
        NSFetchRequest<SyncOutboxItem>(entityName: "SyncOutboxItem")
    }

    @NSManaged public var id: UUID
    @NSManaged public var entityName: String
    @NSManaged public var localIdentifier: UUID
    @NSManaged public var operation: Int16
    @NSManaged public var createdAt: Date
    @NSManaged public var payload: Data?
}

extension SyncOutboxItem: Identifiable {}
