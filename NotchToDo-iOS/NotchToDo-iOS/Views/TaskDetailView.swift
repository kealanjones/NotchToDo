import SwiftUI

struct TaskDetailView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var task: TaskModel
    let orb: OrbModel

    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            // Title Section
            Section {
                if isEditing {
                    TextField("Task Title", text: $task.title)
                        .font(.title3)
                } else {
                    Text(task.title)
                        .font(.title3)
                }
            }

            // Status Section
            Section("Status") {
                Picker("Status", selection: $task.status) {
                    ForEach([TaskModel.Status.outstanding, .inProgress, .complete], id: \.rawValue) { status in
                        HStack {
                            Image(systemName: status.iconName)
                            Text(status.displayName)
                        }
                        .tag(status.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!isEditing)
                .onChange(of: task.status) { _ in
                    dataManager.updateTask(task, in: orb)
                }
            }

            // Details Section
            Section("Details") {
                HStack {
                    Image(systemName: "folder")
                    Text("Orb")
                    Spacer()
                    Circle()
                        .fill(Color(orb.color))
                        .frame(width: 12, height: 12)
                    Text(orb.name)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Image(systemName: "calendar")
                    Text("Created")
                    Spacer()
                    Text(task.createdAt, style: .date)
                        .foregroundColor(.secondary)
                }

                if let deadline = task.deadline {
                    DatePicker("Due Date", selection: Binding(
                        get: { deadline },
                        set: { task.deadline = $0 }
                    ), displayedComponents: [.date])
                    .disabled(!isEditing)
                } else if isEditing {
                    Button(action: { task.deadline = Date() }) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                            Text("Add Due Date")
                        }
                    }
                }
            }

            // Notes Section
            Section("Notes") {
                if isEditing {
                    TextEditor(text: $task.details)
                        .frame(minHeight: 100)
                } else {
                    Text(task.details.isEmpty ? "No notes" : task.details)
                        .foregroundColor(task.details.isEmpty ? .secondary : .primary)
                }
            }

            // Delete Section
            if isEditing {
                Section {
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Task")
                        }
                    }
                }
            }
        }
        .navigationTitle("Task Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        dataManager.updateTask(task, in: orb)
                    }
                    isEditing.toggle()
                }
            }
        }
        .alert("Delete Task", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                dataManager.deleteTask(task, from: orb)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this task?")
        }
    }
}
