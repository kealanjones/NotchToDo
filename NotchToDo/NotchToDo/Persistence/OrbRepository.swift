import CoreData
import Foundation

/// Clean CRUD repository for OrbEntity. All operations go through a single
/// managed object context and automatically track changes for sync.
final class OrbRepository {
    private let context: NSManagedObjectContext
    private let changeTracker: ChangeTracker

    init(context: NSManagedObjectContext, changeTracker: ChangeTracker) {
        self.context = context
        self.changeTracker = changeTracker
    }

    // MARK: - Read

    func fetchAll() throws -> [OrbEntity] {
        let request = OrbEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        return try context.fetch(request)
    }

    func fetch(byID id: UUID) throws -> OrbEntity? {
        let request = OrbEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    func fetch(byRemoteID remoteID: UUID) throws -> OrbEntity? {
        let request = OrbEntity.fetchRequest()
        request.predicate = NSPredicate(format: "remoteID == %@", remoteID as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    // MARK: - Create

    @discardableResult
    func create(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        sortOrder: Double,
        createdAt: Date = Date()
    ) throws -> OrbEntity {
        let entity = OrbEntity(context: context)
        entity.id = id
        entity.name = name
        entity.colorHex = colorHex
        entity.sortOrder = sortOrder
        entity.createdAt = createdAt
        entity.updatedAt = createdAt
        entity.needsSync = true

        try save()
        changeTracker.recordChange(entity: entity, operation: .insert)
        return entity
    }

    // MARK: - Update

    func update(_ entity: OrbEntity, name: String? = nil, colorHex: String? = nil, sortOrder: Double? = nil) throws {
        if let name { entity.name = name }
        if let colorHex { entity.colorHex = colorHex }
        if let sortOrder { entity.sortOrder = sortOrder }
        entity.updatedAt = Date()
        entity.needsSync = true

        try save()
        changeTracker.recordChange(entity: entity, operation: .update)
    }

    // MARK: - Delete

    func delete(_ entity: OrbEntity) throws {
        changeTracker.recordChange(entity: entity, operation: .delete)
        context.delete(entity)
        try save()
    }

    // MARK: - Batch Operations

    func deleteAll() throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "OrbEntity")
        let batchDelete = NSBatchDeleteRequest(fetchRequest: request)
        try context.persistentStoreCoordinator?.execute(batchDelete, with: context)
        context.reset()
    }

    func reindex(_ entities: [OrbEntity]) throws {
        for (index, entity) in entities.enumerated() {
            let order = Double(index)
            if entity.sortOrder != order {
                entity.sortOrder = order
                entity.needsSync = true
                changeTracker.recordChange(entity: entity, operation: .update)
            }
        }
        try save()
    }

    // MARK: - Persistence

    private func save() throws {
        guard context.hasChanges else { return }
        try context.save()
    }
}
