import SwiftUI
import Speech

struct CreateTaskView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    var preselectedOrb: OrbModel?

    @State private var taskTitle = ""
    @State private var taskNotes = ""
    @State private var selectedOrb: OrbModel?
    @State private var selectedStatus: TaskModel.Status = .outstanding
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var showingVoiceInput = false

    var body: some View {
        NavigationView {
            Form {
                // Title Section
                Section("Task Title") {
                    HStack {
                        TextField("Enter task title", text: $taskTitle)

                        Button(action: { showingVoiceInput = true }) {
                            Image(systemName: "mic.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }

                // Orb Selection
                Section("Orb") {
                    Picker("Select Orb", selection: $selectedOrb) {
                        Text("Select...").tag(nil as OrbModel?)
                        ForEach(dataManager.orbs) { orb in
                            HStack {
                                Circle()
                                    .fill(Color(orb.color))
                                    .frame(width: 16, height: 16)
                                Text(orb.name)
                            }
                            .tag(orb as OrbModel?)
                        }
                    }
                }

                // Status Section
                Section("Status") {
                    Picker("Status", selection: $selectedStatus) {
                        ForEach([TaskModel.Status.outstanding, .inProgress, .complete], id: \.rawValue) { status in
                            HStack {
                                Image(systemName: status.iconName)
                                Text(status.displayName)
                            }
                            .tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Due Date Section
                Section {
                    Toggle("Add Due Date", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date])
                    }
                }

                // Notes Section
                Section("Notes (Optional)") {
                    TextEditor(text: $taskNotes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createTask()
                    }
                    .disabled(taskTitle.isEmpty || selectedOrb == nil)
                }
            }
            .sheet(isPresented: $showingVoiceInput) {
                VoiceInputView(recognizedText: $taskTitle)
            }
            .onAppear {
                if let preselected = preselectedOrb {
                    selectedOrb = preselected
                } else if dataManager.orbs.count == 1 {
                    selectedOrb = dataManager.orbs.first
                }
            }
        }
    }

    private func createTask() {
        guard let orb = selectedOrb else { return }

        let task = TaskModel(
            title: taskTitle,
            isCompleted: false,
            details: taskNotes,
            deadline: hasDueDate ? dueDate : nil,
            priority: 1,
            status: selectedStatus.rawValue,
            createdAt: Date(),
            sortOrder: Double(orb.tasks.count)
        )

        orb.addTask(task)
        dataManager.saveOrb(orb)
        dismiss()
    }
}

#Preview {
    CreateTaskView()
        .environmentObject(DataManager.shared)
}
