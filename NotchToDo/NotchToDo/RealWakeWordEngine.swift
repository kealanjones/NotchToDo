import Foundation
import Speech
import AVFoundation

/// Real-time wake word detection using continuous speech recognition
/// Listens for wake words: "Hey Notch", "OK Notch", "Notch"
class RealWakeWordEngine: WakeWordEngine {
    var onTriggered: (() -> Void)?
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var isRunning = false
    private var lastTriggerTime: Date?
    private let triggerCooldown: TimeInterval = 1.2 // More responsive
    
    // Wake word variations (lowercase for comparison)
    private let wakeWords: Set<String> = [
        "hey notch",
        "ok notch",
        "okay notch",
        "notch"
    ]
    
    // Minimum confidence threshold for wake word detection
    private let confidenceThreshold: Float = 0.7
    
    init(locale: Locale = Locale(identifier: "en-US")) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer?.defaultTaskHint = .dictation
        
        DebugLog.log("RealWakeWordEngine initialized", category: .speech)
    }
    
    deinit {
        stop()
        DebugLog.log("RealWakeWordEngine deinitialized", category: .speech)
    }
    
    func start() throws {
        guard !isRunning else {
            DebugLog.log("Wake word engine already running", category: .speech)
            return
        }
        
        // Check authorization
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined:
            DebugLog.log("Speech recognition not authorized - requesting", category: .speech)
            SFSpeechRecognizer.requestAuthorization { status in
                if status == .authorized {
                    try? self.startListening()
                }
            }
            return
        case .denied, .restricted:
            DebugLog.log("Speech recognition authorization denied", category: .speech)
            throw WakeWordError.authorizationDenied
        case .authorized:
            break
        @unknown default:
            break
        }
        
        try startListening()
    }
    
    private func startListening() throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw WakeWordError.recognizerNotAvailable
        }
        
        // Cancel any existing task
        if let task = recognitionTask {
            task.cancel()
            recognitionTask = nil
        }
        
        // Configure audio session for background listening (iOS/tvOS only)
        #if os(iOS) || os(tvOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            throw WakeWordError.unableToCreateRequest
        }
        
        // Configure for continuous listening
        recognitionRequest.shouldReportPartialResults = true
        // Prefer on-device for lower latency and better responsiveness for wake phrase
        recognitionRequest.requiresOnDeviceRecognition = true
        
        // Get audio input
        let inputNode = audioEngine.inputNode
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                // Consider multiple hypotheses to improve robustness
                var hypotheses: [String] = [result.bestTranscription.formattedString]
                for alt in result.transcriptions {
                    let text = alt.formattedString
                    if !hypotheses.contains(text) {
                        hypotheses.append(text)
                    }
                }
                var triggered = false
                for hyp in hypotheses {
                    let transcript = hyp.lowercased()
                    DebugLog.log("Wake listen partial='\(transcript)' final=\(result.isFinal)", category: .speech)
                    if self.checkForWakeWord(in: transcript) {
                        triggered = true
                        break
                    }
                }
                if triggered {
                    return
                }
                
                // Keep listening - don't stop on final results for wake word detection
                if result.isFinal {
                    // Restart recognition to continue listening
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if self.isRunning {
                            self.restartRecognition()
                        }
                    }
                }
            }
            
            if let error = error {
                DebugLog.log("Wake word detection error: \(error.localizedDescription)", category: .speech)
                
                // Restart on error if still running
                if self.isRunning {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if self.isRunning {
                            self.restartRecognition()
                        }
                    }
                }
            }
        }
        
        // Configure audio tap
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 512, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        isRunning = true
        DebugLog.log("Wake word detection started - listening for: \(wakeWords.joined(separator: ", "))", category: .speech)
    }
    
    private func restartRecognition() {
        guard isRunning else { return }
        
        // Stop current recognition
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        // Start new recognition
        do {
            try startListening()
        } catch {
            DebugLog.log("Failed to restart wake word detection: \(error)", category: .speech)
        }
    }
    
    @discardableResult
    private func checkForWakeWord(in transcript: String) -> Bool {
        // Check cooldown period
        if let lastTrigger = lastTriggerTime {
            let timeSinceLastTrigger = Date().timeIntervalSince(lastTrigger)
            if timeSinceLastTrigger < triggerCooldown {
                return false
            }
        }
        
        // Examine only the last few words (most recent 2-3 seconds of speech)
        let tokens = transcript.split { !$0.isLetter }.map { String($0) }
        let lastWindow = tokens.suffix(4).joined(separator: " ")
        
        // Check if transcript contains any wake word
        for wakeWord in wakeWords {
            if lastWindow.contains(wakeWord) || isPhoneticMatch(lastWindow, wakeWord: wakeWord) {
                DebugLog.log("Wake word detected: '\(wakeWord)' in transcript: '\(transcript)' (window='\(lastWindow)')", category: .speech)
                
                // Slightly more permissive: trigger if near start or standalone
                let isValidTrigger: Bool = transcript.hasPrefix(wakeWord) || transcript == wakeWord || transcript.contains("\(wakeWord) ") || isPhoneticMatch(lastWindow, wakeWord: wakeWord)
                
                if isValidTrigger {
                    lastTriggerTime = Date()
                    DebugLog.log("Valid wake word trigger confirmed!", category: .speech)
                    
                    // Trigger callback on main thread
                    DispatchQueue.main.async {
                        self.onTriggered?()
                    }
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Fuzzy/phonetic matching helpers
    private func isPhoneticMatch(_ text: String, wakeWord: String) -> Bool {
        // Allow common variations that ASR might produce
        let variants: [String] = ["notch", "noch", "natch", "notchh", "nodge", "not", "natchh"]
        if variants.contains(where: { text.contains($0) }) && wakeWord.contains("notch") {
            return true
        }
        // Levenshtein distance within small threshold for the last token
        let last = text.split(separator: " ").last.map(String.init) ?? text
        let d = editDistance(between: last, and: wakeWord)
        return d <= 1
    }

    private func editDistance(between a: String, and b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let n = aChars.count
        let m = bChars.count
        if n == 0 { return m }
        if m == 0 { return n }
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 0...n { dp[i][0] = i }
        for j in 0...m { dp[0][j] = j }
        for i in 1...n {
            for j in 1...m {
                if aChars[i-1] == bChars[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = min(dp[i-1][j-1], min(dp[i-1][j], dp[i][j-1])) + 1
                }
            }
        }
        return dp[n][m]
    }
    
    func stop() {
        guard isRunning else { return }
        
        DebugLog.log("Stopping wake word detection", category: .speech)
        
        isRunning = false
        
        // Stop audio engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // End recognition
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Cancel task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        DebugLog.log("Wake word detection stopped", category: .speech)
    }

    // Expose running state to coordinate with dictation
    var isActive: Bool { isRunning }
}

// MARK: - Errors

enum WakeWordError: LocalizedError {
    case authorizationDenied
    case recognizerNotAvailable
    case unableToCreateRequest
    
    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Microphone access denied. Please enable it in System Settings."
        case .recognizerNotAvailable:
            return "Speech recognizer is not available."
        case .unableToCreateRequest:
            return "Unable to create wake word detection request."
        }
    }
}

