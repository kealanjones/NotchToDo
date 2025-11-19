import Foundation

/// Secure input validation utility for user-provided data
/// Prevents common security issues like injection attacks, XSS, and data corruption
enum InputValidator {
    /// Validation errors with user-friendly messages
    enum ValidationError: LocalizedError {
        case emptyInput(field: String)
        case invalidFormat(field: String)
        case tooShort(field: String, minimum: Int)
        case tooLong(field: String, maximum: Int)
        case invalidCharacters(field: String)
        case weakPassword
        case invalidEmail

        var errorDescription: String? {
            switch self {
            case .emptyInput(let field):
                return "\(field) cannot be empty"
            case .invalidFormat(let field):
                return "\(field) format is invalid"
            case .tooShort(let field, let minimum):
                return "\(field) must be at least \(minimum) characters"
            case .tooLong(let field, let maximum):
                return "\(field) must be no more than \(maximum) characters"
            case .invalidCharacters(let field):
                return "\(field) contains invalid characters"
            case .weakPassword:
                return "Password must be at least 6 characters with a mix of letters and numbers"
            case .invalidEmail:
                return "Please enter a valid email address"
            }
        }
    }

    // MARK: - Email Validation

    /// Validates email address format
    /// - Parameter email: Email string to validate
    /// - Returns: Sanitized email address
    /// - Throws: ValidationError if invalid
    static func validateEmail(_ email: String) throws -> String {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ValidationError.emptyInput(field: "Email")
        }

        guard trimmed.count <= 320 else { // RFC 5321 maximum
            throw ValidationError.tooLong(field: "Email", maximum: 320)
        }

        // Email regex pattern (RFC 5322 simplified)
        let emailRegex = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegex)

        guard emailPredicate.evaluate(with: trimmed) else {
            throw ValidationError.invalidEmail
        }

        return trimmed.lowercased()
    }

    // MARK: - Password Validation

    /// Validates password strength and format
    /// - Parameter password: Password string to validate
    /// - Returns: Validated password
    /// - Throws: ValidationError if invalid
    static func validatePassword(_ password: String) throws -> String {
        guard !password.isEmpty else {
            throw ValidationError.emptyInput(field: "Password")
        }

        guard password.count >= 6 else {
            throw ValidationError.tooShort(field: "Password", minimum: 6)
        }

        guard password.count <= 128 else {
            throw ValidationError.tooLong(field: "Password", maximum: 128)
        }

        // Check for at least one letter and one number for stronger passwords
        let hasLetter = password.rangeOfCharacter(from: .letters) != nil
        let hasNumber = password.rangeOfCharacter(from: .decimalDigits) != nil

        guard hasLetter && hasNumber else {
            throw ValidationError.weakPassword
        }

        return password
    }

    // MARK: - Generic Text Validation

    /// Validates general text input (task titles, project names, etc.)
    /// - Parameters:
    ///   - text: Text to validate
    ///   - fieldName: Name of the field for error messages
    ///   - minLength: Minimum length (default: 1)
    ///   - maxLength: Maximum length (default: 500)
    ///   - allowedCharacters: Character set to allow (default: all)
    /// - Returns: Sanitized text
    /// - Throws: ValidationError if invalid
    static func validateText(
        _ text: String,
        fieldName: String = "Input",
        minLength: Int = 1,
        maxLength: Int = 500,
        allowedCharacters: CharacterSet? = nil
    ) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ValidationError.emptyInput(field: fieldName)
        }

        guard trimmed.count >= minLength else {
            throw ValidationError.tooShort(field: fieldName, minimum: minLength)
        }

        guard trimmed.count <= maxLength else {
            throw ValidationError.tooLong(field: fieldName, maximum: maxLength)
        }

        // Check for allowed characters if specified
        if let allowedCharacters = allowedCharacters {
            let disallowedCharacters = CharacterSet(charactersIn: trimmed).subtracting(allowedCharacters)
            guard disallowedCharacters.isEmpty else {
                throw ValidationError.invalidCharacters(field: fieldName)
            }
        }

        // Sanitize: remove any control characters except newlines and tabs
        var sanitized = ""
        for scalar in trimmed.unicodeScalars {
            if CharacterSet.controlCharacters.contains(scalar) {
                // Allow newlines and tabs
                if scalar == "\n" || scalar == "\t" || scalar == "\r" {
                    sanitized.unicodeScalars.append(scalar)
                }
                // Skip other control characters
            } else {
                sanitized.unicodeScalars.append(scalar)
            }
        }

        return sanitized
    }

    // MARK: - URL Validation

    /// Validates URL format
    /// - Parameter urlString: URL string to validate
    /// - Returns: Valid URL object
    /// - Throws: ValidationError if invalid
    static func validateURL(_ urlString: String) throws -> URL {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ValidationError.emptyInput(field: "URL")
        }

        guard let url = URL(string: trimmed), url.scheme != nil else {
            throw ValidationError.invalidFormat(field: "URL")
        }

        return url
    }
}

// MARK: - Logging Helper

extension DebugLog {
    /// Log validation errors for debugging
    static func logValidationError(_ error: InputValidator.ValidationError, category: DebugCategory) {
        log("Validation failed: \(error.localizedDescription)", category: category)
    }
}
