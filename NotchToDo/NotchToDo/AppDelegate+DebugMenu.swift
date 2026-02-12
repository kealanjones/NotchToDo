import Cocoa
import _Concurrency

// MARK: - Debug Menu & Test Actions

extension AppDelegate {

    func rebuildDebugMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(makeMenuItem(title: "Show Walkthrough…", action: #selector(showOnboarding)))
        menu.addItem(makeMenuItem(title: "Keyboard Shortcuts…", action: #selector(showKeyboardShortcuts)))
        // Supabase status + controls
        let status = NSMenuItem(title: "Supabase: Idle", action: nil, keyEquivalent: "")
        status.isEnabled = false
        supabaseStatusMenuItem = status
        menu.addItem(status)
        menu.addItem(makeMenuItem(title: "Sync Now", action: #selector(syncNow)))
        let signInItem = makeMenuItem(title: "Supabase Sign In…", action: #selector(promptSupabaseSignIn))
        menu.addItem(signInItem)
        let signOutItem = makeMenuItem(title: "Supabase Sign Out", action: #selector(handleSupabaseSignOut))
        signOutItem.isEnabled = supabaseAuthManager?.currentSession != nil
        menu.addItem(signOutItem)
        menu.addItem(NSMenuItem.separator())
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
        menu.addItem(makeMenuItem(title: "Reset All Orbs", action: #selector(resetAllOrbs)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeMenuItem(title: "Kill App", action: #selector(killApp)))
    }

    func makeMenuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    func addLoggingSubmenu(to menu: NSMenu) {
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

        // Add separator and feature toggles
        menu.addItem(NSMenuItem.separator())

        let previewItem = NSMenuItem(title: "Show Compact Preview", action: #selector(toggleCompactPreview), keyEquivalent: "")
        previewItem.target = self
        previewItem.state = NotchCompactPreviewController.isEnabled ? .on : .off
        menu.addItem(previewItem)

        let animationsItem = NSMenuItem(title: "Contextual Notch Animations", action: #selector(toggleContextualAnimations), keyEquivalent: "")
        animationsItem.target = self
        animationsItem.state = NotchIndicatorView.contextualAnimationsEnabled ? .on : .off
        menu.addItem(animationsItem)

        // Add orb limit submenu
        let orbLimitItem = NSMenuItem(title: "Max Orbs Limit", action: nil, keyEquivalent: "")
        let orbLimitMenu = NSMenu()
        let currentLimit = UserDefaults.standard.integer(forKey: "maxOrbCount")
        let effectiveLimit = currentLimit > 0 ? currentLimit : 6

        for limit in [6, 8, 10, 12, 15, 20] {
            let item = NSMenuItem(title: "\(limit) orbs", action: #selector(setMaxOrbLimit(_:)), keyEquivalent: "")
            item.target = self
            item.tag = limit
            item.state = (limit == effectiveLimit) ? .on : .off
            orbLimitMenu.addItem(item)
        }
        orbLimitItem.submenu = orbLimitMenu
        menu.addItem(orbLimitItem)

        // Add text size submenu
        let textSizeItem = NSMenuItem(title: "Text Size", action: nil, keyEquivalent: "")
        let textSizeMenu = NSMenu()
        let currentSize = TextSizePreference.current

        let regularItem = NSMenuItem(title: "Regular", action: #selector(setTextSize(_:)), keyEquivalent: "")
        regularItem.target = self
        regularItem.tag = 0  // 0 = regular
        regularItem.state = (currentSize == .regular) ? .on : .off
        textSizeMenu.addItem(regularItem)

        let largeItem = NSMenuItem(title: "Large", action: #selector(setTextSize(_:)), keyEquivalent: "")
        largeItem.target = self
        largeItem.tag = 1  // 1 = large
        largeItem.state = (currentSize == .large) ? .on : .off
        textSizeMenu.addItem(largeItem)

        textSizeItem.submenu = textSizeMenu
        menu.addItem(textSizeItem)
    }

    func refreshLogMenuStates() {
        for (category, item) in logMenuItems {
            item.state = DebugLogger.shared.isEnabled(category) ? .on : .off
        }
    }

    @objc func toggleCompactPreview(_ sender: NSMenuItem) {
        NotchCompactPreviewController.isEnabled.toggle()
        sender.state = NotchCompactPreviewController.isEnabled ? .on : .off
        print("🔧 Compact preview \(NotchCompactPreviewController.isEnabled ? "enabled" : "disabled")")
    }

    @objc func toggleContextualAnimations(_ sender: NSMenuItem) {
        NotchIndicatorView.contextualAnimationsEnabled.toggle()
        sender.state = NotchIndicatorView.contextualAnimationsEnabled ? .on : .off
        print("🔧 Contextual notch animations \(NotchIndicatorView.contextualAnimationsEnabled ? "enabled" : "disabled")")
        // Refresh the notch display
        overlayController?.notchView?.needsDisplay = true
    }

    @objc func setMaxOrbLimit(_ sender: NSMenuItem) {
        let newLimit = sender.tag
        UserDefaults.standard.set(newLimit, forKey: "maxOrbCount")
        print("🔧 Max orb limit set to \(newLimit)")

        // Rebuild menu to update checkmarks
        rebuildDebugMenu(debugMenu)
    }

    @objc func setTextSize(_ sender: NSMenuItem) {
        let newSize: TextSizePreference.Size = sender.tag == 0 ? .regular : .large
        TextSizePreference.current = newSize
        print("🔧 Text size set to \(newSize.rawValue)")

        // Rebuild menu to update checkmarks
        rebuildDebugMenu(debugMenu)
    }
}

// MARK: - Keyboard Shortcut Actions

extension AppDelegate {
    func showQuickAddTaskPrompt() {
        let alert = NSAlert()
        alert.messageText = "Quick Add Task"
        alert.informativeText = "Enter the task title:"
        alert.alertStyle = .informational
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        inputField.placeholderString = "e.g. Buy groceries"
        alert.accessoryView = inputField
        alert.addButton(withTitle: "Add Task")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let title = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        overlayController?.addTask(title)
        AudioFeedback.shared.play(.success, volume: 0.5)
    }

    func showNewProjectPrompt() {
        let alert = NSAlert()
        alert.messageText = "New Project"
        alert.informativeText = "Enter the project name:"
        alert.alertStyle = .informational
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        inputField.placeholderString = "e.g. Marketing"
        alert.accessoryView = inputField
        alert.addButton(withTitle: "Create Project")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let name = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        overlayController?.createNewProject(name: name)
        AudioFeedback.shared.play(.success, volume: 0.5)
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

    @objc func syncNow() {
        supabaseSyncManager?.forceFullPullOnce()
        supabaseSyncManager?.requestImmediateSync(reason: "Manual debug menu (full pull)")
    }

    @objc func promptSupabaseSignIn() {
        guard let authManager = supabaseAuthManager else {
            let alert = NSAlert()
            alert.messageText = "Supabase Not Configured"
            alert.informativeText = "Provide Supabase credentials in Info.plist before attempting to sign in."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = "Supabase Sign In"
        alert.informativeText = "Enter your Supabase email and password."
        alert.alertStyle = .informational

        let emailField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        emailField.placeholderString = "name@example.com"
        let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))

        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 260, height: 56))
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(emailField)
        stack.addArrangedSubview(passwordField)
        emailField.widthAnchor.constraint(equalToConstant: 260).isActive = true
        passwordField.widthAnchor.constraint(equalToConstant: 260).isActive = true

        alert.accessoryView = stack
        alert.addButton(withTitle: "Sign In")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let email = emailField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordField.stringValue
        guard !email.isEmpty, !password.isEmpty else {
            let errorAlert = NSAlert()
            errorAlert.messageText = "Missing Credentials"
            errorAlert.informativeText = "Email and password are required."
            errorAlert.alertStyle = .warning
            errorAlert.runModal()
            return
        }

        _Concurrency.Task { [weak self] in
            do {
                try await authManager.signIn(email: email, password: password)
                await MainActor.run {
                    self?.showInfoAlert(title: "Signed In", message: "Supabase session established.")
                    if let menu = self?.debugMenu {
                        self?.rebuildDebugMenu(menu)
                    }
                    self?.supabaseSyncManager?.requestImmediateSync(reason: "Manual sign in")
                }
            } catch {
                await MainActor.run {
                    self?.showErrorAlert(title: "Sign In Failed", error: error)
                }
            }
        }
    }

    @objc func handleSupabaseSignOut() {
        guard let authManager = supabaseAuthManager else { return }

        DebugLog.log("🔒 Starting logout process...", category: .sync)

        // CRITICAL: Stop sync manager FIRST to prevent any ongoing operations
        supabaseSyncManager?.stop()

        // Clear auth session (tokens in Keychain)
        authManager.clearSession()

        // Clear access token from sync manager
        supabaseSyncManager?.updateAccessToken(nil)

        // Clear last pull timestamp to prevent stale data on next login
        UserDefaults.standard.removeObject(forKey: "SupabaseLastSuccessfulPullAt")

        // Clear all local data (Core Data + in-memory orbs + OUTBOX)
        overlayController?.clearLocalData()

        // Clear onboarding state so auth window shows on next launch
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(false, forKey: "hasSeenTutorial")

        rebuildDebugMenu(debugMenu)
        DebugLog.log("✅ Logout complete: cleared session, sync state, outbox, and all local data", category: .sync)
        showInfoAlert(title: "Signed Out", message: "All data cleared. Ready for next login.")

        // Show auth window immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showAuthWindow()
        }
    }

    @objc func toggleDebugCategory(_ sender: NSMenuItem) {
        guard let category = sender.representedObject as? DebugCategory else { return }
        let newState = sender.state != .on
        DebugLogger.shared.setCategory(category, enabled: newState)
        sender.state = newState ? .on : .off
        DebugLog.log("Logging category \(category.displayName) \(newState ? "enabled" : "disabled")", category: .app)
    }

    @objc func resetUIState() {
        pendingClarification = nil
        overlayController?.debugResetUIState()
        releaseSpaceHoldIfNeeded()
        speechRecognizer?.stop()
        DebugLog.log("UI state reset via debug menu", category: .app)
    }

    @objc func resetAllOrbs() {
        let alert = NSAlert()
        alert.messageText = "Reset All Orbs?"
        alert.informativeText = "This will permanently delete all orbs and their tasks. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset All Orbs")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            overlayController?.dataStore.clearAllData()
            DebugLog.log("All orbs cleared via debug menu", category: .app)
        }
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

// MARK: - Window Management

extension AppDelegate {
    @objc func showAuthWindow() {
        // Close existing auth window if present
        authWindowController?.close()

        // Create and show new auth window
        authWindowController = AuthWindowController()
        if let authVC = authWindowController?.window?.contentViewController as? AuthViewController {
            authVC.delegate = self
        }
        authWindowController?.showWindow(nil)
        authWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showOnboarding() {
        // Close existing onboarding window if present
        onboardingWindowController?.close()

        // Create and show new onboarding window
        onboardingWindowController = OnboardingWindowController()
        onboardingWindowController?.showWindow(nil)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showKeyboardShortcuts() {
        let shortcuts = """
        GLOBAL SHORTCUTS:

        ⌘N                Quick add task (text prompt)
        ⇧⌘N              New project/orb (text prompt)
        ⇧⌘O              Toggle semi-circle overlay
        ⌘1 - ⌘6          Switch to orb 1-6
        ⌘Z                Undo last action
        ⇧⌘Z              Redo last action
        Esc                Cancel voice capture / Hide overlay

        TASK DETAIL WINDOW:

        Space              Toggle task completion
        ⌘W                Close window
        Esc                Close window

        TASK CARD:

        ⌘F                Search/filter tasks
        ⌘E                Export tasks (Text/Markdown/JSON)
        Control+Click     Delete task (with undo)
        Two-finger click  Delete task (with undo)

        VOICE SHORTCUTS:

        Say "Hey Notch" or "Notch" to activate voice input
        """

        let alert = NSAlert()
        alert.messageText = "Keyboard Shortcuts"
        alert.informativeText = shortcuts
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func showInfoAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func showErrorAlert(title: String, error: Error) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = String(error.localizedDescription)
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Auth View Controller Delegate

extension AppDelegate {
    func authViewController(_ controller: AuthViewController, signInWithEmail email: String, password: String) async throws {
        guard let authManager = supabaseAuthManager else {
            throw NSError(domain: "NotchToDo", code: -1, userInfo: [NSLocalizedDescriptionKey: "Supabase not configured"])
        }
        try await authManager.signIn(email: email, password: password)
        if let session = authManager.currentSession {
            supabaseSyncManager?.updateAccessToken(session.accessToken)
            supabaseSyncManager?.requestImmediateSync(reason: "After sign in")
        }
    }

    func authViewController(_ controller: AuthViewController, signUpWithEmail email: String, password: String) async throws {
        guard let authManager = supabaseAuthManager else {
            throw NSError(domain: "NotchToDo", code: -1, userInfo: [NSLocalizedDescriptionKey: "Supabase not configured"])
        }
        try await authManager.signUp(email: email, password: password)
        if let session = authManager.currentSession {
            supabaseSyncManager?.updateAccessToken(session.accessToken)
            supabaseSyncManager?.requestImmediateSync(reason: "After sign up")
        }
    }

    func authViewControllerDidAuthenticate(_ controller: AuthViewController) {
        authWindowController?.close()
        authWindowController = nil

        // Load user's data after authentication
        overlayController?.loadUserData()

        // Mark onboarding as completed and show tutorial if needed
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        let hasSeenTutorial = UserDefaults.standard.bool(forKey: "hasSeenTutorial")
        if !hasSeenTutorial {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showOnboarding()
            }
        }
    }

    func authViewControllerDidSkip(_ controller: AuthViewController) {
        authWindowController?.close()
        authWindowController = nil

        // Load local data when skipping auth (offline mode)
        overlayController?.loadUserData()

        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === debugMenu else { return }
        refreshLogMenuStates()
    }
}
