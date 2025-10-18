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
    case showOverlay
    case createOrb(name: String)
    case clarifyTaskOrOrb(title: String, transcript: String)
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
        case .showOverlay:
            return "Show overlay"
        case .createOrb(let name):
            return "Create orb '\(name)'"
        case .clarifyTaskOrOrb(let title, _):
            return "Clarify whether '\(title)' is a task or orb"
        }
    }
}

class IntentRouter {
    private let classifier: IntentClassifier
    private let addVerbs: Set<String> = ["add", "create", "make", "start", "new"]
    private let openVerbs: Set<String> = ["open", "show", "reveal", "display", "bring"]
    private let orbKeywords: Set<String> = ["orb", "project", "workspace", "space"]
    private let taskKeywords: Set<String> = ["task", "tasks", "todo", "reminder", "item"]
    
    init(classifier: IntentClassifier = .shared) {
        self.classifier = classifier
    }
    
    func handle(transcript: String, context: RoutingContext) -> Action? {
        let stripped = stripWakeWord(from: transcript).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stripped.isEmpty else { return nil }
        
        let lowered = stripped.lowercased()
        let tokens = lowered.split { !$0.isLetter }.map { String($0) }
        let tokenSet = Set(tokens)
        let mentionsOrb = !orbKeywords.isDisjoint(with: tokenSet)
        let mentionsTask = !taskKeywords.isDisjoint(with: tokenSet)
        
        let prediction = classifier.predictIntent(for: stripped)
        
        switch prediction.intent {
        case .createTask:
            if mentionsOrb && mentionsTask {
                let title = extractContentCandidate(from: stripped) ?? deriveDefaultTitle(from: lowered)
                return .clarifyTaskOrOrb(title: title, transcript: transcript)
            }
            let title = parseAddTask(lowered)
                ?? extractContentCandidate(from: stripped)
                ?? deriveDefaultTitle(from: lowered)
            return .createTask(title: title, folderId: nil)
        case .createOrb:
            let name = parseCreateOrb(lowered)
                ?? extractContentCandidate(from: stripped)
                ?? deriveDefaultTitle(from: lowered)
            return .createOrb(name: name)
        case .showOverlay:
            return .showOverlay
        case .clarification:
            let title = extractContentCandidate(from: stripped) ?? deriveDefaultTitle(from: lowered)
            return .clarifyTaskOrOrb(title: title, transcript: transcript)
        case .unknown:
            break
        }
        
        if let orbName = parseCreateOrb(lowered) {
            return .createOrb(name: orbName)
        } else if parseShowOverlay(lowered) {
            return .showOverlay
        } else if let match = parseAddTask(lowered) {
            return handleAddTask(match, context: context)
        } else if let match = parseNewFolder(lowered) {
            return handleNewFolder(match)
        } else if let match = parseShowFolder(lowered) {
            return handleShowFolder(match, context: context)
        } else if let match = parseMoveTask(lowered) {
            return handleMoveTask(match, context: context)
        } else if let match = parseMarkDone(lowered) {
            return handleMarkDone(match, context: context)
        } else if let match = parseDueDate(lowered) {
            return handleDueDate(match, context: context)
        }
        
        return inferFallbackAction(lowered)
    }
    
    private func stripWakeWord(from text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let prefixes = ["hey notch", "ok notch", "okay notch", "notch"]
        for prefix in prefixes {
            if lower.hasPrefix(prefix) {
                let index = trimmed.index(trimmed.startIndex, offsetBy: prefix.count)
                trimmed = String(trimmed[index...])
                break
            }
        }
        let unwanted = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        return trimmed.trimmingCharacters(in: unwanted)
    }
    
    private func parseAddTask(_ text: String) -> String? {
        let tokenSet = Set(text.split { !$0.isLetter }.map { String($0) })
        if !orbKeywords.isDisjoint(with: tokenSet) {
            return nil
        }
        let pattern = #"^(add|create|new|start|make)\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 3 else { return nil }
        let titleRange = Range(match.range(at: 2), in: text)!
        return cleanEntity(String(text[titleRange]))
    }
    
    private func parseNewFolder(_ text: String) -> String? {
        let pattern = #"^new\s+folder\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2 else { return nil }
        let nameRange = Range(match.range(at: 1), in: text)!
        return cleanEntity(String(text[nameRange]))
    }
    
    private func parseShowFolder(_ text: String) -> String? {
        let pattern = #"^show\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2 else { return nil }
        let folderRange = Range(match.range(at: 1), in: text)!
        return cleanEntity(String(text[folderRange]))
    }
    
    private func parseMoveTask(_ text: String) -> (taskId: UUID, folderName: String)? {
        let pattern = #"^move\s+(it|that|task)\s+to\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 3 else { return nil }
        let folderRange = Range(match.range(at: 2), in: text)!
        let folderName = cleanEntity(String(text[folderRange]))
        return (UUID(), folderName)
    }
    
    private func parseMarkDone(_ text: String) -> String? {
        let pattern = #"^mark\s+(.+)\s+(done|complete)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2 else { return nil }
        let titleRange = Range(match.range(at: 1), in: text)!
        return cleanEntity(String(text[titleRange]))
    }
    
    private func parseDueDate(_ text: String) -> (taskId: UUID, dateString: String)? {
        let pattern = #"^due\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2 else { return nil }
        let dateRange = Range(match.range(at: 1), in: text)!
        let dateString = cleanEntity(String(text[dateRange]))
        return (UUID(), dateString)
    }
    
