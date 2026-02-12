import CoreData
import Foundation

/// Central Core Data bootstrapper. Creates the persistent container that is shared
/// between the DataStore, repositories, and sync engine.
///
/// REDESIGNED: This class is now purely responsible for Core Data stack setup.
/// All outbox/change tracking logic has been moved to ChangeTracker, and all
/// CRUD operations go through OrbRepository and TaskRepository via DataStore.
/// This eliminates the old multi-path outbox system that caused missed syncs.
final class PersistenceController {
    static let shared = PersistenceController()

    private static let schemaVersion = 3
    private static let versionDefaultsKey = "OrbPersistenceSchemaVersion"
    private static let storeFilename = "NotchDataModel.sqlite"

    let container: NSPersistentContainer

    // Legacy compatibility: sync manager still needs to register its context
    // to avoid re-entrant outbox writes. This will be removed once
    // SupabaseSyncManager is fully migrated to use ChangeTracker.
    private let ignoredContexts = NSHashTable<NSManagedObjectContext>.weakObjects()

    private init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "NotchDataModel")

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

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data store failed to load: \(error)")
            }
            UserDefaults.standard.set(Self.schemaVersion, forKey: Self.versionDefaultsKey)
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    // MARK: - Sync Context Registration (legacy bridge)

    func registerSyncWorkerContext(_ context: NSManagedObjectContext) {
        ignoredContexts.add(context)
    }

    // MARK: - Legacy Outbox Compatibility

    /// These methods exist for backward compatibility with SupabaseSyncManager
    /// while it is being migrated. New code should use ChangeTracker directly.

    func performOutboxMaintenanceSync() {
        // Now handled by ChangeTracker.performMaintenance()
        // This is a no-op bridge method
    }

    func enqueueEntity(for objectID: NSManagedObjectID, in context: NSManagedObjectContext, operation: SyncOutboxOperation) {
        // Legacy bridge - no longer used by the new persistence system
        // The ChangeTracker handles all outbox writes directly
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

    // MARK: - Store Location

    private static func storeURL() -> URL {
        let fileManager = FileManager.default
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.notchtodo.app"
        let directory = baseDirectory.appendingPathComponent(bundleIdentifier, isDirectory: true)
        return directory.appendingPathComponent(storeFilename)
    }

    private static func ensureStoreDirectory(for storeURL: URL) {
        let directory = storeURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            DebugLog.log("Failed to create Core Data directory: \(error)", category: .persistence)
        }
    }

    // MARK: - Schema Migration

    private func resetStoreIfNeeded(at url: URL) {
        let defaults = UserDefaults.standard
        let currentVersion = defaults.integer(forKey: Self.versionDefaultsKey)
        DebugLog.log("Current store version \(currentVersion); target \(Self.schemaVersion)", category: .persistence)
        guard currentVersion < Self.schemaVersion else { return }

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
            DebugLog.log("Removed store file \(fileURL.lastPathComponent)", category: .persistence)
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
