import Foundation

/// Input validation utilities for task and orb creation
public enum InputValidation {
    
    // MARK: - Validation Errors
    
    public enum ValidationError: LocalizedError {
        case emptyTitle
        case titleTooLong(maxLength: Int)
        case titleContainsInvalidCharacters
        case emptyOrbName
        case orbNameTooLong(maxLength: Int)
        case invalidPriority(validRange: ClosedRange<Int>)
        case invalidStatus(validRange: ClosedRange<Int16>)
        case deadlineInPast
        case notesTooLong(maxLength: Int)
        
        public var errorDescription: String? {
            switch self {
            case .emptyTitle:
                return "Task title cannot be empty"
            case .titleTooLong(let maxLength):
                return "Task title cannot exceed \(maxLength) characters"
            case .titleContainsInvalidCharacters:
                return "Task title contains invalid characters"
            case .emptyOrbName:
                return "Project name cannot be empty"
            case .orbNameTooLong(let maxLength):
                return "Project name cannot exceed \(maxLength) characters"
            case .invalidPriority(let range):
                return "Priority must be between \(range.lowerBound) and \(range.upperBound)"
            case .invalidStatus(let range):
                return "Status must be between \(range.lowerBound) and \(range.upperBound)"
            case .deadlineInPast:
                return "Deadline cannot be in the past"
            case .notesTooLong(let maxLength):
                return "Notes cannot exceed \(maxLength) characters"
            }
        }
        
        public var recoverySuggestion: String? {
            switch self {
            case .emptyTitle:
                return "Please enter a title for your task"
            case .titleTooLong:
                return "Try shortening the title"
            case .titleContainsInvalidCharacters:
                return "Remove any special characters from the title"
            case .emptyOrbName:
                return "Please enter a name for your project"
            case .orbNameTooLong:
                return "Try shortening the project name"
            case .invalidPriority(let range):
                return "Set priority to a value between \(range.lowerBound) and \(range.upperBound)"
            case .invalidStatus(let range):
                return "Set status to a valid value"
            case .deadlineInPast:
                return "Choose a deadline in the future"
            case .notesTooLong:
                return "Try shortening the notes"
            }
        }
    }
    
    // MARK: - Configuration
    
    public struct Config {
        public let maxTitleLength: Int
        public let maxOrbNameLength: Int
        public let maxNotesLength: Int
        public let validPriorityRange: ClosedRange<Int>
        public let validStatusRange: ClosedRange<Int16>
        public let allowPastDeadlines: Bool
        
        public static let `default` = Config(
            maxTitleLength: 500,
            maxOrbNameLength: 100,
            maxNotesLength: 10000,
            validPriorityRange: 1...5,
            validStatusRange: 1...3,
            allowPastDeadlines: false
        )
        
        public init(
            maxTitleLength: Int = 500,
            maxOrbNameLength: Int = 100,
            maxNotesLength: Int = 10000,
            validPriorityRange: ClosedRange<Int> = 1...5,
            validStatusRange: ClosedRange<Int16> = 1...3,
            allowPastDeadlines: Bool = false
        ) {
            self.maxTitleLength = maxTitleLength
            self.maxOrbNameLength = maxOrbNameLength
            self.maxNotesLength = maxNotesLength
            self.validPriorityRange = validPriorityRange
            self.validStatusRange = validStatusRange
            self.allowPastDeadlines = allowPastDeadlines
        }
    }
    
    // MARK: - Task Validation
    
    /// Validates task input and returns sanitized title or throws validation error
    public static func validateTaskTitle(_ title: String, config: Config = .default) throws -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            throw ValidationError.emptyTitle
        }
        
        guard trimmed.count <= config.maxTitleLength else {
            throw ValidationError.titleTooLong(maxLength: config.maxTitleLength)
        }
        
        // Check for control characters (but allow unicode)
        let invalidCharacters = CharacterSet.controlCharacters.subtracting(.whitespaces)
        guard trimmed.unicodeScalars.allSatisfy({ !invalidCharacters.contains($0) }) else {
            throw ValidationError.titleContainsInvalidCharacters
        }
        
        return trimmed
    }
    
    /// Validates task priority
    public static func validatePriority(_ priority: Int, config: Config = .default) throws -> Int {
        guard config.validPriorityRange.contains(priority) else {
            throw ValidationError.invalidPriority(validRange: config.validPriorityRange)
        }
        return priority
    }
    
    /// Validates task status
    public static func validateStatus(_ status: Int16, config: Config = .default) throws -> Int16 {
        guard config.validStatusRange.contains(status) else {
            throw ValidationError.invalidStatus(validRange: config.validStatusRange)
        }
        return status
    }
    
    /// Validates deadline
    public static func validateDeadline(_ deadline: Date?, config: Config = .default) throws -> Date? {
        guard let deadline = deadline else { return nil }
        
        if !config.allowPastDeadlines && deadline < Date() {
            // Allow some tolerance (5 minutes) for recently set deadlines
            let tolerance: TimeInterval = 5 * 60
            if deadline.addingTimeInterval(tolerance) < Date() {
                throw ValidationError.deadlineInPast
            }
        }
        
        return deadline
    }
    
    /// Validates notes/details
    public static func validateNotes(_ notes: String?, config: Config = .default) throws -> String {
        guard let notes = notes else { return "" }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmed.count <= config.maxNotesLength else {
            throw ValidationError.notesTooLong(maxLength: config.maxNotesLength)
        }
        
        return trimmed
    }
    
    // MARK: - Orb Validation
    
    /// Validates orb name and returns sanitized name or throws validation error
    public static func validateOrbName(_ name: String, config: Config = .default) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            throw ValidationError.emptyOrbName
        }
        
        guard trimmed.count <= config.maxOrbNameLength else {
            throw ValidationError.orbNameTooLong(maxLength: config.maxOrbNameLength)
        }
        
        return trimmed
    }
    
    // MARK: - Convenience Methods
    
    /// Sanitizes a string by trimming whitespace and limiting length
    public static func sanitize(_ input: String, maxLength: Int) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= maxLength {
            return trimmed
        }
        return String(trimmed.prefix(maxLength))
    }
    
    /// Checks if a string is a valid non-empty input
    public static func isValidInput(_ input: String) -> Bool {
        return !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
