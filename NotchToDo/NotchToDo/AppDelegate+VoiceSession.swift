import Foundation

// MARK: - Voice Session Pipeline

extension AppDelegate {

    func setupRealVoiceEngines() {
        DebugLog.log("🎤 Setting up REAL voice engines", category: .speech)

        // Create real wake word engine
        let realWakeWordEngine = RealWakeWordEngine()
        realWakeWordEngine.onTriggered = { [weak self] in
            DebugLog.log("🎤 Real wake word detected!", category: .speech)
            // Provide immediate UI feedback even before bubble
            self?.overlayController?.setState(.wake)
            AudioFeedback.shared.play(.wake, volume: 0.65)
            self?.handleWakeWordTriggered()
        }

        // Start wake word detection
        do {
            try realWakeWordEngine.start()
            DebugLog.log("🎤 Real wake word engine started successfully", category: .speech)
        } catch {
            DebugLog.log("🎤 Failed to start real wake word engine: \(error.localizedDescription)", category: .speech)
            // Fall back to mock if real fails
            setupMockVoiceEngines()
            return
        }

        // Give the recognizer a tiny priming delay to stabilize the input
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            DebugLog.log("Wake word engine primed", category: .speech)
        }

        wakeWordEngine = realWakeWordEngine

        // Create real speech recognizer
        let realSpeechRecognizer = RealSpeechRecognizer()
        realSpeechRecognizer.onPartial = { [weak self] partial in
            DebugLog.log("🎤 Real partial transcript: '\(partial)'", category: .speech)
            self?.handlePartialTranscript(partial)
        }
        realSpeechRecognizer.onFinal = { [weak self] final in
            DebugLog.log("🎤 Real final transcript: '\(final)'", category: .speech)
            self?.handleFinalTranscript(final)
        }
        realSpeechRecognizer.onError = { [weak self] errorMessage in
            DebugLog.log("🎤 Speech recognition error: '\(errorMessage)'", category: .speech)
            self?.handleSpeechError(errorMessage)
        }

        speechRecognizer = realSpeechRecognizer

