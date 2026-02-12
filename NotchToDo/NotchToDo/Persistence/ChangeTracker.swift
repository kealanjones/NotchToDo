import CoreData
import Foundation

/// Unified change tracking system. Replaces the old fragmented outbox management
/// where changes were recorded through multiple code paths (context observer,
/// manual enqueue, background context workarounds). Now there is ONE way to
/// record a change: call `recordChange(entity:operation:)`.
///
/// The ChangeTracker owns its own background context dedicated to outbox writes,
/// ensuring outbox persistence never interferes with the main view context.
final class ChangeTracker {
    private let container: NSPersistentContainer
    private let outboxContext: NSManagedObjectContext
    private let queue = DispatchQueue(label: "com.notchtodo.changetracker", qos: .utility)
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    /// Posted when new outbox entries are available for sync.
    static let outboxDidChangeNotification = Notification.Name("ChangeTrackerOutboxDidChange")

    init(container: NSPersistentContainer) {
        self.container = container
        self.outboxContext = container.newBackgroundContext()
        self.outboxContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        self.outboxContext.automaticallyMergesChangesFromParent = true
    }

    // MARK: - Public API

    /// Record a single entity change. This is the ONLY entry point for outbox writes.
    /// Called by repositories after every create/update/delete.
    func recordChange(entity: NSManagedObject, operation: SyncOutboxOperation) {
        guard let entityName = entity.entity.name,
              entityName == "OrbEntity" || entityName == "TaskEntity" else {
            return
        }
        guard let identifier = entity.value(forKey: "id") as? UUID else {
            DebugLog.log("ChangeTracker: skipping entity with no id", category: .sync)
            return
        }

        let payloadData = buildPayload(for: entity, operation: operation)
        if payloadData == nil && operation != .delete {
            DebugLog.log("ChangeTracker: skipping \(entityName) - payload encoding failed", category: .sync)
            return
        }

        queue.async { [weak self] in
            guard let self else { return }
            self.outboxContext.performAndWait {
                self.writeOutboxEntry(
                    entityName: entityName,
                    identifier: identifier,
                    operation: operation,
                    payload: payloadData
                )
            }
        }
    }

    /// Record changes for multiple entities at once (e.g., after a remote merge).
    func recordChanges(entities: [(NSManagedObject, SyncOutboxOperation)]) {
        guard !entities.isEmpty else { return }
        queue.async { [weak self] in
            guard let self else { return }
            self.outboxContext.performAndWait {
                for (entity, operation) in entities {
                    guard let entityName = entity.entity.name,
                          entityName == "OrbEntity" || entityName == "TaskEntity",
                          let identifier = entity.value(forKey: "id") as? UUID else {
                        continue
                    }
                    let payloadData = self.buildPayload(for: entity, operation: operation)
                    self.writeOutboxEntry(
                        entityName: entityName,
                        identifier: identifier,
                        operation: operation,
                        payload: payloadData
                    )
                }
            }
        }
    }

    /// Fetch pending outbox items for the sync manager to process.
    func fetchPendingItems(limit: Int = 50) -> [OutboxItem] {
        var results: [OutboxItem] = []
        outboxContext.performAndWait {
            let request: NSFetchRequest<SyncOutboxItem> = SyncOutboxItem.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            request.fetchLimit = limit
            guard let items = try? outboxContext.fetch(request) else { return }

            for item in items {
                let name = item.entityName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty,
                      let operation = SyncOutboxOperation(rawValue: item.operation) else {
                    outboxContext.delete(item)
                    continue
                }
                results.append(OutboxItem(
                    objectID: item.objectID,
                    entityName: name,
                    localIdentifier: item.localIdentifier,
                    operation: operation,
                    payload: item.payload,
                    createdAt: item.createdAt
                ))
            }
            if outboxContext.hasChanges {
                try? outboxContext.save()
            }
        }
        return results
    }

    /// Remove a successfully synced outbox entry.
    func removeItem(objectID: NSManagedObjectID) {
        outboxContext.performAndWait {
            if let item = try? outboxContext.existingObject(with: objectID) {
                outboxContext.delete(item)
                try? outboxContext.save()
            }
        }
    }

