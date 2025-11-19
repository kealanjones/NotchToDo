import Foundation
import Combine

// Central data manager that coordinates between Core Data and Supabase
class DataManager: ObservableObject {
    static let shared = DataManager()

    @Published var orbs: [OrbModel] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let persistence = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    private var supabaseService: SupabaseService?
    private var authManager: SupabaseAuthManager?

    private init() {
        setupSupabase()
        loadOrbs()
        observeDataChanges()
    }

    private func setupSupabase() {
        // Load Supabase configuration from Info.plist
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              let url = URL(string: urlString),
              let anonKey = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String else {
            DebugLog.log("Supabase configuration missing from Info.plist", category: .sync)
            return
        }

        let config = SupabaseService.Configuration(
            projectURL: url,
            anonKey: anonKey,
            storageBucket: "attachments"
        )
        supabaseService = SupabaseService(configuration: config)
        authManager = SupabaseAuthManager(service: supabaseService!)
    }

    private func observeDataChanges() {
        NotificationCenter.default.publisher(for: .supabaseDataDidPull)
            .sink { [weak self] _ in
                self?.loadOrbs()
            }
            .store(in: &cancellables)
    }

    func loadOrbs() {
        isLoading = true
        let snapshots = persistence.fetchOrbs()

        orbs = snapshots.map { snapshot in
            let color = PlatformColor.fromHexString(snapshot.colorHex) ?? OrbColorPalette.getColor(for: 0)
            let orb = OrbModel(
                id: snapshot.id,
                name: snapshot.name,
                color: color,
                createdAt: snapshot.createdAt,
                sortOrder: snapshot.sortOrder
            )
            orb.updatedAt = snapshot.updatedAt

            // Convert tasks
            orb.tasks = snapshot.tasks.map { taskSnapshot in
                TaskModel(
                    id: taskSnapshot.id,
                    title: taskSnapshot.title,
                    isCompleted: taskSnapshot.isCompleted,
                    details: taskSnapshot.notes,
                    deadline: taskSnapshot.dueDate,
                    priority: taskSnapshot.priority,
                    status: taskSnapshot.status,
                    createdAt: taskSnapshot.createdAt,
                    sortOrder: taskSnapshot.sortOrder
                )
            }
            orb.taskCount = orb.tasks.count

            return orb
        }

        isLoading = false
        DebugLog.log("Loaded \(orbs.count) orbs from Core Data", category: .persistence)
    }

    func saveOrb(_ orb: OrbModel) {
        let taskSnapshots = orb.tasks.map { task in
            TaskSnapshot(
                id: task.id,
                title: task.title,
                notes: task.details,
                isCompleted: task.isCompleted,
                priority: task.priority,
                status: task.status,
                createdAt: task.createdAt,
                dueDate: task.deadline,
                sortOrder: task.sortOrder
            )
        }

        let snapshot = OrbSnapshot(
            id: orb.id,
            name: orb.name,
            colorHex: orb.color.toHexString(),
            sortOrder: orb.sortOrder,
            createdAt: orb.createdAt,
            updatedAt: orb.updatedAt,
            tasks: taskSnapshots
        )

        persistence.saveOrb(snapshot)
    }

    func createOrb(name: String) {
        let color = OrbColorPalette.getUniqueColor(for: orbs.count)
        let orb = OrbModel(
            name: name,
            color: color,
            createdAt: Date(),
            sortOrder: Double(orbs.count)
        )
        orbs.append(orb)
        saveOrb(orb)
    }

    func deleteOrb(_ orb: OrbModel) {
        orbs.removeAll { $0.id == orb.id }
        persistence.deleteOrb(orb.id)
    }

    func createTask(in orb: OrbModel, title: String) {
        let task = TaskModel(
            title: title,
            status: 1, // Outstanding
            createdAt: Date(),
            sortOrder: Double(orb.tasks.count)
        )
        orb.addTask(task)
        saveOrb(orb)
    }

    func deleteTask(_ task: TaskModel, from orb: OrbModel) {
        _ = orb.removeTask(task)
        persistence.deleteTask(task.id)
        saveOrb(orb)
    }

    func updateTask(_ task: TaskModel, in orb: OrbModel) {
        saveOrb(orb)
    }

    // MARK: - Authentication

    func signIn(email: String, password: String) async throws {
        guard let authManager = authManager else {
            throw NSError(domain: "DataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Auth manager not initialized"])
        }
        try await authManager.signIn(email: email, password: password)
        loadOrbs() // Reload data after sign in
    }

    func signUp(email: String, password: String) async throws {
        guard let authManager = authManager else {
            throw NSError(domain: "DataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Auth manager not initialized"])
        }
        try await authManager.signUp(email: email, password: password)
        loadOrbs()
    }

    func signOut() {
        authManager?.clearSession()
        orbs.removeAll()
    }

    var isAuthenticated: Bool {
        authManager?.currentSession != nil
    }
}