    private func parseShowOverlay(_ text: String) -> Bool {
        let pattern = #"^(open|show|reveal|display|bring)(?:\s+(?:it|them|the|overlay|orbs?))*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }
    
    private func parseCreateOrb(_ text: String) -> String? {
        let tokenSet = Set(text.split { !$0.isLetter }.map { String($0) })
        if !taskKeywords.isDisjoint(with: tokenSet) {
            return nil
        }
        let pattern = #"^(?:add|create|make|start)\s+(?:an?\s+)?(?:orb|project|workspace|space)\s*(?:called|named|titled)?\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2 else { return nil }
        let nameRange = Range(match.range(at: 1), in: text)!
        return cleanEntity(String(text[nameRange]))
    }
    
    private func cleanEntity(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        return trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).capitalized
    }
    
    private func inferFallbackAction(_ text: String) -> Action? {
        let tokens = text.split { !$0.isLetter }.map { String($0) }
        let tokenSet = Set(tokens)
        let containsAdd = !addVerbs.isDisjoint(with: tokenSet)
        let containsOpen = !openVerbs.isDisjoint(with: tokenSet)
        let mentionsOrb = !orbKeywords.isDisjoint(with: tokenSet)
        let mentionsTask = !taskKeywords.isDisjoint(with: tokenSet)
        
        if containsOpen && !mentionsTask && !mentionsOrb {
            return .showOverlay
        }
        
        if containsAdd {
            if mentionsOrb && mentionsTask {
                let title = extractContentCandidate(from: text) ?? deriveDefaultTitle(from: text)
                return .clarifyTaskOrOrb(title: title, transcript: text)
            }
            if mentionsOrb {
                let name = extractContentCandidate(from: text) ?? deriveDefaultTitle(from: text)
                return .createOrb(name: name)
            }
            if mentionsTask {
                let title = extractContentCandidate(from: text) ?? deriveDefaultTitle(from: text)
                return .createTask(title: title, folderId: nil)
            }
        }
        
        if containsOpen {
            return .showOverlay
        }
        
        return nil
    }
    
    private func extractContentCandidate(from text: String) -> String? {
        if let quoted = extractQuotedName(from: text) {
            return quoted
        }
        if let trailing = parseTrailingName(from: text) {
            return trailing
        }
        return nil
    }
    
    private func extractQuotedName(from text: String) -> String? {
        let pattern = #"["“']([^"”']+)["”']"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return cleanEntity(String(text[range]))
    }
    
    private func parseTrailingName(from text: String) -> String? {
        guard let lastSpace = text.lastIndex(of: " ") else { return nil }
        let fragment = text[text.index(after: lastSpace)...]
        let candidate = cleanEntity(String(fragment))
        return candidate.isEmpty ? nil : candidate
    }
    
    private func deriveDefaultTitle(from text: String) -> String {
        let words = text.split { !$0.isLetter }
        for word in words.reversed() {
            let lower = word.lowercased()
            if addVerbs.contains(lower) || taskKeywords.contains(lower) || orbKeywords.contains(lower) {
                continue
            }
            return cleanEntity(String(word))
        }
        return "New Item"
    }
    
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

extension IntentRouter {
    static func runSelfTest() -> [String] {
        let router = IntentRouter()
        let context = RoutingContext()
        let classifier = IntentClassifier.shared
        struct TestCase {
            let phrase: String
            let verifier: (Action?) -> Bool
            let description: String
        }
        let cases: [TestCase] = [
            TestCase(phrase: "Notch, open", verifier: { action in
                if case .showOverlay? = action { return true } else { return false }
            }, description: "Open overlay"),
            TestCase(phrase: "Notch open overlay now", verifier: { action in
                if case .showOverlay? = action { return true } else { return false }
            }, description: "Open overlay (variant)"),
            TestCase(phrase: "Notch add an orb called alpine", verifier: { action in
                if case .createOrb(let name)? = action { return name.lowercased().contains("alpine") } else { return false }
            }, description: "Create orb"),
            TestCase(phrase: "Notch add buy milk", verifier: { action in
                if case .createTask(let title, _)? = action { return title.lowercased().contains("buy milk") } else { return false }
            }, description: "Create task"),
            TestCase(phrase: "Notch add a project and a task", verifier: { action in
                if case .clarifyTaskOrOrb = action { return true } else { return false }
            }, description: "Clarify ambiguous")
        ]
        return cases.map { test in
            let action = router.handle(transcript: test.phrase, context: context)
            let passed = test.verifier(action)
            let stripped = router.stripWakeWord(from: test.phrase).trimmingCharacters(in: .whitespacesAndNewlines)
            let prediction: VoiceIntentPrediction
            if stripped.isEmpty {
                prediction = VoiceIntentPrediction(intent: .unknown, confidence: 0, label: nil, source: .heuristic)
            } else {
                prediction = classifier.predictIntent(for: stripped)
            }
            let sourceToken = prediction.source == .coreML ? "ML" : "Fallback"
            let confidence = prediction.confidence > 0 ? String(format: "%.2f", prediction.confidence) : "–"
            return "[\(passed ? "✔︎" : "✘")] \(test.description) – action: \(action?.description ?? "nil") (intent: \(prediction.intent) @ \(confidence), \(sourceToken))"
        }
    }
}
