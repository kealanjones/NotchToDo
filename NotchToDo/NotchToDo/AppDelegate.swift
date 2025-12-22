import Cocoa
import SwiftUI
import AppKit
import ApplicationServices
import _Concurrency

// MARK: - Onboarding Step Model

private struct OnboardingStep {
    let title: String
    let description: String
    let imageName: String? // Optional system image name
    let tips: [String]
    let category: StepCategory

    enum StepCategory {
        case welcome
        case basics
        case voice
        case keyboard
        case advanced
        case settings
    }
}

// MARK: - Onboarding Window Controller

private class OnboardingWindowController: NSWindowController {
    private var onboardingViewController: OnboardingViewController?

    convenience init() {
        let contentRect = NSRect(x: 0, y: 0, width: 800, height: 600)
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .fullSizeContentView]
        let window = NSWindow(contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false)

        window.title = "Welcome to NotchToDo"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.level = .floating

        self.init(window: window)

        let viewController = OnboardingViewController()
        self.onboardingViewController = viewController
        window.contentViewController = viewController
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        window?.backgroundColor = NSColor(calibratedWhite: 0.95, alpha: 1.0)
    }
}

// MARK: - Onboarding View Controller

private class OnboardingViewController: NSViewController {
    private var currentStepIndex = 0
    private let steps: [OnboardingStep] = [
        OnboardingStep(
            title: "Welcome to NotchToDo!",
            description: "NotchToDo is a voice-first task manager that lives in your Mac's notch. Organize projects, add tasks with your voice, and stay productive without lifting a finger.",
            imageName: nil,
            tips: [
                "💡 NotchToDo uses your Mac's notch as a visual hub",
                "🎤 Voice commands make task management effortless",
                "⚡ Keyboard shortcuts for power users",
                "🎨 Beautiful, physics-based animations"
            ],
            category: .welcome
        ),
        OnboardingStep(
            title: "Creating Your First Orb (Project)",
            description: "Orbs are colorful floating bubbles that represent your projects. Each orb can contain unlimited tasks.",
            imageName: nil,
            tips: [
                "🗣️ Say \"Hey Notch, create project Work\" - Voice command",
                "⌨️ Press ⇧⌘N and type project name - Keyboard shortcut",
                "🎨 Each orb gets a unique color automatically",
                "📊 Orbs show task count in real-time",
                "⚙️ Configure max orbs (6-20) in settings"
            ],
            category: .basics
        ),
        OnboardingStep(
            title: "Adding Tasks",
            description: "Add tasks to your projects using voice or keyboard. Tasks can have titles, details, and due dates.",
            imageName: nil,
            tips: [
                "🗣️ Click an orb, say \"add buy groceries\" - Quick voice add",
                "🗣️ Say \"add buy milk to Shopping\" - Add to specific project",
                "⌨️ Press ⌘N - Opens quick add dialog",
                "⌨️ Click orb number (⌘1-⌘6) - Switch projects",
                "✏️ Click task to edit details, deadlines, and notes"
            ],
            category: .basics
        ),
        OnboardingStep(
            title: "Voice Commands & Wake Word",
            description: "NotchToDo listens for \"Hey Notch\" or \"Notch\" to activate voice input. No need to click anything!",
            imageName: nil,
            tips: [
                "🎤 \"Hey Notch\" or \"Notch\" - Wake word to activate",
                "➕ \"add [task]\" - Create new task",
                "➕ \"add [task] to [project]\" - Add to specific project",
                "✅ \"complete [task]\" - Mark task as done",
                "🗑️ \"delete [task]\" - Remove a task",
                "📋 \"create project [name]\" - New project/orb",
                "🔇 Voice requires microphone & speech recognition permissions"
            ],
            category: .voice
        ),
        OnboardingStep(
            title: "Keyboard Shortcuts - Power User Mode",
            description: "Master these shortcuts to fly through your tasks. All shortcuts are designed for one-handed use.",
            imageName: nil,
            tips: [
                "⌘N - Quick add task",
                "⇧⌘N - New project/orb",
                "⇧⌘O - Toggle semi-circle overlay",
                "⌘1-⌘6 - Switch to orb 1-6",
                "⌘F - Search/filter tasks (in card)",
                "⌘E - Export tasks (Text/Markdown/JSON)",
                "⌘Z - Undo last action",
                "⇧⌘Z - Redo",
                "Esc - Cancel/close/hide"
            ],
            category: .keyboard
        ),
        OnboardingStep(
            title: "Managing Tasks",
            description: "Complete, edit, delete, and reorder tasks with ease. Everything is designed to be intuitive.",
            imageName: nil,
            tips: [
                "✅ Click checkbox - Mark task complete/incomplete",
                "✏️ Click task - Edit details in floating panel",
                "🗑️ Control+Click or Two-finger click - Delete with undo",
                "↕️ Drag task handle - Reorder tasks",
                "Space - Toggle completion (in detail view)",
                "⌘W - Close detail panel",
                "⌘Z - Undo deletions"
            ],
            category: .basics
        ),
        OnboardingStep(
            title: "Search & Export",
            description: "Find tasks quickly and export your data for backup or sharing.",
            imageName: nil,
            tips: [
                "🔍 Press ⌘F - Activate search in task card",
                "⌨️ Type to filter - Searches titles and details",
                "Esc - Clear search",
                "📤 Press ⌘E - Export current project",
                "📄 Export as Text - Simple numbered checklist",
                "📝 Export as Markdown - GitHub-compatible",
                "💾 Export as JSON - Full data with timestamps"
            ],
            category: .advanced
        ),
        OnboardingStep(
            title: "Customization & Settings",
            description: "Personalize NotchToDo to match your workflow. Access settings from the menu bar icon.",
            imageName: nil,
            tips: [
                "🎨 Orbs get automatic colors (unique per project)",
                "📊 Max Orbs Limit - Set 6, 8, 10, 12, 15, or 20 orbs",
                "🔔 Contextual Animations - Notch glows with project color",
                "📱 Compact Preview - Mini task preview mode",
                "📋 Logging - Debug categories for troubleshooting",
                "⚙️ Right-click menu bar icon for all settings"
            ],
            category: .settings
        ),
        OnboardingStep(
            title: "Pro Tips & Tricks",
            description: "Advanced techniques to supercharge your productivity with NotchToDo.",
            imageName: nil,
            tips: [
                "📌 Pin task cards - Keep important projects visible",
                "🎯 Drag & drop files - Attach files to tasks",
                "⚡ Physics animations - Orbs magnetically attract to notch",
                "🎨 Visual feedback - Cards pulse when tasks complete",
                "🔄 Undo everything - All deletions can be undone",
                "⌨️ Card focus - Click search box, then type immediately",
                "🎤 Natural language - \"add task\" works like \"add a task\"",
                "💡 Empty states - Helpful guides when lists are empty"
            ],
            category: .advanced
        ),
        OnboardingStep(
            title: "You're All Set!",
            description: "Ready to get started? Try creating your first orb and adding a task. You can re-open this guide anytime from Help → Show Walkthrough.",
            imageName: nil,
            tips: [
                "🎉 You've completed the walkthrough!",
                "🚀 Start by creating an orb with ⇧⌘N",
                "💬 Try the wake word: \"Hey Notch, add my first task\"",
                "📚 Access this guide anytime from the menu",
                "❓ Check Keyboard Shortcuts (in menu) for reference",
                "💡 Hover over orbs to see project names"
            ],
            category: .welcome
        )
    ]

