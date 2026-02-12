import CoreData
import Foundation

/// Clean CRUD repository for TaskEntity. All operations go through a single
/// managed object context and automatically track changes for sync.
final class TaskRepository {
    private let context: NSManagedObjectContext
    private let changeTracker: ChangeTracker

    init(context: NSManagedObjectContext, changeTracker: ChangeTracker) {
        self.context = context
        self.changeTracker = changeTracker
    }

    // MARK: - Read

    func fetchAll(for orb: OrbEntity) throws -> [TaskEntity] {
        let request = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "orb == %@", orb)
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        return try context.fetch(request)
    }

    func fetch(byID id: UUID) throws -> TaskEntity? {
        let request = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    func fetch(byRemoteID remoteID: UUID) throws -> TaskEntity? {
        let request = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "remoteID == %@", remoteID as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    // MARK: - Create

    @discardableResult
    func create(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        isCompleted: Bool = false,
        priority: Int16 = 1,
        status: Int16 = 1,
        dueDate: Date? = nil,
        sortOrder: Double,
        orb: OrbEntity,
        createdAt: Date = Date()
    ) throws -> TaskEntity {
        let entity = TaskEntity(context: context)
        entity.id = id
        entity.title = title
        entity.notes = notes
        entity.isCompleted = isCompleted
        entity.priority = priority
        entity.status = status
        entity.dueDate = dueDate
        entity.sortOrder = sortOrder
        entity.orb = orb
        entity.createdAt = createdAt
        entity.needsSync = true

        try save()
        changeTracker.recordChange(entity: entity, operation: .insert)
        return entity
    }

    // MARK: - Update

    func update(
        _ entity: TaskEntity,
        title: String? = nil,
        notes: String?? = nil,
        isCompleted: Bool? = nil,
        priority: Int16? = nil,
        status: Int16? = nil,
        dueDate: Date?? = nil,
        sortOrder: Double? = nil,
        orb: OrbEntity? = nil
    ) throws {
        if let title { entity.title = title }
        if let notes { entity.notes = notes }
        if let isCompleted { entity.isCompleted = isCompleted }
        if let priority { entity.priority = priority }
        if let status { entity.status = status }
        if let dueDate { entity.dueDate = dueDate }
        if let sortOrder { entity.sortOrder = sortOrder }
        if let orb { entity.orb = orb }
        entity.needsSync = true

        try save()
        changeTracker.recordChange(entity: entity, operation: .update)
    }

    // MARK: - Delete

    func delete(_ entity: TaskEntity) throws {
        changeTracker.recordChange(entity: entity, operation: .delete)
        context.delete(entity)
        try save()
    }

    // MARK: - Batch Operations

    func deleteAll() throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "TaskEntity")
        let batchDelete = NSBatchDeleteRequest(fetchRequest: request)
        try context.persistentStoreCoordinator?.execute(batchDelete, with: context)
        context.reset()
    }

    func reindex(tasks: [TaskEntity]) throws {
        for (index, entity) in tasks.enumerated() {
            let order = Double(index)
            if entity.sortOrder != order {
                entity.sortOrder = order
                entity.needsSync = true
                changeTracker.recordChange(entity: entity, operation: .update)
            }
        }
        try save()
    }

    func moveTask(_ entity: TaskEntity, to targetOrb: OrbEntity, at index: Int) throws {
        entity.orb = targetOrb
        entity.sortOrder = Double(index)
        entity.needsSync = true

        // Reindex remaining tasks in the target orb
        let targetTasks = try fetchAll(for: targetOrb).filter { $0.id != entity.id }
        var reindexed = Array(targetTasks)
        reindexed.insert(entity, at: min(index, reindexed.count))
        for (i, task) in reindexed.enumerated() {
            task.sortOrder = Double(i)
        }

        try save()
        changeTracker.recordChange(entity: entity, operation: .update)
    }

    // MARK: - Persistence

    private func save() throws {
        guard context.hasChanges else { return }
        try context.save()
    }
}
