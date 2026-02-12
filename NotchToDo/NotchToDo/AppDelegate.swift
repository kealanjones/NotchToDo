import Cocoa
import SwiftUI
import AppKit
import ApplicationServices
import _Concurrency

struct ClarificationPending {
    let pendingTitle: String
}

class AppDelegate: NSObject, NSApplicationDelegate, AuthViewControllerDelegate {
    private var statusItem: NSStatusItem?
    var overlayController: NotchOverlayController?
    var wakeWordEngine: WakeWordEngine?
    var speechRecognizer: SpeechRecognizer?
    var intentRouter: IntentRouter?
    var onboardingWindowController: OnboardingWindowController?
    var authWindowController: AuthWindowController?

    var currentVoiceSessionID: UUID?
    var isSpaceHoldActive = false
    var didHandleSpaceHoldForCurrentPress = false
    private var spaceKeyEventTap: CFMachPort?
    private var spaceKeyEventTapSource: CFRunLoopSource?
    var shouldCaptureSpaceGlobally = false
    private var supabaseService: SupabaseService?
    var supabaseSyncManager: SupabaseSyncManager?
    var supabaseAuthManager: SupabaseAuthManager?
    var supabaseStatusMenuItem: NSMenuItem?
    private var hasPromptedForAccessibilityPermission = false
    private var hasShownAccessibilityWarning = false

    // Flag to switch between real and mock implementations
    private let useRealVoice = true // Set to false to use mock implementations
    var pendingClarification: ClarificationPending?
    var logMenuItems: [DebugCategory: NSMenuItem] = [:]
    let persistenceController = PersistenceController.shared
    lazy var debugMenu: NSMenu = {
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
        setupURLHandling()
        setupSupabaseSync()
        checkAndShowOnboarding()
    }

