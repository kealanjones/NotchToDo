import Cocoa
import Combine
import CoreData
import Foundation

/// Central data store that serves as the single observable mediator between
/// Core Data (source of truth) and in-memory UI models (ProjectOrb/Task).
///
/// Architecture:
///   Core Data <-> DataStore <-> ProjectOrb/Task (in-memory, with animation state)
///
/// This replaces the old OrbPersistenceStore + OrbManager persistence coupling,
/// which had multiple save paths, manual outbox workarounds, and snapshot-based
/// full-graph serialization.
///
/// Key improvements:
/// - Single save path: all changes flow through repositories -> ChangeTracker
/// - Incremental updates: only changed fields are written, not entire graph
/// - Debounced persistence with immediate flush for critical edits
/// - Clean reload from Core Data after remote sync pulls
final class DataStore: ObservableObject {
    let orbRepository: OrbRepository
    let taskRepository: TaskRepository
    let changeTracker: ChangeTracker

    /// The in-memory OrbManager (owns ProjectOrb instances for UI/physics).
    let orbManager: OrbManager

    private let viewContext: NSManagedObjectContext
    private var saveWorkItem: DispatchWorkItem?
    private let saveQueue = DispatchQueue(label: "com.notchtodo.datastore.save", qos: .utility)
    private var isLoaded = false
    private var isSuppressingCallbacks = false

    init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.changeTracker = ChangeTracker(container: container)
        self.orbRepository = OrbRepository(context: container.viewContext, changeTracker: changeTracker)
        self.taskRepository = TaskRepository(context: container.viewContext, changeTracker: changeTracker)
        self.orbManager = OrbManager(includeSampleData: false)

        // Wire up the OrbManager's onChange to debounced persistence
        orbManager.onChange = { [weak self] in
            guard let self, !self.isSuppressingCallbacks else { return }
            self.scheduleSave()
        }