    // UI Elements
    private let contentView = NSView()
    private let headerView = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let stepIndicatorLabel = NSTextField(labelWithString: "")
    private let descriptionLabel = NSTextField(wrappingLabelWithString: "")
    private let tipsContainer = NSView()
    private let previousButton = NSButton(title: "Previous", target: nil, action: #selector(previousStep))
    private let nextButton = NSButton(title: "Next", target: nil, action: #selector(nextStep))
    private let skipButton = NSButton(title: "Skip", target: nil, action: #selector(closeOnboarding))
    private let getStartedButton = NSButton(title: "Get Started!", target: nil, action: #selector(closeOnboarding))

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateStepContent()
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(calibratedWhite: 0.95, alpha: 1.0).cgColor

        // Header
        headerView.frame = NSRect(x: 0, y: view.bounds.height - 120, width: view.bounds.width, height: 120)
        headerView.wantsLayer = true
        view.addSubview(headerView)

        // Title
        titleLabel.font = NSFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = NSColor(calibratedWhite: 0.15, alpha: 1.0)
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 40, y: 50, width: view.bounds.width - 80, height: 40)
        headerView.addSubview(titleLabel)

        // Step indicator
        stepIndicatorLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        stepIndicatorLabel.textColor = NSColor(calibratedWhite: 0.4, alpha: 1.0)
        stepIndicatorLabel.alignment = .center
        stepIndicatorLabel.frame = NSRect(x: 40, y: 25, width: view.bounds.width - 80, height: 20)
        headerView.addSubview(stepIndicatorLabel)

        // Content area
        contentView.frame = NSRect(x: 40, y: 100, width: view.bounds.width - 80, height: view.bounds.height - 260)
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.white.cgColor
        contentView.layer?.cornerRadius = 16
        view.addSubview(contentView)

        // Description
        descriptionLabel.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        descriptionLabel.textColor = NSColor(calibratedWhite: 0.25, alpha: 1.0)
        descriptionLabel.alignment = .center
        descriptionLabel.maximumNumberOfLines = 3
        descriptionLabel.frame = NSRect(x: 60, y: contentView.bounds.height - 80, width: contentView.bounds.width - 120, height: 60)
        contentView.addSubview(descriptionLabel)

        // Tips container
        tipsContainer.frame = NSRect(x: 40, y: 0, width: contentView.bounds.width - 80, height: contentView.bounds.height - 100)
        contentView.addSubview(tipsContainer)

        // Navigation buttons
        let buttonWidth: CGFloat = 120
        let buttonHeight: CGFloat = 36
        let buttonY: CGFloat = 40

        previousButton.frame = NSRect(x: 60, y: buttonY, width: buttonWidth, height: buttonHeight)
        previousButton.target = self
        previousButton.bezelStyle = .rounded
        previousButton.contentTintColor = NSColor.white.withAlphaComponent(0.8)
        view.addSubview(previousButton)

        skipButton.frame = NSRect(x: (view.bounds.width - buttonWidth) / 2, y: buttonY, width: buttonWidth, height: buttonHeight)
        skipButton.target = self
        skipButton.bezelStyle = .rounded
        skipButton.contentTintColor = NSColor.white.withAlphaComponent(0.6)
        view.addSubview(skipButton)

        nextButton.frame = NSRect(x: view.bounds.width - buttonWidth - 60, y: buttonY, width: buttonWidth, height: buttonHeight)
        nextButton.target = self
        nextButton.bezelStyle = .rounded
        nextButton.contentTintColor = .systemBlue
        nextButton.keyEquivalent = "\r" // Enter key
        view.addSubview(nextButton)

        getStartedButton.frame = NSRect(x: (view.bounds.width - 200) / 2, y: buttonY, width: 200, height: buttonHeight)
        getStartedButton.target = self
        getStartedButton.bezelStyle = .rounded
        getStartedButton.contentTintColor = .systemGreen
        getStartedButton.keyEquivalent = "\r"
        getStartedButton.isHidden = true
        view.addSubview(getStartedButton)
    }

    private func updateStepContent() {
        let step = steps[currentStepIndex]

        // Update title and indicator
        titleLabel.stringValue = step.title
        stepIndicatorLabel.stringValue = "Step \(currentStepIndex + 1) of \(steps.count)"
        descriptionLabel.stringValue = step.description

        // Update tips
        tipsContainer.subviews.forEach { $0.removeFromSuperview() }

        let tipHeight: CGFloat = 32
        let tipSpacing: CGFloat = 8
        let startY = tipsContainer.bounds.height - 40

        for (index, tip) in step.tips.enumerated() {
            let yPosition = startY - CGFloat(index) * (tipHeight + tipSpacing)

            let tipLabel = NSTextField(wrappingLabelWithString: tip)
            tipLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
            tipLabel.textColor = NSColor(calibratedWhite: 0.2, alpha: 1.0)
            tipLabel.alignment = .left
            tipLabel.maximumNumberOfLines = 2
            tipLabel.frame = NSRect(x: 0, y: yPosition, width: tipsContainer.bounds.width, height: tipHeight)

            // Subtle background for each tip
            let backgroundView = NSView(frame: tipLabel.frame.insetBy(dx: -12, dy: -4))
            backgroundView.wantsLayer = true
            backgroundView.layer?.backgroundColor = NSColor(calibratedWhite: 0.96, alpha: 1.0).cgColor
            backgroundView.layer?.cornerRadius = 8
            tipsContainer.addSubview(backgroundView)
            tipsContainer.addSubview(tipLabel)
        }

        // Update button states
        previousButton.isEnabled = currentStepIndex > 0
        previousButton.alphaValue = currentStepIndex > 0 ? 1.0 : 0.3

        let isLastStep = currentStepIndex == steps.count - 1
        nextButton.isHidden = isLastStep
        skipButton.isHidden = isLastStep
        getStartedButton.isHidden = !isLastStep

        if !isLastStep {
            nextButton.title = "Next"
        }

        // Category-based styling
        updateCategoryStyle(for: step.category)
    }

    private func updateCategoryStyle(for category: OnboardingStep.StepCategory) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = headerView.bounds

        switch category {
        case .welcome:
            gradientLayer.colors = [
                NSColor.systemBlue.withAlphaComponent(0.3).cgColor,
                NSColor.systemPurple.withAlphaComponent(0.2).cgColor
            ]
        case .basics:
            gradientLayer.colors = [
                NSColor.systemGreen.withAlphaComponent(0.3).cgColor,
                NSColor.systemTeal.withAlphaComponent(0.2).cgColor
            ]
        case .voice:
            gradientLayer.colors = [
                NSColor.systemPink.withAlphaComponent(0.3).cgColor,
                NSColor.systemRed.withAlphaComponent(0.2).cgColor
            ]
        case .keyboard:
            gradientLayer.colors = [
                NSColor.systemIndigo.withAlphaComponent(0.3).cgColor,
                NSColor.systemBlue.withAlphaComponent(0.2).cgColor
            ]
        case .advanced:
            gradientLayer.colors = [
                NSColor.systemOrange.withAlphaComponent(0.3).cgColor,
                NSColor.systemYellow.withAlphaComponent(0.2).cgColor
            ]
        case .settings:
            gradientLayer.colors = [
                NSColor.systemGray.withAlphaComponent(0.3).cgColor,
                NSColor.systemGray.withAlphaComponent(0.1).cgColor
            ]
        }

        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)

        headerView.layer?.sublayers?.removeAll(where: { $0 is CAGradientLayer })
        headerView.layer?.insertSublayer(gradientLayer, at: 0)
    }

