import CoreData
import Foundation

/// Handles converting the in-memory orb graph to Core Data entities and back, with
/// a debounced save queue so rapid UI changes do not hammer disk.
final class OrbPersistenceStore {
    private enum Keys {
        static let orbEntity = "OrbEntity"
        static let taskEntity = "TaskEntity"

        static let id = "id"
        static let name = "name"
        static let colorHex = "colorHex"
        static let sortOrder = "sortOrder"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
        static let tasks = "tasks"

        static let title = "title"
        static let notes = "notes"
        static let isCompleted = "isCompleted"
        static let priority = "priority"
        static let status = "status"
        static let dueDate = "dueDate"
        static let orb = "orb"
    }

    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private var pendingSaveWorkItem: DispatchWorkItem?
    private let queue = DispatchQueue(label: "com.notchtodo.persistence.save", qos: .utility)

    init(persistenceController: PersistenceController) {
        viewContext = persistenceController.container.viewContext
        backgroundContext = persistenceController.container.newBackgroundContext()
    }

    func loadSnapshots() throws -> [OrbSnapshot] {
        let request = NSFetchRequest<NSManagedObject>(entityName: Keys.orbEntity)
        request.sortDescriptors = [NSSortDescriptor(key: Keys.sortOrder, ascending: true)]
        let entities = try viewContext.fetch(request)
        return entities.map { orbSnapshot(from: $0) }
    }

