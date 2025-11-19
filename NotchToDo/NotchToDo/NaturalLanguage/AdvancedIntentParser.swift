import Foundation
import NaturalLanguage

/// Represents different task actions that can be performed
enum TaskAction: String {
    case create
    case update
    case delete
    case move
    case complete
    case setDueDate
    case setPriority
    case setStatus
}

/// Comprehensive task intent extracted from natural language
struct TaskIntent {
    var action: TaskAction
    var title: String
    var targetOrb: String?
    var dueDate: Date?
    var dueTime: Date?
    var priority: Int?  // 1=low, 2=normal, 3=high
    var status: Int16?  // 1=outstanding, 2=in progress, 3=complete
    var notes: String?
    var confidence: Float
    var ambiguities: [String]  // What was unclear or assumed

    /// Combined due date with time if available
    var combinedDueDate: Date? {
        guard let date = dueDate else { return nil }

        if let time = dueTime {
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

            var combined = DateComponents()
            combined.year = dateComponents.year
            combined.month = dateComponents.month
            combined.day = dateComponents.day
            combined.hour = timeComponents.hour
            combined.minute = timeComponents.minute

            return calendar.date(from: combined)
        }

        return date
    }
}

/// Advanced natural language parser for voice commands
/// Extracts task attributes from complex, multi-clause utterances
class AdvancedIntentParser {

    private let dateParser = NaturalLanguageDateParser()

    // Action keywords
    private let createKeywords: Set<String> = ["add", "create", "new", "make", "start"]
    private let updateKeywords: Set<String> = ["update", "change", "edit", "modify", "set"]
    private let deleteKeywords: Set<String> = ["delete", "remove", "cancel", "drop"]
    private let moveKeywords: Set<String> = ["move", "transfer", "relocate", "shift"]
    private let completeKeywords: Set<String> = ["complete", "finish", "done", "mark done"]

    // Priority keywords
    private let highPriorityKeywords: Set<String> = [
        "urgent", "high priority", "important", "asap", "critical", "high"
    ]
    private let lowPriorityKeywords: Set<String> = [
        "low priority", "whenever", "someday", "maybe", "low"
    ]

    // Status keywords
    private let inProgressKeywords: Set<String> = [
        "in progress", "working on", "started", "doing"
    ]
    private let outstandingKeywords: Set<String> = [
        "outstanding", "todo", "pending", "not started"
    ]
    private let completeStatusKeywords: Set<String> = [
        "complete", "completed", "done", "finished"
    ]

    // Orb targeting keywords (prepositions)
    private let orbTargetingKeywords: Set<String> = ["to", "in", "for", "into"]

    // Notes/description trigger keywords
    private let notesTriggerKeywords: Set<String> = [
        "notes", "note", "make sure", "remember to", "don't forget",
        "and", "also", "with notes", "description"
    ]

    // Due date trigger keywords
    private let dueDateKeywords: Set<String> = ["due", "by", "on", "at", "deadline"]

    init() {}

    /// Parse a natural language command into a structured TaskIntent
    /// Example: "Add Create Lasagna to Kitchen orb, due on Friday and make sure that you add tomatoes and pasta to the notes"
    func parse(_ text: String, availableOrbs: [String] = []) -> TaskIntent? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        var ambiguities: [String] = []
        var confidence: Float = 1.0

        // Step 1: Identify action
        guard let action = extractAction(from: normalized) else {
            return nil
        }

        // Step 2: Extract task title
        let titleInfo = extractTitle(from: normalized, action: action)
        guard !titleInfo.title.isEmpty else {
            return nil
        }

        // If title extraction had low confidence, note it
        if titleInfo.confidence < 0.8 {
            confidence *= titleInfo.confidence
            ambiguities.append("Task title may be incomplete")
        }

        // Step 3: Extract target orb (if specified)
        let targetOrb = extractTargetOrb(from: normalized, availableOrbs: availableOrbs)
        if targetOrb == nil && !availableOrbs.isEmpty {
            ambiguities.append("No specific orb mentioned - will use ML classification")
        }

        // Step 4: Extract due date/time
        let (dueDate, dueTime) = extractDueDateTime(from: normalized)

        // Step 5: Extract priority
        let priority = extractPriority(from: normalized)

        // Step 6: Extract status
        let status = extractStatus(from: normalized)

        // Step 7: Extract notes/description
        let notes = extractNotes(from: normalized, title: titleInfo.title)

