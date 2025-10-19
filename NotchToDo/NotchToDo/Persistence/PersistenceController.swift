import CoreData
import Foundation

// Central Core Data bootstrapper. Creates the persistent container that we can
// share between the overlay controller, repositories, and future extensions (e.g. iOS).
final class PersistenceController {
    static let shared = PersistenceController()

    private static let schemaVersion = 2
    private static let versionDefaultsKey = "OrbPersistenceSchemaVersion"
    private static let storeFilename = "NotchDataModel.sqlite"

    let container: NSPersistentContainer

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

        container.loadPersistentStores { description, error in
            if let error {
                fatalError("Core Data store failed to load: \(error)")
            }

            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
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
    }

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
