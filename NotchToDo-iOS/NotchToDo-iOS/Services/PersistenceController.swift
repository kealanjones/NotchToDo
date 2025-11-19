import CoreData
import Foundation

// iOS Core Data controller - simplified version of macOS controller
final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer
    private let backgroundContext: NSManagedObjectContext

    private init(inMemory: Bool = false) {
        // Load the Core Data model from the Shared bundle
        guard let modelURL = Bundle.main.url(forResource: "NotchDataModel", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load Core Data model")
        }

        container = NSPersistentContainer(name: "NotchDataModel", managedObjectModel: model)
        backgroundContext = container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        backgroundContext.automaticallyMergesChangesFromParent = true

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        } else {
            let storeURL = Self.storeURL()
            Self.ensureStoreDirectory(for: storeURL)
            DebugLog.log("Using Core Data store at \(storeURL.path)", category: .persistence)

            let description = NSPersistentStoreDescription(url: storeURL)
            description.shouldInferMappingModelAutomatically = true
            description.shouldMigrateStoreAutomatically = true

            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { description, error in
            if let error {
                fatalError("Core Data store failed to load: \(error)")
            }
            DebugLog.log("Core Data store loaded successfully", category: .persistence)
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private static func storeURL() -> URL {
        let fileManager = FileManager.default
        let baseDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        return baseDirectory.appendingPathComponent("NotchDataModel.sqlite")
    }

    private static func ensureStoreDirectory(for storeURL: URL) {
        let directory = storeURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            DebugLog.log("Failed to create Core Data directory: \(error)", category: .persistence)
        }
    }

    // MARK: - Data Operations

    func fetchOrbs() -> [OrbSnapshot] {
        let context = container.viewContext
        let request: NSFetchRequest<OrbEntity> = OrbEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        request.predicate = NSPredicate(format: "deletedAt == nil")

        do {
            let entities = try context.fetch(request)
            return entities.map { orbEntity in
                let taskRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
                taskRequest.predicate = NSPredicate(format: "orb == %@ AND deletedAt == nil", orbEntity)
                taskRequest.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

                let taskEntities = (try? context.fetch(taskRequest)) ?? []
                let tasks = taskEntities.map { taskEntity in
                    TaskSnapshot(
                        id: taskEntity.id ?? UUID(),
                        title: taskEntity.title ?? "Untitled",
                        notes: taskEntity.notes ?? "",
                        isCompleted: taskEntity.isCompleted,
                        priority: Int(taskEntity.priority),
                        status: taskEntity.status,
                        createdAt: taskEntity.createdAt ?? Date(),
                        dueDate: taskEntity.dueDate,
                        sortOrder: taskEntity.sortOrder
                    )
                }

                return OrbSnapshot(
                    id: orbEntity.id ?? UUID(),
                    name: orbEntity.name ?? "Untitled Orb",
                    colorHex: orbEntity.colorHex ?? "#4F5FFF",
                    sortOrder: orbEntity.sortOrder,
                    createdAt: orbEntity.createdAt ?? Date(),
                    updatedAt: orbEntity.updatedAt,
                    tasks: tasks
                )
            }
        } catch {
            DebugLog.log("Failed to fetch orbs: \(error)", category: .persistence)
            return []
        }
    }

    func saveOrb(_ snapshot: OrbSnapshot) {
        let context = container.viewContext
        context.perform {
            let request: NSFetchRequest<OrbEntity> = OrbEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", snapshot.id as CVarArg)
            request.fetchLimit = 1

            let entity = (try? context.fetch(request).first) ?? OrbEntity(context: context)
            entity.id = snapshot.id
            entity.name = snapshot.name
            entity.colorHex = snapshot.colorHex
            entity.sortOrder = snapshot.sortOrder
            entity.createdAt = snapshot.createdAt
            entity.updatedAt = snapshot.updatedAt ?? Date()
            entity.needsSync = true

            // Save tasks
            for taskSnapshot in snapshot.tasks {
                let taskRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
                taskRequest.predicate = NSPredicate(format: "id == %@", taskSnapshot.id as CVarArg)
                taskRequest.fetchLimit = 1

                let taskEntity = (try? context.fetch(taskRequest).first) ?? TaskEntity(context: context)
                taskEntity.id = taskSnapshot.id
                taskEntity.title = taskSnapshot.title
                taskEntity.notes = taskSnapshot.notes
                taskEntity.isCompleted = taskSnapshot.isCompleted
                taskEntity.priority = Int16(taskSnapshot.priority)
                taskEntity.status = taskSnapshot.status
                taskEntity.sortOrder = taskSnapshot.sortOrder
                taskEntity.createdAt = taskSnapshot.createdAt
                taskEntity.dueDate = taskSnapshot.dueDate
                taskEntity.orb = entity
                taskEntity.needsSync = true
            }

            do {
                if context.hasChanges {
                    try context.save()
                    DebugLog.log("Saved orb: \(snapshot.name)", category: .persistence)
                }
            } catch {
                DebugLog.log("Failed to save orb: \(error)", category: .persistence)
            }
        }
    }

    func deleteOrb(_ orbID: UUID) {
        let context = container.viewContext
        context.perform {
            let request: NSFetchRequest<OrbEntity> = OrbEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", orbID as CVarArg)

            do {
                let entities = try context.fetch(request)
                for entity in entities {
                    entity.deletedAt = Date()
                    entity.needsSync = true
                }
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                DebugLog.log("Failed to delete orb: \(error)", category: .persistence)
            }
        }
    }

    func deleteTask(_ taskID: UUID) {
        let context = container.viewContext
        context.perform {
            let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", taskID as CVarArg)

            do {
                let entities = try context.fetch(request)
                for entity in entities {
                    entity.deletedAt = Date()
                    entity.needsSync = true
                }
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                DebugLog.log("Failed to delete task: \(error)", category: .persistence)
            }
        }
    }
}
