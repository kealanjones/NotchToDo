import Cocoa
import SwiftUI
import AppKit

private struct ClarificationPending {
    let pendingTitle: String
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var overlayController: NotchOverlayController?
    private var wakeWordEngine: WakeWordEngine?
    private var speechRecognizer: SpeechRecognizer?
    private var intentRouter: IntentRouter?
    
    // Flag to switch between real and mock implementations
    private let useRealVoice = true // Set to false to use mock implementations
    private var pendingClarification: ClarificationPending?
    private var logMenuItems: [DebugCategory: NSMenuItem] = [:]
    private let persistenceController = PersistenceController.shared
    private lazy var debugMenu: NSMenu = {
        let menu = NSMenu()
        menu.delegate = self
        rebuildDebugMenu(menu)
        return menu
    }()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupOverlay()
        setupAudioEngines()
        setupNLU()
        setupTestShortcuts()
        setupDefaultPreferences()
    }
    
    private func setupDefaultPreferences() {
        // Set default preferences if not already set
        if !UserDefaults.standard.bool(forKey: "HasLaunchedBefore") {
            NotchCompactPreviewController.isEnabled = true
            AudioFeedback.shared.isEnabled = true
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
        }
    }
    
    private func setupTestShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 15 { // Cmd+Shift+T
                self.overlayController?.compactPreview.testPresent()
                return nil
            }
            return event
        }
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "NotchTo-Do")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    private func setupOverlay() {
        overlayController = NotchOverlayController(persistenceController: persistenceController)
    }
    
    private func setupAudioEngines() {
        if useRealVoice {
            setupRealVoiceEngines()
        } else {
            setupMockVoiceEngines()
        }
    }
    
    private func setupRealVoiceEngines() {
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
        
        speechRecognizer = realSpeechRecognizer
        
        DebugLog.log("🎤 Real voice engines setup complete", category: .speech)
    }
    
    private func setupMockVoiceEngines() {
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
    
    private func setupNLU() {
        intentRouter = IntentRouter()
    }

    // MARK: - Wake word lifecycle helpers
    private func restartWakeWord(after delay: TimeInterval = 0.6) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            do { try self.wakeWordEngine?.start() } catch {
                DebugLog.log("Failed to restart wake word engine: \(error)", category: .speech)
            }
        }
    }

    private func rebuildDebugMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(makeMenuItem(title: "Simulate Wake Word", action: #selector(simulateWakeWord)))
        menu.addItem(makeMenuItem(title: "Simulate Transcript", action: #selector(simulateTranscript)))
        let customItem = makeMenuItem(title: "Simulate Custom Transcript…", action: #selector(simulateCustomTranscriptPrompt))
        menu.addItem(customItem)
        let selfTestItem = makeMenuItem(title: "Run Intent Parser Self-Test", action: #selector(runIntentRouterSelfTest))
        menu.addItem(selfTestItem)
        menu.addItem(makeMenuItem(title: "Test Semi-Circle", action: #selector(testSemiCircle)))
        menu.addItem(makeMenuItem(title: "Hide Semi-Circle", action: #selector(hideSemiCircle)))
        menu.addItem(makeMenuItem(title: "Simulate New Project Request", action: #selector(simulateNewProjectRequest)))
        menu.addItem(NSMenuItem.separator())
        addLoggingSubmenu(to: menu)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeMenuItem(title: "Reset UI State", action: #selector(resetUIState)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeMenuItem(title: "Kill App", action: #selector(killApp)))
    }

    private func makeMenuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func addLoggingSubmenu(to menu: NSMenu) {
        let loggingItem = NSMenuItem(title: "Logging Categories", action: nil, keyEquivalent: "")
        let loggingMenu = NSMenu()
        logMenuItems.removeAll()
        let categories = DebugLogger.shared.allCategories().sorted { $0.displayName < $1.displayName }
        for category in categories {
            let item = NSMenuItem(title: category.displayName, action: #selector(toggleDebugCategory(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = category
            item.state = DebugLogger.shared.isEnabled(category) ? .on : .off
            loggingMenu.addItem(item)
            logMenuItems[category] = item
        }
        loggingItem.submenu = loggingMenu
        menu.addItem(loggingItem)
        
        // Add separator and compact preview toggle
        menu.addItem(NSMenuItem.separator())
        let previewItem = NSMenuItem(title: "Show Compact Preview", action: #selector(toggleCompactPreview), keyEquivalent: "")
        previewItem.target = self
        previewItem.state = NotchCompactPreviewController.isEnabled ? .on : .off
        menu.addItem(previewItem)
    }

    private func refreshLogMenuStates() {
        for (category, item) in logMenuItems {
            item.state = DebugLogger.shared.isEnabled(category) ? .on : .off
        }
    }
    
    @objc private func toggleCompactPreview(_ sender: NSMenuItem) {
        NotchCompactPreviewController.isEnabled.toggle()
        sender.state = NotchCompactPreviewController.isEnabled ? .on : .off
        print("🔧 Compact preview \(NotchCompactPreviewController.isEnabled ? "enabled" : "disabled")")
    }
    
    
    @objc private func statusBarButtonClicked() {
        guard let event = NSApp.currentEvent else {
            overlayController?.toggleOverlay()
            return
        }
        
        let isRightClick = event.type == .rightMouseUp
        let isControlClick = event.modifierFlags.contains(.control) && event.type == .leftMouseUp
        
        if isRightClick || isControlClick {
            if let statusItem {
                statusItem.popUpMenu(debugMenu)
            }
            return
        }
        
        overlayController?.toggleOverlay()
    }
    
    private func handleWakeWordTriggered() {
        // Trigger notch trace activation first
        overlayController?.setState(.wake)
        // Stop wake word listening to free the audio input for dictation
        wakeWordEngine?.stop()
        overlayController?.activateNotchTrace { [weak self] in
            guard let self else { return }
            self.overlayController?.beginSpeechCaptureSession()
            try? self.speechRecognizer?.start()
        }
    }
    
    private func handlePartialTranscript(_ partial: String) {
        overlayController?.updateSpeechCapture(partialTranscript: partial)
    }
    
    private func handleFinalTranscript(_ final: String) {
        speechRecognizer?.stop()
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
        case .createTask(let title, _):
            overlayController?.finalizeSpeechCapture(with: final, resolvedTaskTitle: title)
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
        restartWakeWord(after: 0.6)
    }
    

    private func handlePendingClarificationIfNeeded(with transcript: String) -> Bool {
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

    private func stripWakeWord(_ text: String) -> String {
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

    func applicationWillTerminate(_ notification: Notification) {
        wakeWordEngine?.stop()
        speechRecognizer?.stop()
    }
}

// MARK: - Test Menu Actions
extension AppDelegate {
    @objc func simulateWakeWord() {
        handleWakeWordTriggered()
    }
    
    @objc func simulateTranscript() {
        handleFinalTranscript("add buy milk")
    }

    @objc private func toggleDebugCategory(_ sender: NSMenuItem) {
        guard let category = sender.representedObject as? DebugCategory else { return }
        let newState = sender.state != .on
        DebugLogger.shared.setCategory(category, enabled: newState)
        sender.state = newState ? .on : .off
        DebugLog.log("Logging category \(category.displayName) \(newState ? "enabled" : "disabled")", category: .app)
    }

    @objc private func resetUIState() {
        pendingClarification = nil
        overlayController?.debugResetUIState()
        speechRecognizer?.stop()
        DebugLog.log("UI state reset via debug menu", category: .app)
    }
    
    @objc func simulateCustomTranscriptPrompt() {
        let alert = NSAlert()
        alert.messageText = "Simulate Transcript"
        alert.informativeText = "Enter the phrase you want Notch to process."
        alert.alertStyle = .informational
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        inputField.placeholderString = "e.g. Notch, open"
        inputField.stringValue = "Notch, "
        alert.accessoryView = inputField
        alert.addButton(withTitle: "Send")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        
        let phrase = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else { return }
        handleFinalTranscript(phrase)
    }
    
    @objc func testSemiCircle() {
        overlayController?.testSemiCircle()
    }
    
    @objc func hideSemiCircle() {
        overlayController?.hideSemiCircle()
    }
    
    @objc func simulateNewProjectRequest() {
        // Check if semi-circle is already visible
        if overlayController?.isSemiCircleVisible == true {
            // Semi-circle is already visible, just add a new project
            overlayController?.createNewProject(name: "New Project \(Int.random(in: 1...100))")
        } else {
            // Semi-circle not visible, do full sequence: wake word -> semi-circle -> new project
            handleWakeWordTriggered()
            
            // After a short delay, simulate creating a new project
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.overlayController?.createNewProject(name: "New Project \(Int.random(in: 1...100))")
            }
        }
    }
    
    @objc func killApp() {
        print("💀 Killing app...")
        NSApplication.shared.terminate(nil)
    }

    @objc func runIntentRouterSelfTest() {
        let results = IntentRouter.runSelfTest()
        let message = results.joined(separator: "\n")
        DebugLog.log("Intent Router Self-Test:\n\(message)", category: .intent)
        let alert = NSAlert()
        alert.messageText = "Intent Parser Self-Test"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === debugMenu else { return }
        refreshLogMenuStates()
    }
}