        changeTracker.performMaintenance()
    }

    // MARK: - Load

    /// Load all data from Core Data into in-memory models.
    /// Called after authentication succeeds.
    func loadFromPersistence() {
        do {
            let orbEntities = try orbRepository.fetchAll()
            let snapshots = orbEntities.map { self.snapshotFromEntity($0) }
            isSuppressingCallbacks = true
            orbManager.applySnapshots(snapshots)
            isSuppressingCallbacks = false
            isLoaded = true
            DebugLog.log("DataStore: loaded \(orbEntities.count) orbs from Core Data", category: .persistence)
        } catch {
            DebugLog.log("DataStore: failed to load from Core Data: \(error)", category: .persistence)
            isSuppressingCallbacks = true
            orbManager.applySnapshots([])
            isSuppressingCallbacks = false
        }
    }

    /// Reload from Core Data after a remote sync pull. Merges remote changes
    /// into the in-memory model without losing animation state.
    func reloadFromPersistence() {
        loadFromPersistence()
    }

    // MARK: - Create Operations

    /// Create a new orb (project) in Core Data and in-memory.
    @discardableResult
    func createOrb(name: String) -> ProjectOrb {
        // Create in-memory first for immediate UI feedback
        // OrbManager.createOrb assigns color and sort order internally
        let orb = orbManager.createOrb(name: name)

        // Persist to Core Data
        do {
            try orbRepository.create(
                id: orb.id,
                name: name,
                colorHex: orb.color.toHexString(),
                sortOrder: orb.sortOrder,
                createdAt: orb.createdAt
            )
        } catch {
            DebugLog.log("DataStore: failed to persist new orb: \(error)", category: .persistence)
        }

        return orb
    }

    /// Add a task to an orb. Creates in Core Data and in-memory.
    func addTask(title: String, to orb: ProjectOrb) {
        orb.addTask(title: title)
        persistOrbTasks(orb)
    }

    /// Add an advanced task (from voice intent) to an orb.
    func addTask(from intent: TaskIntent, to orb: ProjectOrb) {
        orb.addTask(from: intent)
        persistOrbTasks(orb)
    }

    // MARK: - Update Operations

    /// Persist the current state of a specific orb's tasks to Core Data.
    /// Used after task additions, deletions, reordering, or edits.
    func persistOrbTasks(_ orb: ProjectOrb) {
        guard let orbEntity = try? orbRepository.fetch(byID: orb.id) else {
            DebugLog.log("DataStore: orb entity not found for \(orb.name)", category: .persistence)
            return
        }

        do {
            let existingTasks = try taskRepository.fetchAll(for: orbEntity)
            var tasksByID: [UUID: TaskEntity] = [:]
            for task in existingTasks {
                tasksByID[task.id] = task
            }

            let inMemoryIDs = Set(orb.tasks.map { $0.id })

            // Delete tasks that no longer exist in memory
            for (id, entity) in tasksByID where !inMemoryIDs.contains(id) {
                try taskRepository.delete(entity)
            }

            // Create or update tasks
            for (index, task) in orb.tasks.enumerated() {
                if let existing = tasksByID[task.id] {
                    // Update existing
                    try taskRepository.update(
                        existing,
                        title: task.title,
                        notes: task.details.isEmpty ? nil : task.details,
                        isCompleted: task.isCompleted,
                        priority: Int16(task.priority),
                        status: task.status,
                        dueDate: task.deadline,
                        sortOrder: Double(index)
                    )
                } else {
                    // Create new
                    try taskRepository.create(
                        id: task.id,
                        title: task.title,
                        notes: task.details.isEmpty ? nil : task.details,
                        isCompleted: task.isCompleted,
                        priority: Int16(task.priority),
                        status: task.status,
                        dueDate: task.deadline,
                        sortOrder: Double(index),
                        orb: orbEntity,
                        createdAt: task.createdAt
                    )
                }
            }
        } catch {
            DebugLog.log("DataStore: failed to persist tasks for \(orb.name): \(error)", category: .persistence)
        }
    }

    // MARK: - Delete Operations

    /// Delete an orb and all its tasks from Core Data.
    func deleteOrb(_ orb: ProjectOrb) {
        guard let entity = try? orbRepository.fetch(byID: orb.id) else { return }
        do {
            try orbRepository.delete(entity)
        } catch {
            DebugLog.log("DataStore: failed to delete orb: \(error)", category: .persistence)
        }
    }

    /// Delete a task from Core Data.
    func deleteTask(_ task: Task) {
        guard let entity = try? taskRepository.fetch(byID: task.id) else { return }
        do {
            try taskRepository.delete(entity)
        } catch {
            DebugLog.log("DataStore: failed to delete task: \(error)", category: .persistence)
        }
    }

    /// Clear all local data (on sign-out).
    func clearAllData() {
        isSuppressingCallbacks = true
        orbManager.clearAllOrbs()
        isSuppressingCallbacks = false

        do {
            try taskRepository.deleteAll()
            try orbRepository.deleteAll()
            changeTracker.purgeAll()
            DebugLog.log("DataStore: cleared all data", category: .persistence)
        } catch {
            DebugLog.log("DataStore: failed to clear data: \(error)", category: .persistence)
        }
    }

    // MARK: - Debounced Save

    /// Schedule a debounced save of the entire in-memory state.
    /// This is the fallback path for when the onChange callback fires
    /// (e.g., from task title edits, completion toggles, etc.)
    private func scheduleSave() {
        saveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.performFullSave()
        }
        saveWorkItem = workItem
        saveQueue.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    /// Immediately persist all in-memory state. Used before closing windows
    /// or when the user expects immediate feedback.
    func saveImmediately() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        saveQueue.sync { [weak self] in
            self?.performFullSave()
        }
    }

    private func performFullSave() {
        let orbs = orbManager.orbs
        for orb in orbs {
            // Ensure orb entity exists
            do {
                if let entity = try orbRepository.fetch(byID: orb.id) {
                    try orbRepository.update(
                        entity,
                        name: orb.name,
                        colorHex: orb.color.toHexString(),
                        sortOrder: orb.sortOrder
                    )
                } else {
                    try orbRepository.create(
                        id: orb.id,
                        name: orb.name,
                        colorHex: orb.color.toHexString(),
                        sortOrder: orb.sortOrder,
                        createdAt: orb.createdAt
                    )
                }
            } catch {
                DebugLog.log("DataStore: full save failed for orb \(orb.name): \(error)", category: .persistence)
            }
            persistOrbTasks(orb)
        }
    }

    // MARK: - Helpers

    /// Resolve the target orb for a new task: either the currently open orb
    /// or the "Captured Tasks" fallback orb.
    func resolveTargetOrb(currentOpenOrb: ProjectOrb?) -> ProjectOrb {
        if let open = currentOpenOrb {
            return open
        }
        return orbManager.findOrCreateCapturedTasksOrb()
    }

    private func snapshotFromEntity(_ entity: OrbEntity) -> OrbSnapshot {
        let tasks = (entity.tasks ?? []).sorted { $0.sortOrder < $1.sortOrder }
        return OrbSnapshot(
            id: entity.id,
            name: entity.name,
            colorHex: entity.colorHex,
            sortOrder: entity.sortOrder,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            tasks: tasks.map { task in
                TaskSnapshot(
                    id: task.id,
                    title: task.title,
                    notes: task.notes ?? "",
                    isCompleted: task.isCompleted,
                    priority: Int(task.priority),
                    status: task.status,
                    createdAt: task.createdAt,
                    dueDate: task.dueDate,
                    sortOrder: task.sortOrder
                )
            }
        )
    }
}