        return TaskIntent(
            action: action,
            title: titleInfo.title,
            targetOrb: targetOrb,
            dueDate: dueDate,
            dueTime: dueTime,
            priority: priority,
            status: status,
            notes: notes,
            confidence: confidence,
            ambiguities: ambiguities
        )
    }

    // MARK: - Extraction Methods

    private func extractAction(from text: String) -> TaskAction? {
        let lowercased = text.lowercased()
        let tokens = Set(lowercased.split { !$0.isLetter }.map { String($0) })

        // Check for delete first (highest priority)
        if !deleteKeywords.isDisjoint(with: tokens) {
            return .delete
        }

        // Check for complete
        if !completeKeywords.isDisjoint(with: tokens) {
            return .complete
        }

        // Check for move
        if !moveKeywords.isDisjoint(with: tokens) {
            return .move
        }

        // Check for update
        if !updateKeywords.isDisjoint(with: tokens) {
            return .update
        }

        // Default to create (most common action)
        if !createKeywords.isDisjoint(with: tokens) {
            return .create
        }

        // If no explicit action keyword, assume create
        return .create
    }

    private func extractTitle(from text: String, action: TaskAction) -> (title: String, confidence: Float) {
        let lowercased = text.lowercased()

        // Strategy 1: Look for title between action verb and first preposition/keyword
        // Example: "Add [Create Lasagna] to Kitchen orb"

        // Find the action keyword position
        var actionKeywords = createKeywords
        switch action {
        case .create: actionKeywords = createKeywords
        case .update: actionKeywords = updateKeywords
        case .delete: actionKeywords = deleteKeywords
        case .move: actionKeywords = moveKeywords
        case .complete: actionKeywords = completeKeywords
        default: actionKeywords = createKeywords
        }

        var titleStart: String.Index?
        for keyword in actionKeywords {
            if let range = lowercased.range(of: keyword) {
                titleStart = range.upperBound
                break
            }
        }

        guard let start = titleStart else {
            // No action keyword found, use entire text
            return (cleanTitle(text), 0.5)
        }

        // Find where the title ends (at first preposition or keyword)
        let textAfterAction = String(lowercased[start...]).trimmingCharacters(in: .whitespaces)
        let originalAfterAction = String(text[start...]).trimmingCharacters(in: .whitespaces)

        // Look for stopping points
        var titleEnd: String.Index = originalAfterAction.endIndex
        var confidence: Float = 0.9

        // Check for orb targeting keywords
        for keyword in orbTargetingKeywords {
            if let range = textAfterAction.range(of: " \(keyword) ") {
                let potentialEnd = originalAfterAction.index(originalAfterAction.startIndex, offsetBy: textAfterAction.distance(from: textAfterAction.startIndex, to: range.lowerBound))
                if potentialEnd < titleEnd {
                    titleEnd = potentialEnd
                }
            }
        }

        // Check for due date keywords
        for keyword in dueDateKeywords {
            if let range = textAfterAction.range(of: " \(keyword) ") {
                let potentialEnd = originalAfterAction.index(originalAfterAction.startIndex, offsetBy: textAfterAction.distance(from: textAfterAction.startIndex, to: range.lowerBound))
                if potentialEnd < titleEnd {
                    titleEnd = potentialEnd
                }
            }
        }

        // Check for comma (often separates title from other attributes)
        if let commaRange = textAfterAction.range(of: ",") {
            let potentialEnd = originalAfterAction.index(originalAfterAction.startIndex, offsetBy: textAfterAction.distance(from: textAfterAction.startIndex, to: commaRange.lowerBound))
            if potentialEnd < titleEnd {
                titleEnd = potentialEnd
            }
        }

        let extractedTitle = String(originalAfterAction[..<titleEnd]).trimmingCharacters(in: .whitespacesAndNewlines)

        return (cleanTitle(extractedTitle), confidence)
    }

    private func extractTargetOrb(from text: String, availableOrbs: [String]) -> String? {
        let lowercased = text.lowercased()

        // Look for patterns like "to [orb name]", "in [orb name]", etc.
        for keyword in orbTargetingKeywords {
            let pattern = " \(keyword) ([^,]+)"
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
                  let candidateRange = Range(match.range(at: 1), in: lowercased) else {
                continue
            }

            var candidate = String(lowercased[candidateRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            // Remove "orb" suffix if present
            candidate = candidate.replacingOccurrences(of: " orb$", with: "", options: .regularExpression)
            candidate = candidate.replacingOccurrences(of: " project$", with: "", options: .regularExpression)

            // Clean up
            candidate = cleanTitle(candidate)

            // Try to match against available orbs (case-insensitive)
            for orb in availableOrbs {
                if orb.lowercased() == candidate ||
                   orb.lowercased().contains(candidate) ||
                   candidate.contains(orb.lowercased()) {
                    return orb
                }
            }

            // Return the extracted name even if it doesn't match exactly
            // (fuzzy matching will happen later)
            if !candidate.isEmpty {
                return candidate
            }
        }

        return nil
    }

    private func extractDueDateTime(from text: String) -> (date: Date?, time: Date?) {
        let lowercased = text.lowercased()

        // Look for due date trigger keywords followed by a date expression
        var searchText = lowercased

        // Try to isolate the date portion
        for keyword in dueDateKeywords {
            if let range = lowercased.range(of: keyword) {
                searchText = String(lowercased[range.upperBound...])
                break
            }
        }

        // Parse the date from the isolated text
        if let parsedDate = dateParser.parse(searchText) {
            return (parsedDate.date, parsedDate.time)
        }

        // If no explicit due date keyword, try parsing the whole text
        // (date parser is smart enough to find date references)
        if let parsedDate = dateParser.parse(lowercased) {
            return (parsedDate.date, parsedDate.time)
        }

        return (nil, nil)
    }

    private func extractPriority(from text: String) -> Int? {
        let lowercased = text.lowercased()

        // Check for high priority keywords
        for keyword in highPriorityKeywords {
            if lowercased.contains(keyword) {
                return 3  // High priority
            }
        }

        // Check for low priority keywords
        for keyword in lowPriorityKeywords {
            if lowercased.contains(keyword) {
                return 1  // Low priority
            }
        }

        // Default to normal priority (implicit)
        return nil  // Will use default value (2) if nil
    }

    private func extractStatus(from text: String) -> Int16? {
        let lowercased = text.lowercased()

        // Check for "in progress" status
        for keyword in inProgressKeywords {
            if lowercased.contains(keyword) {
                return 2  // In progress
            }
        }

        // Check for "complete" status
        for keyword in completeStatusKeywords {
            if lowercased.contains(keyword) {
                return 3  // Complete
            }
        }

        // Check for "outstanding" status
        for keyword in outstandingKeywords {
            if lowercased.contains(keyword) {
                return 1  // Outstanding
            }
        }

        // Default to outstanding (implicit)
        return nil  // Will use default value (1) if nil
    }

    private func extractNotes(from text: String, title: String) -> String? {
        let lowercased = text.lowercased()

        // Strategy 1: Look for explicit notes keywords
        for keyword in notesTriggerKeywords {
            if let range = lowercased.range(of: keyword) {
                var notesText = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)

                // Remove "that" or "to" if it follows immediately
                notesText = notesText.replacingOccurrences(of: "^that ", with: "", options: .regularExpression)
                notesText = notesText.replacingOccurrences(of: "^to ", with: "", options: .regularExpression)
                notesText = notesText.replacingOccurrences(of: "^you ", with: "", options: .regularExpression)

                // Remove trailing "to the notes" or "to notes"
                notesText = notesText.replacingOccurrences(of: " to the notes$", with: "", options: .regularExpression)
                notesText = notesText.replacingOccurrences(of: " to notes$", with: "", options: .regularExpression)
                notesText = notesText.replacingOccurrences(of: " in the notes$", with: "", options: .regularExpression)
                notesText = notesText.replacingOccurrences(of: " in notes$", with: "", options: .regularExpression)

                notesText = notesText.trimmingCharacters(in: .whitespacesAndNewlines)

                if !notesText.isEmpty {
                    return notesText
                }
            }
        }

        // Strategy 2: Look for text after "and" that's not part of the title
        if let andRange = lowercased.range(of: " and ") {
            let afterAnd = String(text[andRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)

            // Make sure this isn't just part of the title
            if !title.lowercased().contains(afterAnd.lowercased()) && afterAnd.count > 3 {
                return afterAnd
            }
        }

        return nil
    }

    // MARK: - Helper Methods

    private func cleanTitle(_ title: String) -> String {
        var cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove "a ", "an ", "the " at the beginning
        cleaned = cleaned.replacingOccurrences(of: "^a ", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "^an ", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "^the ", with: "", options: .regularExpression)

        // Capitalize first letter
        if let first = cleaned.first {
            cleaned = first.uppercased() + cleaned.dropFirst()
        }

        return cleaned
    }
}
