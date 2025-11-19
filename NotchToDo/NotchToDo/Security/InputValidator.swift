import Foundation

/// Comprehensive input validation for NotchToDo
/// Validates and sanitizes all user input to prevent injection attacks and ensure data integrity
enum InputValidator {

    // MARK: - Validation Errors

    enum ValidationError: LocalizedError {
        case emptyInput(field: String)
        case tooShort(field: String, minimum: Int)
        case tooLong(field: String, maximum: Int)
        case invalidFormat(field: String, reason: String)
        case invalidCharacters(field: String)
        case passwordTooWeak(reasons: [String])
        case containsMaliciousContent

        var errorDescription: String? {
            switch self {
            case .emptyInput(let field):
                return "\(field) cannot be empty"
            case .tooShort(let field, let minimum):
                return "\(field) must be at least \(minimum) characters"
            case .tooLong(let field, let maximum):
                return "\(field) must not exceed \(maximum) characters"
            case .invalidFormat(let field, let reason):
                return "\(field) is invalid: \(reason)"
            case .invalidCharacters(let field):
                return "\(field) contains invalid characters"
            case .passwordTooWeak(let reasons):
                return "Password is too weak: \(reasons.joined(separator: ", "))"
            case .containsMaliciousContent:
                return "Input contains potentially malicious content"
            }
        }
    }

    // MARK: - Validation Limits

    enum Limits {
        static let taskTitleMin = 1
        static let taskTitleMax = 500
        static let taskNotesMax = 10_000
        static let orbNameMin = 1
        static let orbNameMax = 100
        static let passwordMin = 8
        static let passwordMax = 128
        static let emailMax = 254 // RFC 5321
        static let voiceCommandMax = 1000
    }

    // MARK: - Email Validation

    /// Validates an email address using RFC 5322 compliant regex
    /// - Parameter email: The email address to validate
    /// - Returns: Validated and trimmed email address
    /// - Throws: ValidationError if invalid
    static func validateEmail(_ email: String) throws -> String {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ValidationError.emptyInput(field: "Email")
        }

        guard trimmed.count <= Limits.emailMax else {
            throw ValidationError.tooLong(field: "Email", maximum: Limits.emailMax)
        }

        // RFC 5322 compliant email regex (simplified but robust)
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        guard predicate.evaluate(with: trimmed) else {
            throw ValidationError.invalidFormat(field: "Email", reason: "Must be a valid email address")
        }

        // Additional security check: prevent common malicious patterns
        let maliciousPatterns = ["<script", "javascript:", "data:", "vbscript:", "onload="]
        for pattern in maliciousPatterns {
            if trimmed.lowercased().contains(pattern) {
                throw ValidationError.containsMaliciousContent
            }
        }

