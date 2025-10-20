import AppKit

final class AudioFeedback {
    static let shared = AudioFeedback()
    private init() {}

    enum Cue {
        case wake
        case startListening
        case success
        case error
    }

    private let defaultsKey = "AudioFeedbackEnabled"

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    func play(_ cue: Cue, volume: Float = 1.0) {
        guard isEnabled else { return }

        let name: NSSound.Name
        switch cue {
        case .wake:
            name = NSSound.Name("Submarine")
        case .startListening:
            name = NSSound.Name("Glass")
        case .success:
            name = NSSound.Name("Pop")
        case .error:
            name = NSSound.Name("Basso")
        }

        if let sound = NSSound(named: name) {
            sound.volume = volume
            sound.play()
        } else {
            // Fallback beep if named sound is unavailable
            NSBeep()
        }
    }
}


