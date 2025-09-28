import Foundation

struct RoutingContext {
    var lastCreatedTask: UUID?
    var currentFolder: UUID?
    var availableFolders: [UUID] = []
}

enum Action {
    case createTask(title: String, folderId: UUID?)
    case createFolder(name: String)
    case showFolder(folderId: UUID?)
    case moveTask(taskId: UUID, toFolderId: UUID)
    case markTaskDone(taskId: UUID)
    case setDueDate(taskId: UUID, date: Date)
    case deleteTask(taskId: UUID)
    case exportData
}

extension Action: CustomStringConvertible {
    var description: String {
        switch self {
        case .createTask(let title, let folderId):
            return "Create task '\(title)'" + (folderId != nil ? " in folder \(folderId!)" : "")
        case .createFolder(let name):
            return "Create folder '\(name)'"
        case .showFolder(let folderId):
            return "Show folder" + (folderId != nil ? " \(folderId!)" : " (default)")
        case .moveTask(let taskId, let toFolderId):
            return "Move task \(taskId) to folder \(toFolderId)"
        case .markTaskDone(let taskId):
            return "Mark task \(taskId) as done"
        case .setDueDate(let taskId, let date):
            return "Set due date for task \(taskId) to \(date)"
        case .deleteTask(let taskId):
            return "Delete task \(taskId)"
        case .exportData:
            return "Export data"
        }
    }
}

class IntentRouter {
    
    func handle(transcript: String, context: RoutingContext) -> Action? {
        let normalizedTranscript = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Parse intent using regex patterns
        if let match = parseAddTask(normalizedTranscript) {
            return handleAddTask(match, context: context)
        } else if let match = parseNewFolder(normalizedTranscript) {
            return handleNewFolder(match)
        } else if let match = parseShowFolder(normalizedTranscript) {
            return handleShowFolder(match, context: context)
        } else if let match = parseMoveTask(normalizedTranscript) {
            return handleMoveTask(match, context: context)
        } else if let match = parseMarkDone(normalizedTranscript) {
            return handleMarkDone(match, context: context)
        } else if let match = parseDueDate(normalizedTranscript) {
            return handleDueDate(match, context: context)
        }
        
        return nil
    }
    
    // MARK: - Parsing Methods
    
    private func parseAddTask(_ text: String) -> String? {
        let pattern = #"^(add|create)\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 3 else { return nil }
        
        let titleRange = Range(match.range(at: 2), in: text)!
        return String(text[titleRange])
    }
    
    private func parseNewFolder(_ text: String) -> String? {
        let pattern = #"^new\s+folder\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2 else { return nil }
        
        let nameRange = Range(match.range(at: 1), in: text)!
        return String(text[nameRange])
    }
    
    private func parseShowFolder(_ text: String) -> String? {
        let pattern = #"^show\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2 else { return nil }
        
        let folderRange = Range(match.range(at: 1), in: text)!
        return String(text[folderRange])
    }
    
    private func parseMoveTask(_ text: String) -> (taskId: UUID, folderName: String)? {
        let pattern = #"^move\s+(it|that|task)\s+to\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 3 else { return nil }
        
        let folderRange = Range(match.range(at: 2), in: text)!
        let folderName = String(text[folderRange])
        
        return (UUID(), folderName)
    }
    
    private func parseMarkDone(_ text: String) -> String? {
        let pattern = #"^mark\s+(.+)\s+(done|complete)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2 else { return nil }
        
        let titleRange = Range(match.range(at: 1), in: text)!
        return String(text[titleRange])
    }
    
    private func parseDueDate(_ text: String) -> (taskId: UUID, dateString: String)? {
        let pattern = #"^due\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2 else { return nil }
        
        let dateRange = Range(match.range(at: 1), in: text)!
        let dateString = String(text[dateRange])
        
        return (UUID(), dateString)
    }
    
    // MARK: - Action Handlers
    
    private func handleAddTask(_ title: String, context: RoutingContext) -> Action {
        return .createTask(title: title, folderId: nil)
    }
    
    private func handleNewFolder(_ name: String) -> Action {
        return .createFolder(name: name)
    }
    
    private func handleShowFolder(_ folderName: String, context: RoutingContext) -> Action {
        return .showFolder(folderId: nil)
    }
    
    private func handleMoveTask(_ match: (taskId: UUID, folderName: String), context: RoutingContext) -> Action {
        return .moveTask(taskId: match.taskId, toFolderId: UUID())
    }
    
    private func handleMarkDone(_ title: String, context: RoutingContext) -> Action {
        return .markTaskDone(taskId: UUID())
    }
    
    private func handleDueDate(_ match: (taskId: UUID, dateString: String), context: RoutingContext) -> Action {
        return .setDueDate(taskId: match.taskId, date: Date())
    }
}
