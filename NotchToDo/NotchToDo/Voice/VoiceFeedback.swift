import Foundation
import AVFoundation

/// Provides voice feedback for task operations
/// Uses Apple's AVSpeechSynthesizer for natural-sounding speech
class VoiceFeedback {
    static let shared = VoiceFeedback()

    private let synthesizer = AVSpeechSynthesizer()
    private var isEnabled: Bool = true
    private let defaultRate: Float = 0.5  // Normal speed
    private let defaultVolume: Float = 0.7

    private init() {
        DebugLog.log("VoiceFeedback initialized", category: .speech)
    }

    /// Enable or disable voice feedback
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            stopSpeaking()
        }
        DebugLog.log("Voice feedback \(enabled ? "enabled" : "disabled")", category: .speech)
    }

    /// Speak text with default settings
    func speak(_ text: String) {
        speak(text, rate: defaultRate, volume: defaultVolume)
    }

    /// Speak text with custom rate and volume
    func speak(_ text: String, rate: Float, volume: Float) {
        guard isEnabled else { return }

        // Stop any ongoing speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = rate
        utterance.volume = volume
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.0
        utterance.postUtteranceDelay = 0.0

        DebugLog.log("Speaking: '\(text)'", category: .speech)
        synthesizer.speak(utterance)
    }

    /// Stop any currently playing speech
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            DebugLog.log("Stopped speaking", category: .speech)
        }
    }

    // MARK: - Convenience Methods for Common Feedback

    /// Announce task creation with details
    func announceTaskCreation(title: String, orb: String?, dueDate: Date? = nil) {
        var message = "Creating '\(title)'"

        if let orb = orb {
            message += " in \(orb)"
        }

        if let dueDate = dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            message += ", due \(formatter.string(from: dueDate))"
        }

        speak(message)
    }

    /// Announce successful task completion
    func announceSuccess(_ message: String = "Done") {
        speak(message, rate: 0.55, volume: 0.6)
    }

    /// Announce an error
    func announceError(_ message: String) {
        speak("Error: \(message)", rate: 0.45, volume: 0.8)
    }

    /// Announce a question or confirmation request
    func announceQuestion(_ message: String) {
        speak(message, rate: 0.48, volume: 0.7)
    }

    /// Format task intent into natural speech
    func announceIntent(_ intent: TaskIntent) {
        var message = ""

        switch intent.action {
        case .create:
            message = "Creating task '\(intent.title)'"
        case .update:
            message = "Updating '\(intent.title)'"
        case .delete:
            message = "Deleting '\(intent.title)'"
        case .complete:
            message = "Completing '\(intent.title)'"
        case .move:
            message = "Moving '\(intent.title)'"
        default:
            message = "Processing '\(intent.title)'"
        }

        if let orb = intent.targetOrb {
            message += " in \(orb)"
        }

        if let dueDate = intent.combinedDueDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let dateString = formatter.localizedString(for: dueDate, relativeTo: Date())
            message += ", due \(dateString)"
        }

        if let priority = intent.priority {
            switch priority {
            case 3:
                message += ", high priority"
            case 1:
                message += ", low priority"
            default:
                break
            }
        }

        speak(message)
    }
}
