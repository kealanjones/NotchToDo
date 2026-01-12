import Foundation

#if canImport(Combine)
import Combine
#endif

// MARK: - Task Data Model (Cross-platform)
public class TaskModel: ObservableObject, Identifiable {
    public let id: UUID
    @Published public var title: String
    @Published public var isCompleted: Bool
    @Published public var details: String
    @Published public var deadline: Date?
    @Published public var priority: Int
    @Published public var status: Int16 // 1=Outstanding, 2=In Progress, 3=Complete
    public let createdAt: Date  // Immutable - set once at creation
    @Published public var sortOrder: Double
    @Published public private(set) var noteCount: Int = 0
    
    /// Callback for change notifications (used by macOS for persistence)
    public var onChange: (() -> Void)?

    public init(
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
    
    /// Notify observers of changes (for macOS persistence integration)
    public func notifyChange() {
        onChange?()
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
public extension TaskModel {
    enum Status: Int16 {
        case outstanding = 1
        case inProgress = 2
        case complete = 3

        public var displayName: String {
            switch self {
            case .outstanding: return "Outstanding"
            case .inProgress: return "In Progress"
            case .complete: return "Complete"
            }
        }

        public var iconName: String {
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
