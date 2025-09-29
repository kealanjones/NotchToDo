import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var overlayController: NotchOverlayController?
    private var wakeWordEngine: MockWakeWordEngine?
    private var speechRecognizer: MockSpeechRecognizer?
    private var intentRouter: IntentRouter?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupOverlay()
        setupAudioEngines()
        setupNLU()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "NotchTo-Do")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            
            // Add test menu
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Simulate Wake Word", action: #selector(simulateWakeWord), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Simulate Transcript", action: #selector(simulateTranscript), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Test Semi-Circle", action: #selector(testSemiCircle), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Hide Semi-Circle", action: #selector(hideSemiCircle), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Simulate New Project Request", action: #selector(simulateNewProjectRequest), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Kill App", action: #selector(killApp), keyEquivalent: ""))
            statusItem?.menu = menu
        }
    }
    
    private func setupOverlay() {
        overlayController = NotchOverlayController()
    }
    
    private func setupAudioEngines() {
        wakeWordEngine = MockWakeWordEngine()
        wakeWordEngine?.onTriggered = { [weak self] in
            self?.handleWakeWordTriggered()
        }
        
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
    
    
    @objc private func statusBarButtonClicked() {
        overlayController?.toggleOverlay()
    }
    
    private func handleWakeWordTriggered() {
        // Trigger notch trace activation first
        overlayController?.activateNotchTrace()
        
        // Then set listening state
        overlayController?.setState(.listening)
        try? speechRecognizer?.start()
    }
    
    private func handlePartialTranscript(_ partial: String) {
        overlayController?.setState(.transcribing)
    }
    
    private func handleFinalTranscript(_ final: String) {
        overlayController?.setState(.idle)
        speechRecognizer?.stop()
        
        let context = RoutingContext()
        let effect = intentRouter?.handle(transcript: final, context: context)
        print("Intent routed: \(effect?.description ?? "none")")
        
        // Add task to overlay if it's a create task action
        if case .createTask(let title, _) = effect {
            overlayController?.addTask(title)
        }
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
}