        return trimmed
    }

    // MARK: - Password Validation

    /// Validates password with comprehensive security requirements
    /// - Parameter password: The password to validate
    /// - Returns: The password if valid
    /// - Throws: ValidationError if invalid
    static func validatePassword(_ password: String) throws -> String {
        guard !password.isEmpty else {
            throw ValidationError.emptyInput(field: "Password")
        }

        guard password.count >= Limits.passwordMin else {
            throw ValidationError.tooShort(field: "Password", minimum: Limits.passwordMin)
        }

        guard password.count <= Limits.passwordMax else {
            throw ValidationError.tooLong(field: "Password", maximum: Limits.passwordMax)
        }

        var weaknesses: [String] = []

        // Check for uppercase letters
        if !password.contains(where: { $0.isUppercase }) {
            weaknesses.append("needs at least one uppercase letter")
        }

        // Check for lowercase letters
        if !password.contains(where: { $0.isLowercase }) {
            weaknesses.append("needs at least one lowercase letter")
        }

        // Check for numbers
        if !password.contains(where: { $0.isNumber }) {
            weaknesses.append("needs at least one number")
        }

        // Check for special characters
        let specialCharacters = CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")
        if password.unicodeScalars.first(where: { specialCharacters.contains($0) }) == nil {
            weaknesses.append("needs at least one special character (!@#$%^&* etc.)")
        }

        // Check for common weak passwords
        let commonPasswords = ["password", "123456", "qwerty", "admin", "letmein", "welcome"]
        if commonPasswords.contains(password.lowercased()) {
            weaknesses.append("is too common")
        }

        // Check for sequential characters
        if containsSequentialCharacters(password) {
            weaknesses.append("contains too many sequential characters")
        }

        if !weaknesses.isEmpty {
            throw ValidationError.passwordTooWeak(reasons: weaknesses)
        }

        return password
    }

    /// Checks if password contains sequential characters (e.g., "abc", "123")
    private static func containsSequentialCharacters(_ password: String) -> Bool {
        let lowercased = password.lowercased()
        let sequences = ["abc", "bcd", "cde", "def", "efg", "fgh", "ghi", "hij", "ijk", "jkl", "klm",
                        "lmn", "mno", "nop", "opq", "pqr", "qrs", "rst", "stu", "tuv", "uvw", "vwx",
                        "wxy", "xyz", "123", "234", "345", "456", "567", "678", "789"]
        return sequences.contains { lowercased.contains($0) }
    }

    // MARK: - Task Validation

    /// Validates a task title
    /// - Parameter title: The task title to validate
    /// - Returns: Sanitized and validated task title
    /// - Throws: ValidationError if invalid
    static func validateTaskTitle(_ title: String) throws -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ValidationError.emptyInput(field: "Task title")
        }

        guard trimmed.count >= Limits.taskTitleMin else {
            throw ValidationError.tooShort(field: "Task title", minimum: Limits.taskTitleMin)
        }

        guard trimmed.count <= Limits.taskTitleMax else {
            throw ValidationError.tooLong(field: "Task title", maximum: Limits.taskTitleMax)
        }

        // Check for malicious content
        try checkForMaliciousContent(trimmed, field: "Task title")

        // Sanitize by removing control characters but keeping emojis and international text
        let sanitized = trimmed.components(separatedBy: .controlCharacters).joined()

        return sanitized
    }

    /// Validates task notes
    /// - Parameter notes: The task notes to validate
    /// - Returns: Sanitized and validated task notes
    /// - Throws: ValidationError if invalid
    static func validateTaskNotes(_ notes: String?) throws -> String? {
        guard let notes = notes, !notes.isEmpty else {
            return nil
        }

        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return nil
        }

        guard trimmed.count <= Limits.taskNotesMax else {
            throw ValidationError.tooLong(field: "Task notes", maximum: Limits.taskNotesMax)
        }

        // Check for malicious content
        try checkForMaliciousContent(trimmed, field: "Task notes")

        // Sanitize control characters
        let sanitized = trimmed.components(separatedBy: .controlCharacters).joined()

        return sanitized
    }

    // MARK: - Orb Validation

    /// Validates an orb (project) name
    /// - Parameter name: The orb name to validate
    /// - Returns: Sanitized and validated orb name
    /// - Throws: ValidationError if invalid
    static func validateOrbName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ValidationError.emptyInput(field: "Project name")
        }

        guard trimmed.count >= Limits.orbNameMin else {
            throw ValidationError.tooShort(field: "Project name", minimum: Limits.orbNameMin)
        }

        guard trimmed.count <= Limits.orbNameMax else {
            throw ValidationError.tooLong(field: "Project name", maximum: Limits.orbNameMax)
        }

        // Check for malicious content
        try checkForMaliciousContent(trimmed, field: "Project name")

        // Sanitize control characters
        let sanitized = trimmed.components(separatedBy: .controlCharacters).joined()

        return sanitized
    }

    // MARK: - Voice Command Validation

    /// Validates and sanitizes voice command input
    /// - Parameter command: The voice command to validate
    /// - Returns: Sanitized voice command
    /// - Throws: ValidationError if invalid
    static func validateVoiceCommand(_ command: String) throws -> String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ValidationError.emptyInput(field: "Voice command")
        }

        guard trimmed.count <= Limits.voiceCommandMax else {
            throw ValidationError.tooLong(field: "Voice command", maximum: Limits.voiceCommandMax)
        }

        // Check for malicious content (important for voice commands!)
        try checkForMaliciousContent(trimmed, field: "Voice command")

        // Sanitize control characters
        let sanitized = trimmed.components(separatedBy: .controlCharacters).joined()

        return sanitized
    }

    // MARK: - Malicious Content Detection

    /// Checks for potentially malicious content patterns
    /// - Parameters:
    ///   - input: The input to check
    ///   - field: The field name for error messages
    /// - Throws: ValidationError.containsMaliciousContent if malicious patterns detected
    private static func checkForMaliciousContent(_ input: String, field: String) throws {
        let lowercased = input.lowercased()

        // SQL injection patterns
        let sqlPatterns = ["drop table", "delete from", "insert into", "update ", "union select",
                          "exec(", "execute(", "script", "--", "/*", "*/", "xp_", ";--"]

        // XSS patterns
        let xssPatterns = ["<script", "</script", "javascript:", "onerror=", "onload=", "onclick=",
                          "<iframe", "</iframe", "eval(", "expression(", "vbscript:", "data:text/html"]

        // Command injection patterns
        let cmdPatterns = ["$(", "`", "|", "&&", "||", ";", "\n", "\r"]

        let allPatterns = sqlPatterns + xssPatterns + cmdPatterns

        for pattern in allPatterns {
            if lowercased.contains(pattern) {
                DebugLog.log("⚠️ Malicious content detected in \(field): pattern '\(pattern)'", category: .app)
                throw ValidationError.containsMaliciousContent
            }
        }
    }

    // MARK: - Safe String Utilities

    /// Creates a safe filename from user input
    /// - Parameter input: The input string
    /// - Returns: A safe filename string
    static func sanitizeFilename(_ input: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let components = input.components(separatedBy: invalidChars)
        let cleaned = components.joined()
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Limit length for filesystem compatibility
        let maxLength = 255
        if trimmed.count > maxLength {
            return String(trimmed.prefix(maxLength))
        }

        return trimmed.isEmpty ? "untitled" : trimmed
    }

    /// Validates a URL string
    /// - Parameter urlString: The URL string to validate
    /// - Returns: A validated URL
    /// - Throws: ValidationError if invalid
    static func validateURL(_ urlString: String) throws -> URL {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ValidationError.emptyInput(field: "URL")
        }

        guard let url = URL(string: trimmed) else {
            throw ValidationError.invalidFormat(field: "URL", reason: "Invalid URL format")
        }

        // Only allow safe schemes
        let allowedSchemes = ["https", "http", "notch"]
        guard let scheme = url.scheme?.lowercased(),
              allowedSchemes.contains(scheme) else {
            throw ValidationError.invalidFormat(field: "URL", reason: "Unsupported URL scheme. Only https, http, and notch are allowed")
        }

        return url
    }
}

// MARK: - Debug Logging Extension

extension DebugLog {
    static func logValidationError(_ error: InputValidator.ValidationError, category: DebugCategory = .app) {
        if let description = error.errorDescription {
            DebugLog.log("❌ Validation error: \(description)", category: category)
        }
    }
}
