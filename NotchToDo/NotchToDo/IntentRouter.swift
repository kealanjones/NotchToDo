import Foundation

struct RoutingContext {
    var lastCreatedTask: UUID?
    var currentFolder: UUID?
    var availableFolders: [UUID] = []
}

enum Action {
    case createTask(title: String)
    case createAdvancedTask(intent: TaskIntent)  // NEW: Support for advanced task creation
    case showOverlay
    case createOrb(name: String)
    case clarifyTaskOrOrb(title: String, transcript: String)
}

extension Action: CustomStringConvertible {
    var description: String {
        switch self {
        case .createTask(let title):
            return "Create task '\(title)'"
        case .createAdvancedTask(let intent):
            return "Create advanced task '\(intent.title)' (orb: \(intent.targetOrb ?? "auto"), priority: \(intent.priority ?? 2), has due date: \(intent.dueDate != nil))"
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
    private let advancedParser: AdvancedIntentParser  // NEW: Advanced NLP parser
    private let addVerbs: Set<String> = ["add", "create", "make", "start", "new"]
    private let openVerbs: Set<String> = ["open", "show", "reveal", "display", "bring"]
    private let orbKeywords: Set<String> = ["orb", "project", "workspace", "space"]
    private let taskKeywords: Set<String> = ["task", "tasks", "todo", "reminder", "item"]

    // Feature flag to enable/disable advanced parsing
    private var useAdvancedParsing: Bool = true

    init(classifier: IntentClassifier = .shared) {
        self.classifier = classifier
        self.advancedParser = AdvancedIntentParser()
    }
    
    func handle(transcript: String, context _: RoutingContext) -> Action? {
        let stripped = stripWakeWord(from: transcript).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stripped.isEmpty else { return nil }

        let lowered = stripped.lowercased()
        let tokens = lowered.split { !$0.isLetter }.map { String($0) }
        let tokenSet = Set(tokens)
        let mentionsOrb = !orbKeywords.isDisjoint(with: tokenSet)
        let mentionsTask = !taskKeywords.isDisjoint(with: tokenSet)

        // NEW: Try advanced parsing first if enabled
        if useAdvancedParsing {
            // Try to parse with advanced NLP parser
            if let taskIntent = advancedParser.parse(stripped) {
                // CRITICAL FIX: Always use advanced parser results - it's smarter than regex
                // The advanced parser correctly handles phrases like "create a task called X"
                // and properly extracts titles, removing helper words and conflicting keywords
                DebugLog.log("Advanced parser extracted: \(taskIntent.title)", category: .intent)
                return .createAdvancedTask(intent: taskIntent)
            }
        }

        // Original logic (fallback for backward compatibility)
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
            return .createTask(title: title)
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
        }
        if parseShowOverlay(lowered) {
            return .showOverlay
        }
        if let match = parseAddTask(lowered) {
            return .createTask(title: match)
        }
        return nil
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
        // CRITICAL FIX: Removed overly broad keyword rejection
        // Previously rejected "create a task called Project Review" because "project" appeared in name
        // Note: This is now a fallback since advanced parser is used primarily

        // Improved pattern that handles "called/named" keywords
        let pattern = #"^(add|create|new|start|make)\s+(?:a\s+)?(?:task\s+)?(?:called|named|titled)?\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 3 else { return nil }
        let titleRange = Range(match.range(at: 2), in: text)!
        return cleanEntity(String(text[titleRange]))
    }
    

    

    

    

    

    
    private func parseShowOverlay(_ text: String) -> Bool {
        let pattern = #"^(open|show|reveal|display|bring)(?:\s+(?:it|them|the|overlay|orbs?))*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }
    
    private func parseCreateOrb(_ text: String) -> String? {
        // CRITICAL FIX: Removed overly broad keyword rejection
        // Previously rejected "create an orb called Task Manager" because "task" appeared in name
        // The regex pattern below is smart enough to identify orb creation commands
        // by looking for explicit "orb"/"project" keywords in the command structure
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
                if case .createTask(let title)? = action { return title.lowercased().contains("buy milk") } else { return false }
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