    @objc private func previousStep() {
        guard currentStepIndex > 0 else { return }
        currentStepIndex -= 1
        updateStepContent()
        animateTransition()
    }

    @objc private func nextStep() {
        guard currentStepIndex < steps.count - 1 else { return }
        currentStepIndex += 1
        updateStepContent()
        animateTransition()
    }

    @objc private func closeOnboarding() {
        // Mark onboarding as completed
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        view.window?.close()
    }

    private func animateTransition() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            contentView.animator().alphaValue = 0.0
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                self.contentView.animator().alphaValue = 1.0
            })
        })
    }
}

private struct ClarificationPending {
    let pendingTitle: String
}

class AppDelegate: NSObject, NSApplicationDelegate, AuthViewControllerDelegate {
    private var statusItem: NSStatusItem?
    private var overlayController: NotchOverlayController?
    private var wakeWordEngine: WakeWordEngine?
    private var speechRecognizer: SpeechRecognizer?
    private var intentRouter: IntentRouter?
    private var onboardingWindowController: OnboardingWindowController?
    private var authWindowController: AuthWindowController?

    private var currentVoiceSessionID: UUID?
    private var isSpaceHoldActive = false
    private var didHandleSpaceHoldForCurrentPress = false
    private var spaceKeyEventTap: CFMachPort?
    private var spaceKeyEventTapSource: CFRunLoopSource?
    private var shouldCaptureSpaceGlobally = false
    private var supabaseService: SupabaseService?
    private var supabaseSyncManager: SupabaseSyncManager?
    private var supabaseAuthManager: SupabaseAuthManager?
    private var supabaseStatusMenuItem: NSMenuItem?
    private var hasPromptedForAccessibilityPermission = false
    private var hasShownAccessibilityWarning = false

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