        DebugLog.log("🎤 Real voice engines setup complete", category: .speech)
    }

    func setupMockVoiceEngines() {
        DebugLog.log("🎤 Setting up MOCK voice engines (fallback)", category: .speech)

        wakeWordEngine = MockWakeWordEngine()
        wakeWordEngine?.onTriggered = { [weak self] in
            self?.handleWakeWordTriggered()
        }
        try? wakeWordEngine?.start()

        speechRecognizer = MockSpeechRecognizer()
        speechRecognizer?.onPartial = { [weak self] partial in
            self?.handlePartialTranscript(partial)
        }
        speechRecognizer?.onFinal = { [weak self] final in
            self?.handleFinalTranscript(final)
        }
    }

    func setupNLU() {
        intentRouter = IntentRouter()
    }

    // MARK: - Wake word lifecycle helpers

    func restartWakeWord(after delay: TimeInterval = 0.8) {
        DebugLog.log("⏰ Scheduling wake word restart in \(delay)s", category: .speech)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            DebugLog.log("🔄 Attempting to restart wake word engine...", category: .speech)
            do {
                try self.wakeWordEngine?.start()
                DebugLog.log("✅ Wake word engine restarted successfully", category: .speech)
            } catch {
                DebugLog.log("❌ Failed to restart wake word engine: \(error)", category: .speech)
            }
        }
    }

    // MARK: - Voice session handlers

    func handleWakeWordTriggered() {
        overlayController?.setState(.wake)
        wakeWordEngine?.stop()
        let sessionID = UUID()
        currentVoiceSessionID = sessionID
        activateGlobalSpaceCapture(promptIfNeeded: false)
        DebugLog.log("🔈 Wake word triggered new session: \(sessionID.uuidString.prefix(6))", category: .speech)
        speechRecognizer?.prepareForSession(id: sessionID)
        overlayController?.activateNotchTrace { [weak self] in
            guard let self else { return }
            self.overlayController?.beginSpeechCaptureSession(sessionID: sessionID)
            do {
                try self.speechRecognizer?.start()
            } catch {
                DebugLog.log("Failed to start recognizer: \(error)", category: .speech)
                self.handleSpeechError("Could not start speech recognition")
            }
        }
    }

    func handlePartialTranscript(_ partial: String) {
        DebugLog.log("Partial transcript received: \(partial)", category: .speech)
        overlayController?.updateSpeechCapture(partialTranscript: partial)
    }

    func handleSpeechError(_ errorMessage: String) {
        DebugLog.log("Voice session error: \(errorMessage)", category: .speech)
        releaseSpaceHoldIfNeeded()
        speechRecognizer?.stop()
        // showSpeechError now handles state reset to .idle so notch shrinks immediately
        overlayController?.showSpeechError(errorMessage)
        currentVoiceSessionID = nil
        restartWakeWord(after: 2.0)
    }

    func handleFinalTranscript(_ final: String) {
        releaseSpaceHoldIfNeeded()
        speechRecognizer?.stop()
        DebugLog.log("Final transcript: \(final)", category: .speech)
        let trimmed = final.trimmingCharacters(in: .whitespacesAndNewlines)
        if handlePendingClarificationIfNeeded(with: trimmed) { return }

        let context = RoutingContext()
        let effect = intentRouter?.handle(transcript: final, context: context)
        DebugLog.log("Intent routed: \(effect?.description ?? "none")", category: .intent)

        guard let effect else {
            overlayController?.finalizeSpeechCaptureForCommand(transcript: final, status: nil, completion: nil)
            return
        }

        switch effect {
        case .createTask(let title):
            overlayController?.finalizeSpeechCapture(with: final, resolvedTaskTitle: title)
        case .createAdvancedTask(let intent):
            // Handle advanced task creation with all attributes
            DebugLog.log("Creating advanced task: \(intent.title)", category: .intent)
            overlayController?.finalizeSpeechCaptureForAdvancedTask(intent: intent)
            // Provide voice feedback
            VoiceFeedback.shared.announceIntent(intent)
        case .showOverlay:
            overlayController?.finalizeSpeechCaptureForCommand(transcript: final, status: "Opening Notch…") { [weak self] in
                self?.overlayController?.revealOverlayForVoice()
            }
        case .createOrb(let name):
            overlayController?.finalizeSpeechCaptureForCommand(transcript: final, status: "Creating \(name)…") { [weak self] in
                self?.overlayController?.createNewProject(name: name)
            }
        case .clarifyTaskOrOrb(let title, _):
            pendingClarification = ClarificationPending(pendingTitle: title)
            overlayController?.showClarificationPrompt(for: title)
        default:
            overlayController?.finalizeSpeechCaptureForCommand(transcript: final, status: nil, completion: nil)
        }
        currentVoiceSessionID = nil
        restartWakeWord(after: 0.6)
    }


    func handlePendingClarificationIfNeeded(with transcript: String) -> Bool {
        guard let pending = pendingClarification else { return false }
        let normalized = stripWakeWord(transcript).lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if normalized.isEmpty {
            overlayController?.remindClarification(for: pending.pendingTitle)
            return true
        }
        if normalized.contains("cancel") {
            pendingClarification = nil
            overlayController?.dismissClarificationPrompt()
            return true
        }
        if normalized.contains("confirm task") || normalized == "task" {
            pendingClarification = nil
            overlayController?.dismissClarificationPrompt()
            overlayController?.finalizeSpeechCapture(with: pending.pendingTitle, resolvedTaskTitle: pending.pendingTitle)
            return true
        }
        if normalized.contains("confirm project") || normalized.contains("confirm orb") || normalized == "project" || normalized == "orb" {
            pendingClarification = nil
            overlayController?.dismissClarificationPrompt()
            overlayController?.finalizeSpeechCaptureForCommand(transcript: transcript, status: "Creating \(pending.pendingTitle)…") { [weak self] in
                self?.overlayController?.createNewProject(name: pending.pendingTitle)
            }
            return true
        }
        overlayController?.remindClarification(for: pending.pendingTitle)
        return true
    }

    func stripWakeWord(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let prefixes = ["hey notch", "ok notch", "okay notch", "notch"]
        for prefix in prefixes {
            if lower.hasPrefix(prefix) {
                let index = trimmed.index(trimmed.startIndex, offsetBy: prefix.count)
                trimmed = String(trimmed[index...])
                break
            }
        }
        return trimmed
    }
}