    /// Remove all outbox entries (used on logout).
    func purgeAll() {
        outboxContext.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "SyncOutboxItem")
            let batchDelete = NSBatchDeleteRequest(fetchRequest: request)
            try? outboxContext.persistentStoreCoordinator?.execute(batchDelete, with: outboxContext)
            outboxContext.reset()
            DebugLog.log("ChangeTracker: purged all outbox entries", category: .sync)
        }
    }

    /// Run maintenance to remove invalid entries. Called at startup.
    func performMaintenance() {
        queue.async { [weak self] in
            guard let self else { return }
            self.outboxContext.performAndWait {
                let request: NSFetchRequest<SyncOutboxItem> = SyncOutboxItem.fetchRequest()
                guard let items = try? self.outboxContext.fetch(request) else { return }
                let allowed: Set<String> = ["OrbEntity", "TaskEntity"]
                var removed = 0
                for item in items {
                    let name = item.entityName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if name.isEmpty || !allowed.contains(name) {
                        self.outboxContext.delete(item)
                        removed += 1
                    }
                }
                if removed > 0 {
                    DebugLog.log("ChangeTracker maintenance: removed \(removed) invalid entries", category: .sync)
                }
                if self.outboxContext.hasChanges {
                    try? self.outboxContext.save()
                }
            }
        }
    }

    // MARK: - Outbox Item (value type for consumers)

    struct OutboxItem {
        let objectID: NSManagedObjectID
        let entityName: String
        let localIdentifier: UUID
        let operation: SyncOutboxOperation
        let payload: Data?
        let createdAt: Date
    }

    // MARK: - Private

    private func writeOutboxEntry(
        entityName: String,
        identifier: UUID,
        operation: SyncOutboxOperation,
        payload: Data?
    ) {
        // Check for existing entry for this entity
        let fetch: NSFetchRequest<SyncOutboxItem> = SyncOutboxItem.fetchRequest()
        fetch.predicate = NSPredicate(
            format: "entityName == %@ AND localIdentifier == %@",
            entityName, identifier as CVarArg
        )
        fetch.fetchLimit = 1

        let existing = (try? outboxContext.fetch(fetch))?.first

        if let existing {
            // Coalesce: if we previously recorded an insert and now get a delete,
            // just remove the outbox entry entirely (never synced).
            if existing.operation == SyncOutboxOperation.insert.rawValue && operation == .delete {
                outboxContext.delete(existing)
                saveAndNotify()
                return
            }
            // If previously insert and now update, keep as insert with fresh payload.
            if existing.operation == SyncOutboxOperation.insert.rawValue && operation == .update {
                existing.createdAt = Date()
                if let payload { existing.payload = payload }
                saveAndNotify()
                return
            }
            // Otherwise, update the existing entry.
            existing.operation = operation.rawValue
            existing.createdAt = Date()
            if let payload { existing.payload = payload }
            saveAndNotify()
            return
        }

        // Create new entry
        let entry = SyncOutboxItem(context: outboxContext)
        entry.id = UUID()
        entry.entityName = entityName
        entry.localIdentifier = identifier
        entry.operation = operation.rawValue
        entry.createdAt = Date()
        entry.payload = payload
        saveAndNotify()
    }

    private func saveAndNotify() {
        guard outboxContext.hasChanges else { return }
        do {
            try outboxContext.save()
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Self.outboxDidChangeNotification,
                    object: nil
                )
            }
        } catch {
            DebugLog.log("ChangeTracker: failed to save outbox: \(error)", category: .sync)
            outboxContext.reset()
        }
    }

    private func buildPayload(for entity: NSManagedObject, operation: SyncOutboxOperation) -> Data? {
        do {
            if let orb = entity as? OrbEntity {
                if operation == .delete {
                    return try encoder.encode(DeletionOutboxPayload(localID: orb.id, remoteID: orb.remoteID))
                }
                return try encoder.encode(OrbOutboxPayload(
                    localID: orb.id,
                    remoteID: orb.remoteID,
                    name: orb.name,
                    colorHex: orb.colorHex,
                    sortOrder: orb.sortOrder,
                    createdAt: orb.createdAt,
                    updatedAt: orb.updatedAt,
                    deletedAt: orb.deletedAt,
                    remoteVersion: orb.remoteVersion == 0 ? nil : orb.remoteVersion
                ))
            } else if let task = entity as? TaskEntity {
                let id = task.id
                if operation == .delete {
                    return try encoder.encode(DeletionOutboxPayload(localID: id, remoteID: task.remoteID))
                }
                let orbEntity = task.orb
                return try encoder.encode(TaskOutboxPayload(
                    localID: id,
                    remoteID: task.remoteID,
                    orbLocalID: orbEntity.id,
                    orbRemoteID: orbEntity.remoteID,
                    title: task.title,
                    notes: task.notes,
                    isCompleted: task.isCompleted,
                    priority: Int(task.priority),
                    status: task.status,
                    createdAt: task.createdAt,
                    updatedAt: nil,
                    deletedAt: task.deletedAt,
                    dueDate: task.dueDate,
                    sortOrder: task.sortOrder,
                    remoteVersion: task.remoteVersion == 0 ? nil : task.remoteVersion
                ))
            }
        } catch {
            DebugLog.log("ChangeTracker: payload encoding failed: \(error)", category: .sync)
        }
        return nil
    }
}
