import Foundation

// MARK: - Task Data Model (iOS-compatible)
class TaskModel: ObservableObject, Identifiable {
    let id: UUID
    @Published var title: String
    @Published var isCompleted: Bool
    @Published var details: String
    @Published var deadline: Date?
    @Published var priority: Int
    @Published var status: Int16 // 1=Outstanding, 2=In Progress, 3=Complete
    var createdAt: Date
    var sortOrder: Double
    @Published private(set) var noteCount: Int = 0

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        details: String = "",
        deadline: Date? = nil,
        priority: Int = 1,
        status: Int16 = 1,
        createdAt: Date = Date(),
        sortOrder: Double = 0.0
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.details = details
        self.deadline = deadline
        self.priority = priority
        self.status = status
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        updateNoteCount()
    }

    private func updateNoteCount() {
        noteCount = TaskModel.calculateNoteCount(from: details)
    }

    private static func calculateNoteCount(from details: String) -> Int {
        guard !details.isEmpty else { return 0 }
        if let data = details.data(using: .utf8),
           let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return array.count
        }
        let lines = details
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.count
    }
}

// MARK: - Task Status Extension
extension TaskModel {
    enum Status: Int16 {
        case outstanding = 1
        case inProgress = 2
        case complete = 3

        var displayName: String {
            switch self {
            case .outstanding: return "Outstanding"
            case .inProgress: return "In Progress"
            case .complete: return "Complete"
            }
        }

        var iconName: String {
            switch self {
            case .outstanding: return "circle"
            case .inProgress: return "circle.lefthalf.filled"
            case .complete: return "checkmark.circle.fill"
            }
        }
    }

    var statusEnum: Status {
        get { Status(rawValue: status) ?? .outstanding }
        set { status = newValue.rawValue }
    }
}
