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
    
    // End-of-speech detection parameters
    private var lastDetectedSpeechAt: CFTimeInterval = CACurrentMediaTime()
    private var isEnding = false
    private let silenceToEndSeconds: CFTimeInterval = 1.2
    private let maxRecordingSeconds: CFTimeInterval = 15.0
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
        
        // Cancel any ongoing recognition and reset engine
        if let task = recognitionTask {
            task.cancel()
            recognitionTask = nil
        }
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
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
        
        // Get audio input node
        let inputNode = audioEngine.inputNode
        
        // Start recognition task
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
                
                // Stop audio engine
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.isRunning = false
                
                // If we got an error but no final result, still send the last partial as final
                if error != nil && !isFinal, let lastTranscript = result?.bestTranscription.formattedString {
                    self.onFinal?(lastTranscript)
                }
            }
        }
        
        // Configure audio tap
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: recordingFormat) { buffer, when in
            self.recognitionRequest?.append(buffer)
            // Energy-based silence detection
            let rms = buffer.rms()
            if rms > self.minSpeechRMS {
                self.lastDetectedSpeechAt = CACurrentMediaTime()
            }
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        DebugLog.log("Audio engine started (input format: \(recordingFormat))", category: .speech)
        isRunning = true
        isEnding = false
        lastDetectedSpeechAt = CACurrentMediaTime()
        
        // Timer to check for end-of-speech or hard timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.pollForEndConditions()
        }
        DebugLog.log("Speech recognition started successfully", category: .speech)
    }
    
    func stop() {
        guard isRunning else { return }
        
        DebugLog.log("Stopping speech recognition", category: .speech)
        
        // Stop audio engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // End recognition request
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Cancel recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isRunning = false
        isEnding = false
        
        DebugLog.log("Speech recognition stopped", category: .speech)
    }

    // MARK: - End Conditions
    private func pollForEndConditions() {
        guard isRunning, !isEnding else { return }
        let now = CACurrentMediaTime()
        let sinceSpeech = now - lastDetectedSpeechAt
        if sinceSpeech >= silenceToEndSeconds {
            isEnding = true
            DebugLog.log("Ending due to silence (\(String(format: "%.2f", sinceSpeech))s)", category: .speech)
            recognitionRequest?.endAudio()
            return
        }
        if sinceSpeech >= maxRecordingSeconds {
            isEnding = true
            DebugLog.log("Ending due to max duration", category: .speech)
            recognitionRequest?.endAudio()
            return
        }
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

