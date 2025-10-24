import Cocoa
import SwiftUI
import AppKit

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

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var overlayController: NotchOverlayController?
    private var wakeWordEngine: WakeWordEngine?
    private var speechRecognizer: SpeechRecognizer?
    private var intentRouter: IntentRouter?
    private var onboardingWindowController: OnboardingWindowController?

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
        checkAndShowOnboarding()
    }

    private func checkAndShowOnboarding() {
        // Show onboarding on first launch
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if !hasCompletedOnboarding {
            // Delay slightly so the app can finish launching
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showOnboarding()
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
    
    private func setupTestShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
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
                    self.overlayController?.cancelSpeechCapture()
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

    private func handleSpeechError(_ errorMessage: String) {
        overlayController?.setState(.error(errorMessage))
        overlayController?.showSpeechError(errorMessage)
        restartWakeWord(after: 2.0)
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
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === debugMenu else { return }
        refreshLogMenuStates()
    }
}
