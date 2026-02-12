import CoreData
import Foundation

/// Legacy bridge that wraps the new DataStore for backward compatibility.
/// The old OrbPersistenceStore handled all Core Data interactions directly with
/// snapshot-based serialization, multiple save paths, and manual outbox management.
///
/// This replacement delegates everything to DataStore, which uses proper
/// repositories and a unified ChangeTracker.
///
/// Consumers that previously used OrbPersistenceStore should migrate to
/// DataStore directly. This class exists to minimize changes in
/// NotchOverlayController during the transition.
final class OrbPersistenceStore {
    private let dataStore: DataStore

    init(dataStore: DataStore) {
        self.dataStore = dataStore
    }

    /// Convenience initializer for legacy callers that pass PersistenceController.
    /// Creates a DataStore internally.
    init(persistenceController: PersistenceController) {
        self.dataStore = DataStore(container: persistenceController.container)
    }

    func loadSnapshots() throws -> [OrbSnapshot] {
        let entities = try dataStore.orbRepository.fetchAll()
        return entities.map { entity in
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

    func deleteAllData() throws {
        dataStore.clearAllData()
    }

    func scheduleSave(orbs snapshots: [OrbSnapshot]) {
        // The new system uses debounced saves through DataStore.
        // This is now a no-op because DataStore handles save scheduling
        // through the OrbManager.onChange callback.
    }

    func saveImmediately(orbs snapshots: [OrbSnapshot]) {
        dataStore.saveImmediately()
    }
}
