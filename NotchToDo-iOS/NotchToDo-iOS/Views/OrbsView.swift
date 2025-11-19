import SwiftUI

struct OrbsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingCreateOrb = false
    @State private var newOrbName = ""

    var body: some View {
        NavigationView {
            List {
                ForEach(dataManager.orbs) { orb in
                    NavigationLink(destination: OrbDetailView(orb: orb)) {
                        OrbRowView(orb: orb)
                    }
                }
                .onDelete(perform: deleteOrbs)
            }
            .navigationTitle("Orbs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateOrb = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateOrb) {
                CreateOrbView()
            }
        }
    }

    private func deleteOrbs(at offsets: IndexSet) {
        for index in offsets {
            let orb = dataManager.orbs[index]
            dataManager.deleteOrb(orb)
        }
    }
}

struct OrbRowView: View {
    @ObservedObject var orb: OrbModel

    var body: some View {
        HStack(spacing: 16) {
            // Orb color circle
            Circle()
                .fill(Color(orb.color))
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(orb.name)
                    .font(.headline)

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.caption)
                    Text("\(orb.taskCount) tasks")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct CreateOrbView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var orbName = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Orb Name") {
                    TextField("Enter orb name", text: $orbName)
                }
            }
            .navigationTitle("New Orb")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        dataManager.createOrb(name: orbName)
                        dismiss()
                    }
                    .disabled(orbName.isEmpty)
                }
            }
        }
    }
}

struct OrbDetailView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var orb: OrbModel
    @State private var showingCreateTask = false
    @State private var isEditingName = false
    @State private var editedName = ""

    var body: some View {
        List {
            // Orb Info Section
            Section {
                HStack {
                    Circle()
                        .fill(Color(orb.color))
                        .frame(width: 60, height: 60)

                    VStack(alignment: .leading, spacing: 4) {
                        if isEditingName {
                            TextField("Orb Name", text: $editedName)
                                .font(.title2)
                        } else {
                            Text(orb.name)
                                .font(.title2)
                                .fontWeight(.bold)
                        }

                        Text("\(orb.taskCount) tasks")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(isEditingName ? "Done" : "Edit") {
                        if isEditingName {
                            orb.name = editedName
                            dataManager.saveOrb(orb)
                        } else {
                            editedName = orb.name
                        }
                        isEditingName.toggle()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 8)
            }

            // Tasks Section
            Section("Tasks") {
                if orb.tasks.isEmpty {
                    Text("No tasks yet")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(orb.tasks) { task in
                        NavigationLink(destination: TaskDetailView(task: task, orb: orb)) {
                            TaskRowView(task: task, orb: orb)
                        }
                    }
                }
            }

            // Add Task Button
            Section {
                Button(action: { showingCreateTask = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Task")
                    }
                }
            }
        }
        .navigationTitle("Orb Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCreateTask) {
            CreateTaskView(preselectedOrb: orb)
        }
    }
}

#Preview {
    OrbsView()
        .environmentObject(DataManager.shared)
}
