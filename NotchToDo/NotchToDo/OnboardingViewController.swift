import Cocoa

// MARK: - Onboarding Step Model

struct OnboardingStep {
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

class OnboardingWindowController: NSWindowController {
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

class OnboardingViewController: NSViewController {
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
