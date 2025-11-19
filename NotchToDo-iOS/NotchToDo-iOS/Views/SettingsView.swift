import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingSignOutAlert = false
    @State private var showingSyncInfo = false

    var body: some View {
        NavigationView {
            List {
                // Account Section
                Section("Account") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Signed In")
                                .font(.headline)
                            Text("Syncing with Supabase")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button(role: .destructive, action: { showingSignOutAlert = true }) {
                        Text("Sign Out")
                    }
                }

                // Sync Section
                Section("Sync") {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Auto-sync")
                        Spacer()
                        Text("Enabled")
                            .foregroundColor(.secondary)
                    }

                    Button(action: { dataManager.loadOrbs() }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Sync Now")
                        }
                    }

                    Button(action: { showingSyncInfo = true }) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("Sync Info")
                        }
                    }
                }

                // Data Section
                Section("Data") {
                    HStack {
                        Image(systemName: "folder")
                        Text("Orbs")
                        Spacer()
                        Text("\(dataManager.orbs.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Tasks")
                        Spacer()
                        Text("\(totalTaskCount)")
                            .foregroundColor(.secondary)
                    }
                }

                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/yourusername/notchtodo")!) {
                        HStack {
                            Image(systemName: "link")
                            Text("GitHub Repository")
                        }
                    }
                }

                // Debug Section (optional)
                #if DEBUG
                Section("Debug") {
                    Button(action: clearAllData) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Data")
                        }
                        .foregroundColor(.red)
                    }
                }
                #endif
            }
            .navigationTitle("Settings")
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    dataManager.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .sheet(isPresented: $showingSyncInfo) {
                SyncInfoView()
            }
        }
    }

    private var totalTaskCount: Int {
        dataManager.orbs.reduce(0) { $0 + $1.taskCount }
    }

    private func clearAllData() {
        dataManager.orbs.forEach { orb in
            dataManager.deleteOrb(orb)
        }
    }
}

struct SyncInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("How Sync Works") {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(
                            icon: "icloud.and.arrow.up",
                            title: "Automatic Sync",
                            description: "Changes are automatically synced to Supabase in the background."
                        )

                        InfoRow(
                            icon: "iphone.and.laptop",
                            title: "Cross-Platform",
                            description: "Your tasks sync seamlessly between iOS and macOS."
                        )

                        InfoRow(
                            icon: "wifi.slash",
                            title: "Offline Support",
                            description: "Make changes offline and they'll sync when you're back online."
                        )
                    }
                }

                Section("Sync Status") {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All changes synced")
                    }
                }
            }
            .navigationTitle("Sync Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
        .environmentObject(DataManager.shared)
}
