import Foundation

/// User-friendly error handling utilities
public enum UserFacingError {
    
    /// Represents an error that can be shown to the user
    public struct DisplayableError: LocalizedError {
        public let title: String
        public let message: String
        public let suggestion: String?
        public let isRetryable: Bool
        public let underlyingError: Error?
        
        public var errorDescription: String? { message }
        public var recoverySuggestion: String? { suggestion }
        
        public init(
            title: String,
            message: String,
            suggestion: String? = nil,
            isRetryable: Bool = false,
            underlyingError: Error? = nil
        ) {
            self.title = title
            self.message = message
            self.suggestion = suggestion
            self.isRetryable = isRetryable
            self.underlyingError = underlyingError
        }
    }
    
    // MARK: - Network Errors
    
    public static let networkUnavailable = DisplayableError(
        title: "No Connection",
        message: "Unable to connect to the server. Please check your internet connection.",
        suggestion: "Make sure you're connected to Wi-Fi or have cellular data enabled.",
        isRetryable: true
    )
    
    public static let serverError = DisplayableError(
        title: "Server Error",
        message: "Something went wrong on our end. Please try again later.",
        suggestion: "If this problem persists, contact support.",
        isRetryable: true
    )
    
    public static let timeout = DisplayableError(
        title: "Request Timed Out",
        message: "The request took too long to complete.",
        suggestion: "Please check your connection and try again.",
        isRetryable: true
    )
    
    // MARK: - Authentication Errors
    
    public static let sessionExpired = DisplayableError(
        title: "Session Expired",
        message: "Your session has expired. Please sign in again.",
        suggestion: "Tap 'Sign In' to continue.",
        isRetryable: false
    )
    
    public static let invalidCredentials = DisplayableError(
        title: "Invalid Credentials",
        message: "The email or password you entered is incorrect.",
        suggestion: "Please check your credentials and try again.",
        isRetryable: false
    )
    
    public static let accountLocked = DisplayableError(
        title: "Account Locked",
        message: "Your account has been temporarily locked due to too many failed attempts.",
        suggestion: "Please wait a few minutes before trying again.",
        isRetryable: false
    )
    
    // MARK: - Sync Errors
    
    public static let syncFailed = DisplayableError(
        title: "Sync Failed",
        message: "Unable to sync your data. Your changes are saved locally.",
        suggestion: "We'll automatically retry when your connection improves.",
        isRetryable: true
    )
    
    public static let conflictDetected = DisplayableError(
        title: "Sync Conflict",
        message: "Your data was modified on another device. We've kept the most recent version.",
        suggestion: nil,
        isRetryable: false
    )
    
    // MARK: - Data Errors
    
    public static let taskNotFound = DisplayableError(
        title: "Task Not Found",
        message: "This task may have been deleted or moved.",
        suggestion: "Try refreshing the list.",
        isRetryable: true
    )
    
    public static let orbNotFound = DisplayableError(
        title: "Project Not Found",
        message: "This project may have been deleted or moved.",
        suggestion: "Try refreshing the list.",
        isRetryable: true
    )
    
    public static let saveFailed = DisplayableError(
        title: "Save Failed",
        message: "Unable to save your changes. Please try again.",
        suggestion: "If this problem persists, try closing and reopening the app.",
        isRetryable: true
    )
    
    public static let deleteFailed = DisplayableError(
        title: "Delete Failed",
        message: "Unable to delete this item. Please try again.",
        suggestion: nil,
        isRetryable: true
    )
    
    // MARK: - Permission Errors
    
    public static let microphoneAccessDenied = DisplayableError(
        title: "Microphone Access Required",
        message: "Voice commands require microphone access.",
        suggestion: "Go to Settings > Privacy > Microphone and enable access for this app.",
        isRetryable: false
    )
    
    // MARK: - Error Mapping
    
    /// Converts a system error to a user-friendly displayable error
    public static func from(_ error: Error) -> DisplayableError {
        // Check for URL errors (network issues)
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return networkUnavailable
            case .timedOut:
                return timeout
            case .cannotFindHost, .cannotConnectToHost:
                return serverError
            default:
                return DisplayableError(
                    title: "Network Error",
                    message: "A network error occurred: \(urlError.localizedDescription)",
                    suggestion: "Please check your connection and try again.",
                    isRetryable: true,
                    underlyingError: error
                )
            }
        }
        
        // Check for Supabase service errors
        if let supaError = error as? SupabaseService.ServiceError {
            switch supaError {
            case .invalidResponse(let status, _):
                switch status {
                case 401:
                    return sessionExpired
                case 403:
                    return DisplayableError(
                        title: "Access Denied",
                        message: "You don't have permission to perform this action.",
                        suggestion: nil,
                        isRetryable: false,
                        underlyingError: error
                    )
                case 404:
                    return taskNotFound
                case 409:
                    return conflictDetected
                case 429:
                    return DisplayableError(
                        title: "Too Many Requests",
                        message: "Please slow down and try again in a moment.",
                        suggestion: nil,
                        isRetryable: true,
                        underlyingError: error
                    )
                case 500...599:
                    return serverError
                default:
                    return DisplayableError(
                        title: "Request Failed",
                        message: "Something went wrong. Please try again.",
                        suggestion: nil,
                        isRetryable: true,
                        underlyingError: error
                    )
                }
            case .invalidConfiguration:
                return DisplayableError(
                    title: "Configuration Error",
                    message: "The app is not configured correctly.",
                    suggestion: "Please contact support.",
                    isRetryable: false,
                    underlyingError: error
                )
            case .missingCredentials:
                return sessionExpired
            }
        }
        
        // Check for validation errors
        if let validationError = error as? InputValidation.ValidationError {
            return DisplayableError(
                title: "Invalid Input",
                message: validationError.errorDescription ?? "Please check your input.",
                suggestion: validationError.recoverySuggestion,
                isRetryable: false,
                underlyingError: error
            )
        }
        
        // Default fallback
        return DisplayableError(
            title: "Error",
            message: error.localizedDescription,
            suggestion: "Please try again. If the problem persists, contact support.",
            isRetryable: true,
            underlyingError: error
        )
    }
}
