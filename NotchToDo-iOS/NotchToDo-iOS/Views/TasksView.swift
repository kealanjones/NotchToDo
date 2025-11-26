import SwiftUI
import Combine

/// Helper struct to hold task with its parent orb
struct TaskWithOrb: Identifiable {
    let orb: OrbModel
    let task: TaskModel
    var id: UUID { task.id }
}

/// View model to cache and optimize task computations with debounced search
@MainActor
class TasksViewModel: ObservableObject {
    @Published private(set) var allTasks: [TaskWithOrb] = []
    @Published var searchText: String = ""
    @Published private(set) var groupedTasks: [(status: TaskModel.Status, tasks: [TaskWithOrb])] = []
    @Published private(set) var isSearching: Bool = false
    
    private var filteredTasks: [TaskWithOrb] = []
    private var cancellables = Set<AnyCancellable>()
    
    /// Debounce interval in seconds
    private let searchDebounceInterval: TimeInterval = 0.3
    
    init() {
        setupSearchDebouncing()
    }
    
    private func setupSearchDebouncing() {
        // Debounce search text changes to avoid excessive filtering
        $searchText
            .debounce(for: .seconds(searchDebounceInterval), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.isSearching = false
                self?.updateFilteredTasks()
            }
            .store(in: &cancellables)
        
        // Show searching indicator immediately when user starts typing
        $searchText
            .dropFirst() // Skip initial value
            .filter { !$0.isEmpty }
            .sink { [weak self] _ in
                self?.isSearching = true
            }
            .store(in: &cancellables)
    }
    
    func updateFromOrbs(_ orbs: [OrbModel]) {
        // Only rebuild if the data actually changed
        let newTasks = orbs.flatMap { orb in
            orb.tasks.map { TaskWithOrb(orb: orb, task: $0) }
        }
        
        // Compare task IDs to avoid unnecessary updates
        let newIds = Set(newTasks.map { $0.id })
        let currentIds = Set(allTasks.map { $0.id })
        
        if newIds != currentIds || newTasks.count != allTasks.count {
            allTasks = newTasks
            updateFilteredTasks()
        }
    }
    
    private func updateFilteredTasks() {
        if searchText.isEmpty {
            filteredTasks = allTasks
        } else {
            let searchTerms = searchText.lowercased()
            filteredTasks = allTasks.filter { item in
                // Search in title
                item.task.title.lowercased().contains(searchTerms) ||
                // Also search in orb name for better discoverability
                item.orb.name.lowercased().contains(searchTerms)
            }
        }
        updateGroupedTasks()
    }
    
    private func updateGroupedTasks() {
        let statuses: [TaskModel.Status] = [.outstanding, .inProgress, .complete]
        groupedTasks = statuses.map { status in
            let tasks = filteredTasks.filter { $0.task.statusEnum == status }
            return (status: status, tasks: tasks)
        }
    }
    
    /// Immediately execute search without waiting for debounce (e.g., for "search" button)
    func executeSearchImmediately() {
        isSearching = false
        updateFilteredTasks()
    }
    
    /// Clear search text
    func clearSearch() {
        searchText = ""
        isSearching = false
        updateFilteredTasks()
    }
}

struct TasksView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var viewModel = TasksViewModel()
    @State private var selectedOrb: OrbModel?
    @State private var showingCreateTask = false

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.groupedTasks, id: \.status.rawValue) { group in
                    if !group.tasks.isEmpty {
                        Section(header: Text(group.status.displayName)) {
                            ForEach(group.tasks) { item in
                                NavigationLink(destination: TaskDetailView(task: item.task, orb: item.orb)) {
                                    TaskRowView(task: item.task, orb: item.orb)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search tasks")
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateTask = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateTask) {
                CreateTaskView()
            }
            .onAppear {
                viewModel.updateFromOrbs(dataManager.orbs)
            }
            .onChange(of: dataManager.orbs) { newOrbs in
                viewModel.updateFromOrbs(newOrbs)
            }
        }
    }
}

struct TaskRowView: View {
    @ObservedObject var task: TaskModel
    let orb: OrbModel

    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            Image(systemName: task.statusEnum.iconName)
                .font(.title3)
                .foregroundColor(Color(orb.color))

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted)

                HStack(spacing: 8) {
                    // Orb badge
                    Circle()
                        .fill(Color(orb.color))
                        .frame(width: 8, height: 8)
                    Text(orb.name)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let deadline = task.deadline {
                        Text("Due \(deadline, style: .date)")
                            .font(.caption)
                            .foregroundColor(deadline < Date() ? .red : .secondary)
                    }
                }
            }

            Spacer()

            if task.noteCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.caption)
                    Text("\(task.noteCount)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TasksView()
        .environmentObject(DataManager.shared)
}
