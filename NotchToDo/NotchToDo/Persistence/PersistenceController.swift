import CoreData
import Foundation

// Central Core Data bootstrapper. Creates the persistent container that we can
// share between the overlay controller, repositories, and future extensions (e.g. iOS).
final class PersistenceController {
    static let shared = PersistenceController()

    private static let schemaVersion = 3
    private static let versionDefaultsKey = "OrbPersistenceSchemaVersion"
    private static let storeFilename = "NotchDataModel.sqlite"
    
    let container: NSPersistentContainer
    private let outboxContext: NSManagedObjectContext
    private let outboxQueue = DispatchQueue(label: "com.notchtodo.persistence.outbox", qos: .utility)
    private var contextObserver: NSObjectProtocol?
    private let ignoredContexts = NSHashTable<NSManagedObjectContext>.weakObjects()
    private let outboxEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "NotchDataModel")
        outboxContext = container.newBackgroundContext()
        outboxContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        outboxContext.automaticallyMergesChangesFromParent = true

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        } else {
            let storeURL = Self.storeURL()
            Self.ensureStoreDirectory(for: storeURL)
            DebugLog.log("Using Core Data store at \(storeURL.path)", category: .persistence)
            resetStoreIfNeeded(at: storeURL)

            let description = NSPersistentStoreDescription(url: storeURL)
            description.shouldInferMappingModelAutomatically = true
            description.shouldMigrateStoreAutomatically = true
            
            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { description, error in
            if let error {
                fatalError("Core Data store failed to load: \(error)")
            }

            UserDefaults.standard.set(Self.schemaVersion, forKey: Self.versionDefaultsKey)

            let model = self.container.managedObjectModel
            if let taskEntity = model.entitiesByName["TaskEntity"],
               let orbRelationship = taskEntity.relationshipsByName["orb"] {
                DebugLog.log("TaskEntity.orb toMany=\(orbRelationship.isToMany)", category: .persistence)
            }
            if let orbEntity = model.entitiesByName["OrbEntity"] {
                let keys = orbEntity.attributesByName.keys.sorted()
                DebugLog.log("OrbEntity attributes: \(keys.joined(separator: ", "))", category: .persistence)
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        observeContextChanges()
        purgeInvalidOutboxEntries()
    }

    deinit {
        if let token = contextObserver {
            NotificationCenter.default.removeObserver(token)
        }
    }

    private static func storeURL() -> URL {
        let fileManager = FileManager.default
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.notchtodo.app"
        let directory = baseDirectory.appendingPathComponent(bundleIdentifier, isDirectory: true)
        return directory.appendingPathComponent(storeFilename)
    }

    private func observeContextChanges() {
        contextObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            self?.handleContextSave(notification)
        }
    }

    func purgeInvalidOutboxEntries() {
        outboxQueue.async { [weak self] in
            guard let self else { return }
            self.outboxContext.perform {
                do {
                    let result = try self.cleanupOutboxEntries()
                    self.logOutboxMaintenanceResult(result)
                    if self.outboxContext.hasChanges {
                        try self.outboxContext.save()
                    }
                } catch {
                    DebugLog.log("Failed to purge/normalize outbox entries: \(error)", category: .sync)
                    self.outboxContext.reset()
                }
            }
        }
    }

    func performOutboxMaintenanceSync() {
        outboxQueue.sync {
            outboxContext.performAndWait {
                do {
                    let result = try cleanupOutboxEntries()
                    logOutboxMaintenanceResult(result)
                    if outboxContext.hasChanges {
                        try outboxContext.save()
                    }
                } catch {
                    DebugLog.log("Failed to synchronously normalize outbox entries: \(error)", category: .sync)
                    outboxContext.reset()
                }
            }
        }
    }

    private struct OutboxMaintenanceResult {
        var removedCount: Int
        var normalizedCount: Int
        var removedExamples: [String]
    }

    private func cleanupOutboxEntries() throws -> OutboxMaintenanceResult {
        let request: NSFetchRequest<SyncOutboxItem> = SyncOutboxItem.fetchRequest()
        let items = try outboxContext.fetch(request)
        let allowedEntities: Set<String> = ["OrbEntity", "TaskEntity"]
        var removed = 0
        var normalized = 0
        var removedExamples: [String] = []

        for item in items {
            let typedName = item.entityName
            let primitiveName = item.primitiveValue(forKey: #keyPath(SyncOutboxItem.entityName)) as? String
            let sourceName = typedName.isEmpty ? (primitiveName ?? "") : typedName
            let trimmed = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || !allowedEntities.contains(trimmed) {
                DebugLog.log(
                    "Outbox maintenance removing entry due to invalid entity: \(debugDescription(for: item))",
                    category: .sync
                )
                outboxContext.delete(item)
                removed += 1
                 if removedExamples.count < 5 {
                     removedExamples.append(trimmed.isEmpty ? "<empty entity name>" : trimmed)
                }
                continue
            }

            guard let raw = item.value(forKey: #keyPath(SyncOutboxItem.localIdentifier)) else {
                DebugLog.log(
                    "Outbox maintenance removing entry due to missing identifier: \(debugDescription(for: item))",
                    category: .sync
                )
                outboxContext.delete(item)
                removed += 1
                if removedExamples.count < 5 {
                    removedExamples.append("missing identifier for \(trimmed)")
                }
                continue
            }

            if let parsed = Self.parseOutboxIdentifier(raw) {
                if !(raw is NSUUID) {
                    setOutboxIdentifier(item, to: parsed)
                    normalized += 1
                }
            } else {
                DebugLog.log(
                    "Outbox maintenance removing entry due to unparsed identifier: \(debugDescription(for: item))",
                    category: .sync
                )
                outboxContext.delete(item)
                removed += 1
                if removedExamples.count < 5 {
                    removedExamples.append("unparsed identifier type \(String(describing: type(of: raw))) for \(trimmed)")
                }
            }
        }

        return OutboxMaintenanceResult(removedCount: removed, normalizedCount: normalized, removedExamples: removedExamples)
    }

    private func logOutboxMaintenanceResult(_ result: OutboxMaintenanceResult) {
        if result.removedCount > 0 {
            var message = "Purged \(result.removedCount) invalid outbox entries"
            if !result.removedExamples.isEmpty {
                message += " (examples: \(result.removedExamples.joined(separator: ", ")) )"
            }
            DebugLog.log(message, category: .sync)
        }
        if result.normalizedCount > 0 {
            DebugLog.log("Normalized \(result.normalizedCount) outbox identifiers", category: .sync)
        }
    }

    private func debugDescription(for item: SyncOutboxItem) -> String {
        let objectURI = item.objectID.uriRepresentation().absoluteString
        let entityName = item.entityName
        let operationValue = item.operation
        let createdAt = item.createdAt.ISO8601Format()
        let payloadSize = item.payload?.count ?? 0

        let rawEntityValue = item.value(forKey: #keyPath(SyncOutboxItem.entityName))
        let rawEntityDescription: String
        switch rawEntityValue {
        case let string as String:
            rawEntityDescription = "String(\(string))"
        case let string as NSString:
            rawEntityDescription = "NSString(\(string))"
        case .none:
            rawEntityDescription = "nil"
        case .some(let value):
            rawEntityDescription = "\(type(of: value))"
        }

        let rawIdentifier = item.value(forKey: #keyPath(SyncOutboxItem.localIdentifier))
        let identifierDescription: String
        switch rawIdentifier {
        case let uuid as UUID:
            identifierDescription = uuid.uuidString
        case let uuid as NSUUID:
            identifierDescription = uuid.uuidString
        case let data as Data:
            identifierDescription = "Data(\(data.count))"
        case let data as NSData:
            identifierDescription = "NSData(\(data.length))"
        case .none:
            identifierDescription = "nil"
        case .some(let value):
            identifierDescription = "\(type(of: value))"
        }

        return "[object=\(objectURI) entity='\(entityName)' rawEntity=\(rawEntityDescription) op=\(operationValue) createdAt=\(createdAt) localIdentifier=\(identifierDescription) payloadBytes=\(payloadSize)]"
    }

    private func setOutboxIdentifier(_ entry: SyncOutboxItem, to identifier: UUID) {
        entry.setValue(identifier as NSUUID, forKey: #keyPath(SyncOutboxItem.localIdentifier))
    }

    static func parseOutboxIdentifier(_ value: Any) -> UUID? {
        switch value {
        case let uuid as UUID:
            return uuid
        case let uuid as NSUUID:
            return uuid as UUID
        case let string as String:
            return UUID(uuidString: string)
        case let data as Data:
            return data.withUnsafeBytes { ptr -> UUID? in
                guard ptr.count == 16 else { return nil }
                let bytes = ptr.bindMemory(to: UInt8.self)
                return UUID(uuid: (
                    bytes[0], bytes[1], bytes[2], bytes[3],
                    bytes[4], bytes[5], bytes[6], bytes[7],
                    bytes[8], bytes[9], bytes[10], bytes[11],
                    bytes[12], bytes[13], bytes[14], bytes[15]
                ))
            }
        case let data as NSData:
            return parseOutboxIdentifier(data as Data)
        default:
            return nil
        }
    }

    private func handleContextSave(_ notification: Notification) {
        guard let context = notification.object as? NSManagedObjectContext else { return }
        if context === outboxContext { return }
        if ignoredContexts.contains(context) { return }

        let inserted = (notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>) ?? []
        let updated = (notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>) ?? []
        let deleted = (notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject>) ?? []

        if inserted.isEmpty && updated.isEmpty && deleted.isEmpty { return }

        enqueueOutboxChanges(for: inserted, operation: .insert)
        enqueueOutboxChanges(for: updated, operation: .update)
        enqueueOutboxChanges(for: deleted, operation: .delete)
    }

    func registerSyncWorkerContext(_ context: NSManagedObjectContext) {
        ignoredContexts.add(context)
    }
    
    // Public method to manually enqueue entities for sync (for backgroundContext saves)
    func enqueueEntity(for objectID: NSManagedObjectID, in context: NSManagedObjectContext, operation: SyncOutboxOperation) {
        context.performAndWait {
            guard let object = try? context.existingObject(with: objectID) else { return }
            let objects = Set([object])
            enqueueOutboxChanges(for: objects, operation: operation)
        }
    }

    private func enqueueOutboxChanges(for objects: Set<NSManagedObject>, operation: SyncOutboxOperation) {
        guard !objects.isEmpty else { return }

        let syncable = objects.filter { object in
            guard let name = object.entity.name else { return false }
            return name == "OrbEntity" || name == "TaskEntity"
        }

        guard !syncable.isEmpty else { return }

        outboxQueue.async { [weak self] in
            guard let self else { return }
            self.outboxContext.performAndWait {
                for object in syncable {
                    self.recordOutboxEntry(for: object, operation: operation)
                }

                if self.outboxContext.hasChanges {
                    do {
                        try self.outboxContext.save()
                        let verificationRequest: NSFetchRequest<SyncOutboxItem> = SyncOutboxItem.fetchRequest()
                        let persistedItems = try self.outboxContext.fetch(verificationRequest)
                        for persisted in persistedItems {
                            let typedName = persisted.entityName
                            if typedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                let persistedPrimitive = persisted.primitiveValue(forKey: #keyPath(SyncOutboxItem.entityName)) as Any?
                                DebugLog.log(
                                    "Post-save outbox entry check: entityName='' raw=\(String(describing: persistedPrimitive)) id=\(persisted.id)",
                                    category: .sync
                                )
                            }
                        }
                        NotificationCenter.default.post(name: .supabaseOutboxDidChange, object: nil)
                    } catch {
                        DebugLog.log("Failed to save outbox context: \(error)", category: .persistence)
                        self.outboxContext.reset()
                    }
                }
            }
        }
    }

    private func recordOutboxEntry(for object: NSManagedObject, operation: SyncOutboxOperation) {
        guard let rawName = object.entity.name else { return }
        let entityName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entityName.isEmpty else { return }
        guard let identifier = object.value(forKey: "id") as? UUID else { return }

        if operation != .delete {
            object.setValue(true, forKey: "needsSync")
        }

        let payloadData = payloadData(for: object, operation: operation)
        if payloadData == nil && operation != .delete {
            DebugLog.log("Skipping outbox entry for \(entityName) due to payload encoding failure", category: .sync)
            return
        }

        let fetch: NSFetchRequest<SyncOutboxItem> = SyncOutboxItem.fetchRequest()
        fetch.fetchLimit = 1
        fetch.predicate = NSPredicate(format: "entityName == %@ AND localIdentifier == %@", entityName, identifier as CVarArg)

        let existing = (try? outboxContext.fetch(fetch))?.first

        if let existing {
            if existing.operation == SyncOutboxOperation.insert.rawValue {
                if operation == .delete {
                    outboxContext.delete(existing)
                } else {
                    // Keep as insert; just refresh timestamp and payload.
                    existing.createdAt = Date()
                    existing.payload = payloadData
                    setOutboxIdentifier(existing, to: identifier)
                }
                return
            }

            existing.operation = operation.rawValue
            existing.createdAt = Date()
            if let payloadData {
                existing.payload = payloadData
            }
            setOutboxIdentifier(existing, to: identifier)
            DebugLog.log("Updated outbox item \(entityName) #\(identifier) (\(operation.name))", category: .sync)
            return
        }

        guard let outboxEntity = NSEntityDescription.insertNewObject(forEntityName: "SyncOutboxItem", into: outboxContext) as? SyncOutboxItem else {
            return
        }

        outboxEntity.id = UUID()
        outboxEntity.entityName = entityName
        // Write-through primitive to avoid typed empty string edge case
        outboxEntity.setValue(entityName as NSString, forKey: #keyPath(SyncOutboxItem.entityName))
        let primitiveEntityName = outboxEntity.primitiveValue(forKey: #keyPath(SyncOutboxItem.entityName)) as Any?
        DebugLog.log(
            "Recorded outbox entry primitive entityName=\(String(describing: primitiveEntityName)) for \(entityName) #\(identifier)",
            category: .sync
        )
        setOutboxIdentifier(outboxEntity, to: identifier)
        outboxEntity.operation = operation.rawValue
        outboxEntity.createdAt = Date()
        outboxEntity.payload = payloadData
        DebugLog.log("Created outbox item \(entityName) #\(identifier) (\(operation.name))", category: .sync)
    }

    private func payloadData(for object: NSManagedObject, operation: SyncOutboxOperation) -> Data? {
        do {
            if let orb = object as? OrbEntity {
                if operation == .delete {
                    let payload = DeletionOutboxPayload(localID: orb.id, remoteID: orb.remoteID)
                    return try outboxEncoder.encode(payload)
                } else {
                    let payload = OrbOutboxPayload(
                        localID: orb.id,
                        remoteID: orb.remoteID,
                        name: orb.name,
                        colorHex: orb.colorHex,
                        sortOrder: orb.sortOrder,
                        createdAt: orb.createdAt,
                        updatedAt: orb.updatedAt,
                        deletedAt: orb.deletedAt,
                        remoteVersion: orb.remoteVersion == 0 ? nil : orb.remoteVersion
                    )
                    return try outboxEncoder.encode(payload)
                }
            } else if let task = object as? TaskEntity {
                guard let id = task.value(forKey: "id") as? UUID else { return nil }
                let remoteID = task.value(forKey: "remoteID") as? UUID

                if operation == .delete {
                    let payload = DeletionOutboxPayload(localID: id, remoteID: remoteID)
                    return try outboxEncoder.encode(payload)
                } else {
                    guard let orb = resolvedOrbRelationship(for: task) else {
                        DebugLog.log("Skipping task payload: missing orb relationship for task \(id)", category: .sync)
                        task.setValue(false, forKey: "needsSync")
                        return nil
                    }
                    guard let orbLocalID = orb.value(forKey: "id") as? UUID else {
                        DebugLog.log("Skipping task payload: orb missing id for task \(id)", category: .sync)
                        task.setValue(false, forKey: "needsSync")
                        return nil
                    }
                    let payload = TaskOutboxPayload(
                        localID: id,
                        remoteID: remoteID,
                        orbLocalID: orbLocalID,
                        orbRemoteID: orb.value(forKey: "remoteID") as? UUID,
                        title: task.value(forKey: "title") as? String ?? "Untitled Task",
                        notes: task.value(forKey: "notes") as? String,
                        isCompleted: (task.value(forKey: "isCompleted") as? Bool) ?? false,
                        priority: Int((task.value(forKey: "priority") as? Int16) ?? 0),
                        status: (task.value(forKey: "status") as? Int16) ?? 0,
                        createdAt: (task.value(forKey: "createdAt") as? Date) ?? Date(),
                        updatedAt: attributeValue(task, key: "updatedAt"),
                        deletedAt: task.value(forKey: "deletedAt") as? Date,
                        dueDate: task.value(forKey: "dueDate") as? Date,
                        sortOrder: (task.value(forKey: "sortOrder") as? Double) ?? 0,
                        remoteVersion: {
                            let version = task.value(forKey: "remoteVersion") as? Int64 ?? 0
                            return version == 0 ? nil : version
                        }()
                    )
                    return try outboxEncoder.encode(payload)
                }
            }
        } catch {
            DebugLog.log("Failed to encode outbox payload for \(object.entity.name ?? "?"): \(error)", category: .sync)
        }
        return nil
    }

    private func resolvedOrbRelationship(for task: TaskEntity) -> OrbEntity? {
        if let orb = task.value(forKey: "orb") as? OrbEntity {
            return orb
        }
        if let set = task.value(forKey: "orb") as? NSSet, let orb = set.anyObject() as? OrbEntity {
            return orb
        }
        return nil
    }

    private func attributeValue<T>(_ object: NSManagedObject, key: String) -> T? {
        guard object.entity.attributesByName[key] != nil else { return nil }
        return object.value(forKey: key) as? T
    }

    private static func ensureStoreDirectory(for storeURL: URL) {
        let directory = storeURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            DebugLog.log("Failed to create Core Data directory: \(error)", category: .persistence)
        }
    }

    private func resetStoreIfNeeded(at url: URL) {
        let defaults = UserDefaults.standard
        let currentVersion = defaults.integer(forKey: Self.versionDefaultsKey)
        DebugLog.log("Current store version \(currentVersion); target \(Self.schemaVersion)", category: .persistence)
        guard currentVersion < Self.schemaVersion else {
            return
        }

        do {
            try Self.removeStoreFiles(at: url)
            try Self.removeLegacyStores()
            DebugLog.log("Reset Core Data store for schema version \(Self.schemaVersion)", category: .persistence)
        } catch {
            DebugLog.log("Failed to reset Core Data store: \(error)", category: .persistence)
        }
    }

    private static func removeStoreFiles(at url: URL) throws {
        let fileManager = FileManager.default
        let urls = [
            url,
            url.appendingPathExtension("wal"),
            url.appendingPathExtension("shm")
        ]

        for fileURL in urls where fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
            DebugLog.log("Removed legacy store file \(fileURL.lastPathComponent)", category: .persistence)
        }
    }

    private static func removeLegacyStores() throws {
        let fileManager = FileManager.default
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory

        let legacyDirectories = [
            baseDirectory.appendingPathComponent("NotchToDo", isDirectory: true),
            baseDirectory.appendingPathComponent("NotchToDo/NotchDataModel.sqlite")
        ]

        for url in legacyDirectories {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
                DebugLog.log("Removed legacy path \(url.path)", category: .persistence)
            }
        }
    }
}
