import SwiftUI

struct TasksView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedOrb: OrbModel?
    @State private var showingCreateTask = false
    @State private var searchText = ""

    var allTasks: [(orb: OrbModel, task: TaskModel)] {
        dataManager.orbs.flatMap { orb in
            orb.tasks.map { (orb: orb, task: $0) }
        }
    }

    var filteredTasks: [(orb: OrbModel, task: TaskModel)] {
        if searchText.isEmpty {
            return allTasks
        }
        return allTasks.filter { $0.task.title.localizedCaseInsensitiveContains(searchText) }
    }

    var groupedTasks: [(status: TaskModel.Status, tasks: [(orb: OrbModel, task: TaskModel)])] {
        let statuses: [TaskModel.Status] = [.outstanding, .inProgress, .complete]
        return statuses.map { status in
            let tasks = filteredTasks.filter { $0.task.statusEnum == status }
            return (status: status, tasks: tasks)
        }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(groupedTasks, id: \.status.rawValue) { group in
                    if !group.tasks.isEmpty {
                        Section(header: Text(group.status.displayName)) {
                            ForEach(group.tasks, id: \.task.id) { item in
                                NavigationLink(destination: TaskDetailView(task: item.task, orb: item.orb)) {
                                    TaskRowView(task: item.task, orb: item.orb)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search tasks")
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