    func scheduleSave(orbs snapshots: [OrbSnapshot]) {
        pendingSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.performSave(orbs: snapshots)
        }
        pendingSaveWorkItem = workItem
        queue.asyncAfter(deadline: .now() + 0.6, execute: workItem)
    }

    private func performSave(orbs snapshots: [OrbSnapshot]) {
        backgroundContext.perform { [weak self] in
            guard let self else { return }
            do {
                try self.syncSnapshots(orbs: snapshots, in: self.backgroundContext)
                if self.backgroundContext.hasChanges {
                    try self.backgroundContext.save()
                }
            } catch {
                DebugLog.log("Core Data save error: \(error)", category: .persistence)
                self.backgroundContext.reset()
            }
        }
    }

    private func syncSnapshots(orbs snapshots: [OrbSnapshot], in context: NSManagedObjectContext) throws {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: Keys.orbEntity)
        let existing = try context.fetch(fetchRequest)
        var orbsByID: [UUID: NSManagedObject] = [:]
        for entity in existing {
            if let id = entity.value(forKey: Keys.id) as? UUID {
                orbsByID[id] = entity
            }
        }

        let remainingIDs = Set(snapshots.map { $0.id })
        for (id, entity) in orbsByID where !remainingIDs.contains(id) {
            context.delete(entity)
        }

        for snapshot in snapshots {
            let entity = orbsByID[snapshot.id] ?? NSEntityDescription.insertNewObject(forEntityName: Keys.orbEntity, into: context)
            entity.setValue(snapshot.id, forKey: Keys.id)
            entity.setValue(snapshot.name, forKey: Keys.name)
            entity.setValue(snapshot.colorHex, forKey: Keys.colorHex)
            entity.setValue(snapshot.sortOrder as NSNumber, forKey: Keys.sortOrder)
            entity.setValue(snapshot.createdAt, forKey: Keys.createdAt)
            entity.setValue(snapshot.updatedAt, forKey: Keys.updatedAt)

            try syncTasks(for: entity, with: snapshot.tasks, in: context)
        }
    }

    private func syncTasks(for orb: NSManagedObject, with snapshots: [TaskSnapshot], in context: NSManagedObjectContext) throws {
        let tasksRelationship = orb.entity.relationshipsByName[Keys.tasks]
        let tasksAreToMany = tasksRelationship?.isToMany ?? true
        DebugLog.log("syncTasks: relationship isToMany=\(tasksRelationship?.isToMany.description ?? "nil") for orb \(orb.value(forKey: Keys.name) ?? "<unnamed>")", category: .persistence)

        let existingTasks = (orb.value(forKey: Keys.tasks) as? NSSet)?
            .compactMap { $0 as? NSManagedObject } ?? []
        DebugLog.log("syncTasks: existing related tasks=\(existingTasks.count)", category: .persistence)
        var tasksByID: [UUID: NSManagedObject] = [:]
        for task in existingTasks {
            if let id = task.value(forKey: Keys.id) as? UUID {
                tasksByID[id] = task
            }
        }

        let relationshipSet: NSMutableSet?
        if tasksAreToMany, tasksRelationship != nil {
            relationshipSet = orb.mutableSetValue(forKey: Keys.tasks)
        } else {
            relationshipSet = nil
        }
        var handled = Set<UUID>()
        for snapshot in snapshots {
            let task: NSManagedObject
            if let cached = tasksByID[snapshot.id] {
                task = cached
            } else {
                task = NSEntityDescription.insertNewObject(forEntityName: Keys.taskEntity, into: context)
                DebugLog.log("syncTasks: inserting task \(snapshot.title) (\(snapshot.id))", category: .persistence)
            }
            handled.insert(snapshot.id)

            task.setValue(snapshot.id, forKey: Keys.id)
            task.setValue(snapshot.title, forKey: Keys.title)
            task.setValue(snapshot.notes.isEmpty ? nil : snapshot.notes, forKey: Keys.notes)
            task.setValue(snapshot.isCompleted as NSNumber, forKey: Keys.isCompleted)
            task.setValue(Int16(snapshot.priority) as NSNumber, forKey: Keys.priority)
            task.setValue(snapshot.status as NSNumber, forKey: Keys.status)
            task.setValue(snapshot.createdAt, forKey: Keys.createdAt)
            task.setValue(snapshot.dueDate, forKey: Keys.dueDate)
            task.setValue(snapshot.sortOrder as NSNumber, forKey: Keys.sortOrder)
            if let orbRelationship = task.entity.relationshipsByName[Keys.orb], orbRelationship.isToMany {
                let set = task.mutableSetValue(forKey: Keys.orb)
                set.removeAllObjects()
                set.add(orb)
                DebugLog.log("syncTasks: assigned orb via to-many set for task \(snapshot.title)", category: .persistence)
            } else {
                task.setValue(orb, forKey: Keys.orb)
            }

            relationshipSet?.add(task)
        }

        for (id, task) in tasksByID where !handled.contains(id) {
            if let orbRelationship = task.entity.relationshipsByName[Keys.orb], orbRelationship.isToMany {
                let set = task.mutableSetValue(forKey: Keys.orb)
                set.remove(orb)
            }
            relationshipSet?.remove(task)
            context.delete(task)
            DebugLog.log("syncTasks: deleting task \(id)", category: .persistence)
        }
    }

    private func orbSnapshot(from entity: NSManagedObject) -> OrbSnapshot {
        let id = (entity.value(forKey: Keys.id) as? UUID) ?? UUID()
        let name = (entity.value(forKey: Keys.name) as? String) ?? "Untitled Orb"
        let colorHex = (entity.value(forKey: Keys.colorHex) as? String) ?? "#4F5FFF"
        let sortOrder = entity.value(forKey: Keys.sortOrder) as? Double ?? 0
        let createdAt = (entity.value(forKey: Keys.createdAt) as? Date) ?? Date()
        let updatedAt = entity.value(forKey: Keys.updatedAt) as? Date
        let taskSnapshots = taskSnapshots(for: entity)
        return OrbSnapshot(
            id: id,
            name: name,
            colorHex: colorHex,
            sortOrder: sortOrder,
            createdAt: createdAt,
            updatedAt: updatedAt,
            tasks: taskSnapshots
        )
    }

    private func taskSnapshots(for orb: NSManagedObject) -> [TaskSnapshot] {
        let tasksRelationship = orb.entity.relationshipsByName[Keys.tasks]
        let tasksAreToMany = tasksRelationship?.isToMany ?? true
        DebugLog.log("taskSnapshots: relationship isToMany=\(tasksRelationship?.isToMany.description ?? "nil") for orb \(orb.value(forKey: Keys.name) ?? "<unnamed>")", category: .persistence)

        let tasks: [NSManagedObject]
        if tasksAreToMany {
            tasks = (orb.value(forKey: Keys.tasks) as? NSSet)?
                .compactMap { $0 as? NSManagedObject } ?? []
            DebugLog.log("taskSnapshots: fetched from relationship set, count \(tasks.count)", category: .persistence)
        } else {
            let fetch = NSFetchRequest<NSManagedObject>(entityName: Keys.taskEntity)
            do {
                let allTasks = try orb.managedObjectContext?.fetch(fetch) ?? []
                tasks = allTasks.filter { task in
                    let value = task.value(forKey: Keys.orb)
                    if let linked = value as? NSManagedObject {
                        return linked == orb
                    } else if let set = value as? NSSet {
                        return set.contains(orb)
                    }
                    return false
                }
                DebugLog.log("taskSnapshots: filtered fetch count \(tasks.count)", category: .persistence)
            } catch {
                DebugLog.log("Failed to fetch tasks for orb: \(error)", category: .persistence)
                return []
            }
        }

        return tasks
            .sorted { (lhs, rhs) -> Bool in
                let l = lhs.value(forKey: Keys.sortOrder) as? Double ?? 0
                let r = rhs.value(forKey: Keys.sortOrder) as? Double ?? 0
                return l < r
            }
            .map { task in
                TaskSnapshot(
                    id: (task.value(forKey: Keys.id) as? UUID) ?? UUID(),
                    title: (task.value(forKey: Keys.title) as? String) ?? "",
                    notes: (task.value(forKey: Keys.notes) as? String) ?? "",
                    isCompleted: task.value(forKey: Keys.isCompleted) as? Bool ?? false,
                    priority: Int(task.value(forKey: Keys.priority) as? Int16 ?? 1),
                    status: task.value(forKey: Keys.status) as? Int16 ?? 1,
                    createdAt: (task.value(forKey: Keys.createdAt) as? Date) ?? Date(),
                    dueDate: task.value(forKey: Keys.dueDate) as? Date,
                    sortOrder: task.value(forKey: Keys.sortOrder) as? Double ?? 0
                )
            }
    }
}