    private func checkAndShowOnboarding() {
        // Check if we're using a developer token (skip auth flow for development)
        let hasDevToken = SupabaseEnvironment.developerAccessToken() != nil

        // Check if user is authenticated
        let isAuthenticated = supabaseAuthManager?.currentSession != nil
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        if !isAuthenticated && !hasDevToken && !hasCompletedOnboarding {
            // Show auth window on first launch if not authenticated and not using dev token
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showAuthWindow()
            }
        } else if isAuthenticated && !hasCompletedOnboarding {
            // User authenticated but hasn't completed onboarding - load data and show tutorial
            overlayController?.loadUserData()
            let hasSeenTutorial = UserDefaults.standard.bool(forKey: "hasSeenTutorial")
            if !hasSeenTutorial {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.showOnboarding()
                }
            }
        } else if hasCompletedOnboarding && isAuthenticated {
            // User has completed onboarding and is authenticated - load their data
            overlayController?.loadUserData()
        } else if hasCompletedOnboarding && !isAuthenticated && !hasDevToken {
            // User completed onboarding but is not authenticated - show auth window
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showAuthWindow()
            }
        }
    }

    private func setupDefaultPreferences() {
        // Set default preferences if not already set
        if !UserDefaults.standard.bool(forKey: "HasLaunchedBefore") {
            NotchCompactPreviewController.isEnabled = true
            NotchIndicatorView.contextualAnimationsEnabled = true
            AudioFeedback.shared.isEnabled = true
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
        }
    }

    private func setupSupabaseSync() {
        guard let configuration = SupabaseEnvironment.configuration() else {
            DebugLog.log("Supabase sync disabled: missing configuration", category: .sync)
            return
        }

        let service = SupabaseService(configuration: configuration)
        let syncManager = SupabaseSyncManager(service: service)
        let authManager = SupabaseAuthManager(service: service)
        syncManager.authManager = authManager

        let devToken = SupabaseEnvironment.developerAccessToken()
        if let devToken = devToken {
            authManager.bootstrapWithDeveloperToken(devToken)
        }

        if let session = authManager.currentSession {
            syncManager.updateAccessToken(session.accessToken)
        }

        NotificationCenter.default.addObserver(
            forName: .supabaseAuthSessionChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let session = notification.object as? SupabaseAuthManager.Session
            self?.supabaseSyncManager?.updateAccessToken(session?.accessToken)
            if session != nil {
                // User authenticated - load their data and resume sync
                self?.overlayController?.loadUserData()
                // CRITICAL FIX: Resume sync manager to activate polling and force initial pull
                self?.supabaseSyncManager?.resume()
            } else {
                // Session cleared - stop sync and clear local data
                self?.supabaseSyncManager?.stop()
                self?.overlayController?.clearLocalData()
            }
        }
        syncManager.stateChangeHandler = { [weak self] state in
            switch state {
            case .idle:
                DebugLog.log("Supabase sync idle", category: .sync)
            case .syncing:
                DebugLog.log("Supabase sync running", category: .sync)
            case .paused:
                DebugLog.log("Supabase sync paused", category: .sync)
            case .error(let message):
                DebugLog.log("Supabase sync error: \(message)", category: .sync)
            }
            DispatchQueue.main.async {
                guard let item = self?.supabaseStatusMenuItem else { return }
                let title: String
                switch state {
                case .idle: title = "Supabase: Idle"
                case .syncing: title = "Supabase: Syncing…"
                case .paused: title = "Supabase: Paused"
                case .error: title = "Supabase: Error"
                }
                item.title = title
            }
        }

        // Wire ChangeTracker from DataStore into sync manager
        syncManager.changeTracker = overlayController?.dataStore.changeTracker

        supabaseService = service
        supabaseSyncManager = syncManager
        supabaseAuthManager = authManager

        // Only start syncing if user is authenticated
        if authManager.currentSession != nil || devToken != nil {
            syncManager.scheduleInitialSync()
            syncManager.requestImmediateSync(reason: "App bootstrap")
        } else {
            DebugLog.log("Skipping initial sync: no authenticated session", category: .sync)
        }

        // Listen for pull completion to refresh UI
        NotificationCenter.default.addObserver(
            forName: .supabaseDataDidPull,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.overlayController?.reloadFromPersistence()
            // Invalidate any open task card windows to force redraw with latest data
            if let windows = self?.overlayController?.taskCardWindows.values {
                for window in windows {
                    window.contentView?.needsDisplay = true
                }
            }
        }
    }

    private func setupURLHandling() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleIncomingURL(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleIncomingURL(_ event: NSAppleEventDescriptor, withReply _: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            DebugLog.log("Received malformed URL event", category: .app)
            return
        }

        if supabaseAuthManager?.handleOAuthRedirect(url: url) == true {
            DebugLog.log("Processed Supabase OAuth callback successfully", category: .sync)

            // Close auth window since OAuth succeeded
            DispatchQueue.main.async { [weak self] in
                self?.authWindowController?.close()
                self?.authWindowController = nil

                // Load user data and complete onboarding
                self?.overlayController?.loadUserData()
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

                // Show tutorial if needed
                let hasSeenTutorial = UserDefaults.standard.bool(forKey: "hasSeenTutorial")
                if !hasSeenTutorial {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.showOnboarding()
                    }
                }
            }

            supabaseSyncManager?.requestImmediateSync(reason: "OAuth redirect callback")
        }
    }

    private func setupTestShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if self.handleSpaceHoldKeyDown(event) {
                return nil
            }

            // Cmd+Shift+T - Test compact preview
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 15 {
                self.overlayController?.compactPreview.testPresent()
                return nil
            }

            // Cmd+N - Quick add task
            if event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.shift) && event.keyCode == 45 {
                self.showQuickAddTaskPrompt()
                return nil
            }

            // Cmd+Shift+N - New orb/project
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 45 {
                self.showNewProjectPrompt()
                return nil
            }

            // Cmd+Shift+O - Toggle overlay
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 31 {
                self.overlayController?.toggleOverlay()
                return nil
            }

            // Cmd+1 through Cmd+6 - Switch to orb by index
            if event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.shift) {
                let numberKeyCodes: [UInt16: Int] = [18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6]
                if let orbIndex = numberKeyCodes[event.keyCode] {
                    self.overlayController?.switchToOrb(at: orbIndex - 1)
                    return nil
                }
            }

            // Esc - Cancel voice capture or hide semi-circle
            if event.keyCode == 53 { // Escape key
                if self.overlayController?.isSpeechCaptureActive() == true {
                    self.releaseSpaceHoldIfNeeded()
                    self.overlayController?.cancelSpeechCapture()
                    self.speechRecognizer?.stop()
                    self.currentVoiceSessionID = nil
                    self.restartWakeWord(after: 0.6)
                } else if self.overlayController?.isSemiCircleVisible == true {
                    self.overlayController?.hideSemiCircle()
                }
                return nil
            }

            // Cmd+Z - Undo
            if event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.shift) && event.keyCode == 6 {
                self.overlayController?.performUndo()
                return nil
            }

            // Cmd+Shift+Z - Redo
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 6 {
                self.overlayController?.performRedo()
                return nil
            }

            return event
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
            if self.handleSpaceHoldKeyUp(event) {
                return nil
            }
            return event
        }
    }

    private func handleSpaceHoldKeyDown(_ event: NSEvent) -> Bool {
        handleSpaceHoldKeyDown(
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        )
    }

    private func handleSpaceHoldKeyDown(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> Bool {
        guard keyCode == 49 else { return false }
        let flags = modifierFlags
        if flags.contains(.command) || flags.contains(.option) || flags.contains(.control) {
            return false
        }

        let sessionActive = currentVoiceSessionID != nil
        guard sessionActive else { return false }

        if !shouldCaptureSpaceGlobally {
            activateGlobalSpaceCapture()
        }

        let bubbleActive = overlayController?.isSpeechCaptureActive() == true

        if didHandleSpaceHoldForCurrentPress {
            if !isSpaceHoldActive {
                isSpaceHoldActive = true
                speechRecognizer?.beginExternalSilenceHold()
                if bubbleActive {
                    overlayController?.setExternalSilenceHoldActive(true)
                }
            }
            return true
        }

        didHandleSpaceHoldForCurrentPress = true

        if !isSpaceHoldActive {
            isSpaceHoldActive = true
            speechRecognizer?.beginExternalSilenceHold()
            if bubbleActive {
                overlayController?.setExternalSilenceHoldActive(true)
            }
        }
        return true
    }

    private func handleSpaceHoldKeyUp(_ event: NSEvent) -> Bool {
        handleSpaceHoldKeyUp(
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        )
    }

    private func handleSpaceHoldKeyUp(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> Bool {
        guard keyCode == 49 else { return false }
        let flags = modifierFlags
        if flags.contains(.command) || flags.contains(.option) || flags.contains(.control) {
            return false
        }
        guard didHandleSpaceHoldForCurrentPress else { return false }

        if isSpaceHoldActive {
            isSpaceHoldActive = false
            speechRecognizer?.endExternalSilenceHold()
            overlayController?.setExternalSilenceHoldActive(false)
        }
        didHandleSpaceHoldForCurrentPress = false
        return true
    }

    func releaseSpaceHoldIfNeeded() {
        if isSpaceHoldActive {
            isSpaceHoldActive = false
            speechRecognizer?.endExternalSilenceHold()
            overlayController?.setExternalSilenceHoldActive(false)
        }
    }

    func activateGlobalSpaceCapture(promptIfNeeded: Bool = true) {
        if !shouldCaptureSpaceGlobally {
            if !promptIfNeeded && !AXIsProcessTrusted() {
                return
            }

            guard ensureAccessibilityPermission(promptIfNeeded: promptIfNeeded) else {
                DebugLog.log("⚠️ Accessibility permission not granted; space hold cannot block other apps", category: .app)
                return
            }

            shouldCaptureSpaceGlobally = true
        }

        ensureSpaceKeyEventTapActive()
    }

    func deactivateGlobalSpaceCapture() {
        releaseSpaceHoldIfNeeded()
        didHandleSpaceHoldForCurrentPress = false
    }

    private func ensureAccessibilityPermission(promptIfNeeded: Bool) -> Bool {
        if AXIsProcessTrusted() {
            return true
        }
        if promptIfNeeded && !hasPromptedForAccessibilityPermission {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            hasPromptedForAccessibilityPermission = true
        }
        if AXIsProcessTrusted() {
            return true
        }
        if !promptIfNeeded && !hasShownAccessibilityWarning {
            hasShownAccessibilityWarning = true
            DispatchQueue.main.async {
                self.presentAccessibilityWarning()
            }
        }
        return false
    }

    private func presentAccessibilityWarning() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Enable Accessibility Access"
        alert.informativeText = "To keep recordings active while the space bar is held, please allow NotchToDo under System Settings → Privacy & Security → Accessibility."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private static let spaceKeyEventTapCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }
        let delegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()
        return delegate.handleSpaceKeyEventTap(proxy: proxy, type: type, event: event)
    }

    private func ensureSpaceKeyEventTapActive() {
        if spaceKeyEventTap == nil {
            let keyDownMask = CGEventMask(1 << Int(CGEventType.keyDown.rawValue))
            let keyUpMask = CGEventMask(1 << Int(CGEventType.keyUp.rawValue))
            let eventMask = keyDownMask | keyUpMask
            guard let tap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: AppDelegate.spaceKeyEventTapCallback,
                userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            ) else {
                DebugLog.log("❌ Failed to install global space key event tap", category: .app)
                shouldCaptureSpaceGlobally = false
                return
            }
            spaceKeyEventTap = tap
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            spaceKeyEventTapSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }

        if let tap = spaceKeyEventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        if spaceKeyEventTap == nil {
            shouldCaptureSpaceGlobally = false
            ensureAccessibilityPermission(promptIfNeeded: false)
        }
    }

    private func teardownSpaceKeyEventTap() {
        if let tap = spaceKeyEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = spaceKeyEventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        spaceKeyEventTapSource = nil
        spaceKeyEventTap = nil
        shouldCaptureSpaceGlobally = false
    }

    private func handleSpaceKeyEventTap(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = spaceKeyEventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard shouldCaptureSpaceGlobally else {
            return Unmanaged.passUnretained(event)
        }

        let sessionActive = currentVoiceSessionID != nil || (overlayController?.isSpeechCaptureActive() ?? false)
        let shouldProcessEvent = sessionActive || didHandleSpaceHoldForCurrentPress || isSpaceHoldActive
        if !shouldProcessEvent {
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passUnretained(event)
        }

        let handled: Bool
        if let nsEvent = NSEvent(cgEvent: event) {
            switch type {
            case .keyDown:
                handled = handleSpaceHoldKeyDown(nsEvent)
            case .keyUp:
                handled = handleSpaceHoldKeyUp(nsEvent)
            default:
                handled = false
            }
        } else {
            let keyCodeValue = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flagsRaw = UInt(event.flags.rawValue)
            let modifierFlags = NSEvent.ModifierFlags(rawValue: flagsRaw).intersection(.deviceIndependentFlagsMask)
            switch type {
            case .keyDown:
                handled = handleSpaceHoldKeyDown(keyCode: keyCodeValue, modifierFlags: modifierFlags)
            case .keyUp:
                handled = handleSpaceHoldKeyUp(keyCode: keyCodeValue, modifierFlags: modifierFlags)
            default:
                handled = false
            }
        }

        return handled ? nil : Unmanaged.passUnretained(event)
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            // Try to load custom icon from assets, fallback to system symbol
            if let customIcon = NSImage(named: "StatusBarIcon") {
                print("✅ Custom StatusBarIcon loaded successfully!")
                print("   Icon size: \(customIcon.size)")
                button.image = customIcon
                button.image?.size = NSSize(width: 18, height: 18)
                button.image?.isTemplate = false  // Keep original colors
            } else {
                print("❌ StatusBarIcon not found in assets, using fallback")
                // Fallback to system symbol if custom icon not found
                button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "NotchTo-Do")
            }
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func setupOverlay() {
        overlayController = NotchOverlayController(persistenceController: persistenceController)
        overlayController?.speechFailureHandler = { [weak self] message in
            guard let self else { return }
            DebugLog.log("Voice session failure surfaced: \(message)", category: .speech)
            self.handleSpeechError(message)
        }
        overlayController?.speechCaptureVisibilityHandler = { [weak self] isVisible in
            guard let self else { return }
            if isVisible {
                let shouldPrompt = !AXIsProcessTrusted()
                self.activateGlobalSpaceCapture(promptIfNeeded: shouldPrompt)
            } else {
                self.deactivateGlobalSpaceCapture()
                if self.currentVoiceSessionID == nil {
                    self.restartWakeWord(after: 0.6)
                }
            }
        }
    }

    private func setupAudioEngines() {
        if useRealVoice {
            setupRealVoiceEngines()
        } else {
            setupMockVoiceEngines()
        }
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

    func applicationWillTerminate(_ notification: Notification) {
        wakeWordEngine?.stop()
        releaseSpaceHoldIfNeeded()
        deactivateGlobalSpaceCapture()
        speechRecognizer?.stop()
        teardownSpaceKeyEventTap()
    }
}