    private func releaseSpaceHoldIfNeeded() {
        if isSpaceHoldActive {
            isSpaceHoldActive = false
            speechRecognizer?.endExternalSilenceHold()
            overlayController?.setExternalSilenceHoldActive(false)
        }
    }

    private func activateGlobalSpaceCapture(promptIfNeeded: Bool = true) {
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

    private func deactivateGlobalSpaceCapture() {
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
        realSpeechRecognizer.onError = { [weak self] errorMessage in
            DebugLog.log("🎤 Speech recognition error: '\(errorMessage)'", category: .speech)
            self?.handleSpeechError(errorMessage)
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
    private func restartWakeWord(after delay: TimeInterval = 0.8) {
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

    private func rebuildDebugMenu(_ menu: NSMenu) {
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
    
    @objc private func toggleContextualAnimations(_ sender: NSMenuItem) {
        NotchIndicatorView.contextualAnimationsEnabled.toggle()
        sender.state = NotchIndicatorView.contextualAnimationsEnabled ? .on : .off
        print("🔧 Contextual notch animations \(NotchIndicatorView.contextualAnimationsEnabled ? "enabled" : "disabled")")
        // Refresh the notch display
        overlayController?.notchView?.needsDisplay = true
    }

    @objc private func setMaxOrbLimit(_ sender: NSMenuItem) {
        let newLimit = sender.tag
        UserDefaults.standard.set(newLimit, forKey: "maxOrbCount")
        print("🔧 Max orb limit set to \(newLimit)")

        // Rebuild menu to update checkmarks
        rebuildDebugMenu(debugMenu)
    }

    @objc private func setTextSize(_ sender: NSMenuItem) {
        let newSize: TextSizePreference.Size = sender.tag == 0 ? .regular : .large
        TextSizePreference.current = newSize
        print("🔧 Text size set to \(newSize.rawValue)")

        // Rebuild menu to update checkmarks
        rebuildDebugMenu(debugMenu)
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
    
    private func handlePartialTranscript(_ partial: String) {
        DebugLog.log("Partial transcript received: \(partial)", category: .speech)
        overlayController?.updateSpeechCapture(partialTranscript: partial)
    }

    private func handleSpeechError(_ errorMessage: String) {
        DebugLog.log("Voice session error: \(errorMessage)", category: .speech)
        releaseSpaceHoldIfNeeded()
        speechRecognizer?.stop()
        // showSpeechError now handles state reset to .idle so notch shrinks immediately
        overlayController?.showSpeechError(errorMessage)
        currentVoiceSessionID = nil
        restartWakeWord(after: 2.0)
    }
    
    private func handleFinalTranscript(_ final: String) {
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
            // NEW: Handle advanced task creation with all attributes
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
        releaseSpaceHoldIfNeeded()
        deactivateGlobalSpaceCapture()
        speechRecognizer?.stop()
        teardownSpaceKeyEventTap()
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

    @objc private func syncNow() {
        supabaseSyncManager?.forceFullPullOnce()
        supabaseSyncManager?.requestImmediateSync(reason: "Manual debug menu (full pull)")
    }

    @objc private func promptSupabaseSignIn() {
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

    @objc private func handleSupabaseSignOut() {
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
        releaseSpaceHoldIfNeeded()
        speechRecognizer?.stop()
        DebugLog.log("UI state reset via debug menu", category: .app)
    }

    @objc private func resetAllOrbs() {
        let alert = NSAlert()
        alert.messageText = "Reset All Orbs?"
        alert.informativeText = "This will permanently delete all orbs and their tasks. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset All Orbs")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            overlayController?.orbManager.clearAllOrbs()
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
    
    private func showInfoAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showErrorAlert(title: String, error: Error) {
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

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === debugMenu else { return }
        refreshLogMenuStates()
    }
}
