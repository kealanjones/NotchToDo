import Foundation
import Speech
import AVFoundation
import Accelerate

/// Real-time speech recognizer using Apple's Speech framework
/// Provides live transcription with partial and final results
class RealSpeechRecognizer: SpeechRecognizer {
    var onPartial: ((String) -> Void)?
    var onFinal: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var isRunning = false
    private var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    private let stateLock = NSLock()
    private var sessionID = 0  // Track session for debugging
    
    // End-of-speech detection parameters
    private var recordingStartedAt: CFTimeInterval = CACurrentMediaTime()
    private var lastDetectedSpeechAt: CFTimeInterval = CACurrentMediaTime()
    private var isEnding = false
    private let silenceToEndSeconds: CFTimeInterval = 1.2
    private let maxRecordingSeconds: CFTimeInterval = 10.0  // Maximum 10 seconds recording
    private let minSpeechRMS: Float = 0.01 // ~-40dB; adjust if needed
    
    init(locale: Locale = Locale(identifier: "en-US")) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        
        // Check initial authorization status
        self.authorizationStatus = SFSpeechRecognizer.authorizationStatus()
        
        // Configure speech recognizer for better performance
        speechRecognizer?.defaultTaskHint = .dictation
        
        DebugLog.log("RealSpeechRecognizer initialized with locale: \(locale.identifier)", category: .speech)
        DebugLog.log("Initial authorization status: \(authorizationStatus.rawValue)", category: .speech)
    }
    
    deinit {
        stop()
        DebugLog.log("RealSpeechRecognizer deinitialized", category: .speech)
    }
    
    func start() throws {
        guard !isRunning else {
            DebugLog.log("Speech recognizer already running", category: .speech)
            return
        }

        // Check authorization status
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined:
            DebugLog.log("Speech recognition authorization not determined - requesting", category: .speech)
            requestAuthorization { [weak self] in
                if $0 {
                    try? self?.startRecognition()
                }
            }
            return
        case .denied, .restricted:
            DebugLog.log("Speech recognition authorization denied or restricted", category: .speech)
            let message = "Speech recognition access denied. Please enable it in System Settings > Privacy & Security > Speech Recognition."
            onError?(message)
            throw SpeechRecognitionError.authorizationDenied
        case .authorized:
            break
        @unknown default:
            break
        }

        try startRecognition()
    }
    
    private func startRecognition() throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            DebugLog.log("Speech recognizer not available", category: .speech)
            let message = "Speech recognition is not available. Please check your internet connection and try again."
            onError?(message)
            throw SpeechRecognitionError.recognizerNotAvailable
        }

        // Acquire lock to ensure single-threaded cleanup
        stateLock.lock()

        sessionID += 1
        let currentSessionID = sessionID
        DebugLog.log("🆕 Starting recognition session #\(currentSessionID) - isRunning=\(isRunning), isEnding=\(isEnding)", category: .speech)

        // Force complete cleanup of any previous session
        if let task = recognitionTask {
            DebugLog.log("Cancelling previous recognition task", category: .speech)
            task.cancel()
            recognitionTask = nil
        }

        // Clean up recognition request
        if recognitionRequest != nil {
            recognitionRequest?.endAudio()
            recognitionRequest = nil
            DebugLog.log("Cleaned up previous recognition request", category: .speech)
        }

        // Reset all state flags
        isRunning = false
        isEnding = false

        // Release lock before audio operations (they can take time and block)
        stateLock.unlock()

        // Always try to stop and clean up audio engine (outside lock to avoid blocking)
        if audioEngine.isRunning {
            DebugLog.log("Stopping running audio engine", category: .speech)
            audioEngine.stop()
        }

        // Always remove tap to ensure clean state
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        DebugLog.log("Removed audio tap from input node", category: .speech)

        // CRITICAL: Give audio engine time to fully release resources
        // This prevents conflicts when wake word engine just stopped
        Thread.sleep(forTimeInterval: 0.15)
        
        // Configure audio session (iOS/tvOS only). On macOS, AVAudioSession APIs are unavailable.
        #if os(iOS) || os(tvOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.unableToCreateRequest
        }
        
        // Configure request
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false // Allow network for better accuracy

        // Start recognition task (inputNode already declared above for cleanup)
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                DebugLog.log("Speech result: '\(transcription)' (final: \(result.isFinal))", category: .speech)
                
                isFinal = result.isFinal
                
                if isFinal {
                    self.onFinal?(transcription)
                } else {
                    self.onPartial?(transcription)
                }
            }
            
            if error != nil || isFinal {
                DebugLog.log("Speech recognition ended: error=\(error?.localizedDescription ?? "none"), isFinal=\(isFinal)", category: .speech)

                // Perform cleanup synchronously on main thread
                DispatchQueue.main.async {
                    self.stateLock.lock()

                    // Stop audio engine
                    if self.audioEngine.isRunning {
                        self.audioEngine.stop()
                    }
                    inputNode.removeTap(onBus: 0)

                    // Clean up all state
                    self.recognitionRequest = nil
                    self.recognitionTask = nil
                    self.isRunning = false
                    self.isEnding = false

                    DebugLog.log("✅ Recognition cleanup complete (session #\(currentSessionID))", category: .speech)

                    self.stateLock.unlock()
                }

                // If we got an error but no final result, still send the last partial as final
                if error != nil && !isFinal, let lastTranscript = result?.bestTranscription.formattedString {
                    DebugLog.log("Sending error recovery final result: '\(lastTranscript)'", category: .speech)
                    self.onFinal?(lastTranscript)
                }
            }
        }
        
        // Configure audio tap
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        DebugLog.log("Installing audio tap with format: \(recordingFormat)", category: .speech)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: recordingFormat) { [weak self] buffer, when in
            guard let self = self else { return }
            self.recognitionRequest?.append(buffer)
            // Energy-based silence detection
            let rms = buffer.rms()
            if rms > self.minSpeechRMS {
                self.stateLock.lock()
                self.lastDetectedSpeechAt = CACurrentMediaTime()
                self.stateLock.unlock()
            }
        }

        // Start audio engine
        audioEngine.prepare()

        do {
            try audioEngine.start()
            DebugLog.log("Audio engine started successfully (format: \(recordingFormat))", category: .speech)
        } catch {
            DebugLog.log("⚠️ Audio engine failed to start: \(error.localizedDescription)", category: .speech)
            // Clean up and retry after longer delay
            inputNode.removeTap(onBus: 0)
            self.recognitionRequest = nil
            DebugLog.log("⚠️ Waiting longer for audio resources and retrying...", category: .speech)
            Thread.sleep(forTimeInterval: 0.25)

            // Re-create recognition request for retry
            self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let retryRequest = self.recognitionRequest else {
                throw SpeechRecognitionError.unableToCreateRequest
            }
            retryRequest.shouldReportPartialResults = true
            retryRequest.requiresOnDeviceRecognition = false

            // Reinstall tap for retry
            inputNode.installTap(onBus: 0, bufferSize: 2048, format: recordingFormat) { [weak self] buffer, when in
                guard let self = self else { return }
                self.recognitionRequest?.append(buffer)
                let rms = buffer.rms()
                if rms > self.minSpeechRMS {
                    self.stateLock.lock()
                    self.lastDetectedSpeechAt = CACurrentMediaTime()
                    self.stateLock.unlock()
                }
            }

            // Second attempt
            audioEngine.prepare()
            try audioEngine.start()
            DebugLog.log("✅ Audio engine started on retry", category: .speech)
        }

        // NOW set running state after everything is successfully started (re-acquire lock)
        stateLock.lock()
        isRunning = true
        isEnding = false
        recordingStartedAt = CACurrentMediaTime()
        lastDetectedSpeechAt = CACurrentMediaTime()
        stateLock.unlock()

        DebugLog.log("Recording session initialized - isRunning=\(isRunning), isEnding=\(isEnding)", category: .speech)
        
        // Timer to check for end-of-speech or hard timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.pollForEndConditions()
        }

        DebugLog.log("✅ Speech recognition started successfully (session #\(currentSessionID))", category: .speech)
    }
    
    func stop() {
        stateLock.lock()
        defer { stateLock.unlock() }

        DebugLog.log("stop() called - current state: isRunning=\(isRunning), isEnding=\(isEnding)", category: .speech)

        // Always perform cleanup, even if not marked as running
        // This prevents stuck states

        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            DebugLog.log("Audio engine stopped", category: .speech)
        }

        // Remove tap (safe even if no tap exists)
        audioEngine.inputNode.removeTap(onBus: 0)

        // End recognition request
        if let request = recognitionRequest {
            request.endAudio()
            DebugLog.log("Recognition request ended", category: .speech)
        }
        recognitionRequest = nil

        // Cancel recognition task - this will trigger the completion handler
        if let task = recognitionTask {
            task.cancel()
            DebugLog.log("Recognition task cancelled", category: .speech)
        }
        recognitionTask = nil

        // Reset all state flags
        isRunning = false
        isEnding = false

        DebugLog.log("✅ Speech recognition stopped and cleaned up completely", category: .speech)
    }

    // MARK: - End Conditions
    private func pollForEndConditions() {
        // Thread-safe read of state variables
        stateLock.lock()
        let currentlyRunning = isRunning
        let currentlyEnding = isEnding
        let speechTime = lastDetectedSpeechAt
        let startTime = recordingStartedAt
        stateLock.unlock()

        guard currentlyRunning, !currentlyEnding else {
            if !currentlyRunning {
                DebugLog.log("pollForEndConditions: Not running, stopping poll", category: .speech)
            }
            if currentlyEnding {
                DebugLog.log("pollForEndConditions: Already ending, stopping poll", category: .speech)
            }
            return
        }

        let now = CACurrentMediaTime()
        let sinceSpeech = now - speechTime
        let totalRecordingTime = now - startTime

        // Log every second to track progress
        let timeInterval = Int(totalRecordingTime * 10)
        if timeInterval % 10 == 0 {
            DebugLog.log("Recording progress: \(String(format: "%.1f", totalRecordingTime))s / \(String(format: "%.1f", maxRecordingSeconds))s, silence: \(String(format: "%.1f", sinceSpeech))s", category: .speech)
        }

        // Check for max recording duration first (hard timeout)
        if totalRecordingTime >= maxRecordingSeconds {
            stateLock.lock()
            isEnding = true
            stateLock.unlock()
            DebugLog.log("⏱️ Ending due to max duration (\(String(format: "%.2f", totalRecordingTime))s)", category: .speech)
            recognitionRequest?.endAudio()
            return
        }

        // Check for silence
        if sinceSpeech >= silenceToEndSeconds {
            stateLock.lock()
            isEnding = true
            stateLock.unlock()
            DebugLog.log("🤫 Ending due to silence (\(String(format: "%.2f", sinceSpeech))s)", category: .speech)
            recognitionRequest?.endAudio()
            return
        }

        // Continue polling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.pollForEndConditions()
        }
    }
    
    // MARK: - Authorization
    
    private func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.authorizationStatus = status
                let authorized = status == .authorized
                DebugLog.log("Speech recognition authorization: \(status.rawValue) (authorized: \(authorized))", category: .speech)
                completion(authorized)
            }
        }
    }
    
    func checkAuthorization(completion: @escaping (Bool) -> Void) {
        let status = SFSpeechRecognizer.authorizationStatus()
        
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            requestAuthorization(completion: completion)
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
}

// MARK: - Errors

enum SpeechRecognitionError: LocalizedError {
    case authorizationDenied
    case recognizerNotAvailable
    case unableToCreateRequest
    case audioEngineError
    
    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Speech recognition access denied. Please enable it in System Settings."
        case .recognizerNotAvailable:
            return "Speech recognizer is not available for this language."
        case .unableToCreateRequest:
            return "Unable to create speech recognition request."
        case .audioEngineError:
            return "Audio engine error occurred."
        }
    }
}

// MARK: - Audio utilities
private extension AVAudioPCMBuffer {
    func rms() -> Float {
        guard let channelData = floatChannelData else { return 0 }
        let frameLength = Int(self.frameLength)
        var sum: Float = 0
        vDSP_measqv(channelData[0], 1, &sum, vDSP_Length(frameLength))
        return sqrtf(sum)
    }
}

