import Cocoa
import SwiftUI
import QuartzCore
import UserNotifications
import NaturalLanguage



extension NSScreen {
    var hasTopNotchDesign: Bool {
        guard #available(macOS 12, *) else { return false }
        return safeAreaInsets.top != 0
    }
}

class NotchOverlayController: ObservableObject, TaskDetailViewDelegate, SpeechCaptureCoordinatorDelegate {
    private let persistenceController: PersistenceController
    private let orbStore: OrbPersistenceStore
    internal let orbManager: OrbManager  // Changed to internal for TaskCardView access
    internal var notchIndicatorWindow: NSWindow?
    internal var semiCircleWindow: NSWindow?
    internal var semiCircleView: SemiCircleWithOrbsView? // Added
    internal var currentOpenOrb: ProjectOrb? // Track which orb's card is currently open
    internal var taskCardWindows: [UUID: NSWindow] = [:] // Track multiple task cards by orb ID
    internal var taskDetailWindows: [UUID: NSWindow] = [:] // Track task detail windows by task ID
    internal var currentListenState: ListenState = .idle
    var isSemiCircleVisible = false // Added
    
    // Speech capture coordination
    let compactPreview = NotchCompactPreviewController()
    private lazy var speechCoordinator = SpeechCaptureCoordinator(delegate: self)
    private lazy var windowManager = OverlayWindowManager(controller: self)
    var speechFailureHandler: ((String) -> Void)?
    var speechCaptureVisibilityHandler: ((Bool) -> Void)?
    
        // Auto-fade timer system
    private var fadeTimer: Timer?
    private let fadeDelay: TimeInterval = 10.0
    private var isFaded: Bool = false
    private var isAutoFadeSuspended = false
    private var orbRattleTimer: Timer?
    
    // Task drag visualization
    var draggedTaskWindow: NSWindow?
    var draggedTaskView: TaskDragView?
    
    // Card size preferences (stores custom sizes per orb)
    internal var customCardSizes: [UUID: CGSize] = [:]

    // Undo Manager
    private let undoManager = UndoManager()

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.orbStore = OrbPersistenceStore(persistenceController: persistenceController)
        self.orbManager = OrbManager(includeSampleData: false) // Don't load sample data
        // Don't load orb state until authenticated
        orbManager.onChange = { [weak self] in
            self?.scheduleOrbSave()
        }
        windowManager.setupNotchIndicator()
        windowManager.setupSemiCircle()
        setupNotificationObservers()
        refreshOrbEmbeddingCache()
    }

    private func loadOrbState() {
        do {
            let snapshots = try orbStore.loadSnapshots()
            orbManager.applySnapshots(snapshots)
            if snapshots.isEmpty {
                scheduleOrbSave()
            }
        } catch {
            DebugLog.log("Failed to load persisted orb state: \(error)", category: .persistence)
            orbManager.applySnapshots([])
            scheduleOrbSave()
        }
    }

    // Expose a safe public reload for external callers
    func reloadFromPersistence() {
        loadOrbState()
    }
    
    // Load data when user authenticates
    func loadUserData() {
        loadOrbState()
        refreshOrbEmbeddingCache()
    }
    
    // Clear all local data (on sign-out)
    func clearLocalData() {
        DebugLog.log("🧹 Starting comprehensive local data cleanup...", category: .persistence)
        
        // 1. Clear orbs and tasks from memory FIRST
        orbManager.clearAllOrbs()
        orbManager.applySnapshots([])
        
        // 2. Delete all Core Data records (orbs, tasks, outbox)
        do {
            try orbStore.deleteAllData()
            DebugLog.log("✅ Deleted all Core Data records", category: .persistence)
        } catch {
            DebugLog.log("❌ Failed to delete Core Data: \(error)", category: .persistence)
        }
        
        // 3. Clear ML training data and caches
        TaskClassifier.shared.clearAllMLData()
        
        // 4. Close all open windows
        taskCardWindows.values.forEach { $0.close() }
        taskCardWindows.removeAll()
        taskDetailWindows.values.forEach { $0.close() }
        taskDetailWindows.removeAll()
        currentOpenOrb = nil
        
        // 5. Hide semi-circle overlay
        hideSemiCircle()
        
        // 6. Clear custom sizes
        customCardSizes.removeAll()
        
        // 7. Reset UI state
        currentListenState = .idle
        
        DebugLog.log("✅ Comprehensive local data cleanup complete", category: .persistence)
    }

    private func scheduleOrbSave() {
        let snapshots = orbManager.makeSnapshots()
        orbStore.scheduleSave(orbs: snapshots)
    }

    // Persist immediately and nudge sync so remote reflects edits quickly
    private func persistEditsImmediately() {
        let snapshots = orbManager.makeSnapshots()
        orbStore.saveImmediately(orbs: snapshots)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .supabaseOutboxDidChange, object: nil)
        }
    }
    
        func toggleOverlay() {
        if isSemiCircleVisible {
            hideSemiCircle()
        } else {
            showSemiCircle()
        }
    }
    
    func speechBubbleCenter(relativeTo view: NSView) -> CGPoint? {
        speechCoordinator.speechBubbleCenter(relativeTo: view)
    }
    
    func bubbleTargetOrbId() -> UUID? {
        speechCoordinator.bubbleTargetOrbId()
    }
    
    func setState(_ state: ListenState) {
        currentListenState = state
        if let notchView = notchIndicatorWindow?.contentView as? NotchIndicatorView {
            notchView.update(for: state)
        }
    }
    
    var notchView: NotchIndicatorView? {
        return notchIndicatorWindow?.contentView as? NotchIndicatorView
    }
    
    private func updateNotchContext(for orb: ProjectOrb?) {
        guard let notchView = notchIndicatorWindow?.contentView as? NotchIndicatorView else { return }
        
        if let orb = orb {
            // Calculate project progress
            let progress = orb.tasks.isEmpty ? 0.0 : CGFloat(orb.tasks.filter { $0.isCompleted }.count) / CGFloat(orb.tasks.count)
            notchView.updateContext(orbColor: orb.color, progress: progress)
            } else {
            // Clear context when no orb is active
            notchView.updateContext(orbColor: nil, progress: 0.0)
        }
    }
    
    func addTask(_ title: String) {
        let targetOrb = resolveTargetOrbForNewTask()
        addTask(title, to: targetOrb)
    }
    
    internal func resolveTargetOrbForNewTask() -> ProjectOrb {
        if let openOrb = currentOpenOrb {
            return openOrb
        } else {
            // Use dedicated "Captured Tasks" orb for uncategorized tasks
            let capturedTasksOrb = orbManager.findOrCreateCapturedTasksOrb()
            semiCircleView?.needsDisplay = true
            return capturedTasksOrb
        }
    }
    
    func addTask(_ title: String, to targetOrb: ProjectOrb) {
        // Validate and sanitize task title
        let validatedTitle: String
        do {
            validatedTitle = try InputValidator.validateTaskTitle(title)
        } catch {
            DebugLog.logValidationError(error as! InputValidator.ValidationError, category: .app)
            DebugLog.log("Task creation failed due to validation error", category: .app)
            // Use a safe fallback or show error to user
            return
        }

        targetOrb.addTask(title: validatedTitle)
        let newlyCreatedTask = targetOrb.tasks.last

        if let window = taskCardWindows[targetOrb.id],
           let taskCardView = window.contentView as? TaskCardView {
            taskCardView.updateTasks(targetOrb.tasks, projectName: targetOrb.name, orbColor: targetOrb.color, orbId: targetOrb.id)
            window.alphaValue = 1.0
            window.makeKeyAndOrderFront(nil)
            if let task = newlyCreatedTask {
                taskCardView.highlightTask(task)
            }
        }

        if currentOpenOrb?.id == targetOrb.id, taskCardWindows[targetOrb.id] == nil {
            currentOpenOrb = nil
        }

        // Update notch context if this is the current orb
        if currentOpenOrb?.id == targetOrb.id {
            updateNotchContext(for: targetOrb)
        }

        semiCircleView?.needsDisplay = true

        // Reset fade timer when a task is added
        resetFadeTimer()
    }

    func refreshOrbEmbeddingCache() {
        speechCoordinator.refreshOrbEmbeddingCache()
    }

    func primeEmbedding(for orb: ProjectOrb) {
        speechCoordinator.primeEmbedding(for: orb)
    }

    func beginSpeechCaptureSession(sessionID: UUID, wakePhrase: String? = nil) {
        speechCoordinator.beginSession(sessionID: sessionID, wakePhrase: wakePhrase)
    }

    func beginSpeechCaptureSession() {
        beginSpeechCaptureSession(sessionID: UUID())
    }

    func updateSpeechCapture(partialTranscript: String) {
        speechCoordinator.updatePartialTranscript(partialTranscript)
    }

    func finalizeSpeechCapture(with transcript: String, resolvedTaskTitle: String? = nil) {
        speechCoordinator.finalizeTranscript(transcript, resolvedTaskTitle: resolvedTaskTitle)
    }

    func finalizeSpeechCaptureForCommand(transcript: String, status: String?, completion: (() -> Void)? = nil) {
        speechCoordinator.finalizeCommand(transcript: transcript, status: status, completion: completion)
    }

    /// NEW: Finalize speech capture for advanced task creation with all attributes
    func finalizeSpeechCaptureForAdvancedTask(intent: TaskIntent) {
        DebugLog.log("Finalizing advanced task: \(intent.title)", category: .intent)

        // Resolve target orb using fuzzy matching if specified
        var targetOrb: ProjectOrb

        if let targetOrbName = intent.targetOrb {
            // Try fuzzy matching against available orbs
            let orbNames = orbManager.orbs.map { $0.name }

            if let match = FuzzyOrbMatcher.findBestMatch(targetOrbName, in: orbNames) {
                DebugLog.log("Matched orb '\(targetOrbName)' to '\(match.orbName)' (confidence: \(match.confidence))", category: .intent)

                if let foundOrb = orbManager.orbs.first(where: { $0.name == match.orbName }) {
                    targetOrb = foundOrb
                } else {
                    DebugLog.log("Orb match failed, using default", category: .intent)
                    targetOrb = resolveTargetOrbForNewTask()
                }
            } else {
                DebugLog.log("No orb match found for '\(targetOrbName)', using ML classifier", category: .intent)
                targetOrb = resolveTargetOrbForNewTask()
            }
        } else {
            // No orb specified, use ML classification (existing behavior)
            targetOrb = resolveTargetOrbForNewTask()
        }

        // Create the task with all attributes
        targetOrb.addTask(from: intent)

        // Update UI
        if let window = taskCardWindows[targetOrb.id],
           let taskCardView = window.contentView as? TaskCardView {
            taskCardView.updateTasks(targetOrb.tasks, projectName: targetOrb.name, orbColor: targetOrb.color, orbId: targetOrb.id)
            window.alphaValue = 1.0
            window.makeKeyAndOrderFront(nil)
            if let newTask = targetOrb.tasks.last {
                taskCardView.highlightTask(newTask)
            }
        }

        // Finalize speech capture UI
        speechCoordinator.finalizeCommand(
            transcript: intent.title,
            status: "Added to \(targetOrb.name)",
            completion: nil
        )

        // Update notch context
        if currentOpenOrb?.id == targetOrb.id {
            updateNotchContext(for: targetOrb)
        }

        semiCircleView?.needsDisplay = true
        resetFadeTimer()
    }

    func cancelSpeechCapture() {
        speechCoordinator.cancelSession()
    }

    func revealOverlayForVoice(completion: (() -> Void)? = nil) {
        speechCoordinator.revealOverlayForVoice(completion: completion)
    }

    func showClarificationPrompt(for title: String) {
        speechCoordinator.showClarificationPrompt(for: title)
    }

    func remindClarification(for title: String) {
        speechCoordinator.remindClarification(for: title)
    }

    func dismissClarificationPrompt() {
        speechCoordinator.dismissClarificationPrompt()
    }

    func showSpeechError(_ errorMessage: String) {
        speechCoordinator.showSpeechError(errorMessage)
    }

    func speechCaptureCoordinator(_ coordinator: SpeechCaptureCoordinator, didFailWith message: String) {
        speechFailureHandler?(message)
    }

    func speechCaptureBubbleDidAppear() {
        speechCaptureVisibilityHandler?(true)
    }

    func speechCaptureBubbleDidDisappear() {
        speechCaptureVisibilityHandler?(false)
    }

    func isSpeechCaptureActive() -> Bool {
        speechCoordinator.isSpeechCaptureActive()
    }
    
    func setExternalSilenceHoldActive(_ active: Bool) {
        speechCoordinator.setExternalSilenceHoldActive(active)
    }

    // MARK: - Speech Capture Bubble

// MARK: - Keyboard Shortcut Helpers
    func switchToOrb(at index: Int) {
        guard index >= 0 && index < orbManager.orbs.count else {
            DebugLog.log("⌨️ Cannot switch to orb at index \(index) - out of bounds", category: .app)
            return
        }

        let orb = orbManager.orbs[index]
        DebugLog.log("⌨️ Switching to orb \(index + 1): \(orb.name)", category: .app)

        // Show semi-circle if not visible
        if !isSemiCircleVisible {
            showSemiCircle()
        }

        // Show task card for the selected orb
        showTaskCard(for: orb)
        AudioFeedback.shared.play(.wake, volume: 0.3)
    }
    
    func activateNotchTrace(completion: (() -> Void)? = nil) {
        // Show notch indicator and start trace
        if let window = notchIndicatorWindow {
            window.makeKeyAndOrderFront(nil)
            
            // Reset and restart the trace animation
            if let notchView = window.contentView as? NotchIndicatorView {
                notchView.resetAndStartTrace(completion: completion)
            } else {
                completion?()
            }
        } else {
            completion?()
        }
    }
    
    func debugResetUIState() {
        speechCoordinator.resetUIState()
        draggedTaskWindow?.orderOut(nil)
        draggedTaskWindow = nil
        draggedTaskView = nil
        for window in taskDetailWindows.values {
            window.orderOut(nil)
        }
        taskDetailWindows.removeAll()
        for window in taskCardWindows.values {
            window.orderOut(nil)
        }
        taskCardWindows.removeAll()
        currentOpenOrb = nil
        isSemiCircleVisible = false

        // Show notch base rim when resetting
        if let notchView = notchIndicatorWindow?.contentView as? NotchIndicatorView {
            notchView.isSemiCircleVisible = false
            notchView.needsDisplay = true
        }

        orbManager.hideOrbs()
        semiCircleView?.setAnimationsActive(false)
        semiCircleView?.needsDisplay = true
        setState(.idle)
        DebugLog.log("Overlay state reset via debug menu", category: .app)
    }
    
    func hideSemiCircle() {
        guard let window = semiCircleWindow else { return }
        
        // Mark as not visible
        isSemiCircleVisible = false

        // Show notch base rim when semi-circle is hidden
        if let notchView = notchIndicatorWindow?.contentView as? NotchIndicatorView {
            notchView.isSemiCircleVisible = false
            notchView.needsDisplay = true
        }
        
        // Hide orbs first
        orbManager.hideOrbs()
        semiCircleView?.setAnimationsActive(false)
        
        // Animate semi-circle disappearing
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0)
            window.animator().alphaValue = 0.0
        } completionHandler: {
            window.orderOut(nil)
        }
    }
    
    func testSemiCircle() {
        showSemiCircle()
    }
    
    private func calculateCardHeight(for taskCount: Int) -> CGFloat {
        let minHeight: CGFloat = 200
        let maxHeight: CGFloat = 600
        let headerHeight: CGFloat = TaskRowMetrics.headerHeight
        let rowStride: CGFloat = TaskRowMetrics.rowHeight + TaskRowMetrics.rowSpacing
        let padding: CGFloat = TaskRowMetrics.cardInset * 2
        
        let visibleRows = min(taskCount, 8)
        let calculatedHeight = headerHeight + (CGFloat(visibleRows) * rowStride) + padding
        
        return max(minHeight, min(maxHeight, calculatedHeight))
    }
    
    func showTaskCard(for orb: ProjectOrb) {
        DebugLog.log("🎯 showTaskCard() called for orb: \(orb.name)", category: .app)
        
        // Check if this orb already has a task card open
        if taskCardWindows[orb.id] != nil {
            DebugLog.log("🎯 Toggling off existing task card for orb: \(orb.name)", category: .tasks)
            hideTaskCard(for: orb)
            return
        }
        
        DebugLog.log("🎯 Creating new task card for orb: \(orb.name)", category: .tasks)
        DebugLog.log("🎯 Orb has \(orb.tasks.count) tasks", category: .tasks)
        
        // Calculate dynamic height, or use custom size if set
        let defaultWidth: CGFloat = 420  // Increased from 360 for more breathing room
        let defaultHeight: CGFloat = 560  // Increased from 480 for better content visibility
        let cardWidth: CGFloat = customCardSizes[orb.id]?.width ?? defaultWidth
        let cardHeight: CGFloat = customCardSizes[orb.id]?.height ?? max(defaultHeight, calculateCardHeight(for: orb.tasks.count))
        
        // Create a new task card window for this orb
        let window = TaskCardWindow(
            contentRect: NSRect(x: 0, y: 0, width: cardWidth, height: cardHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = true
        window.level = .floating
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true  // Required for scroll events
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovable = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Create task card view
        let taskCardView = TaskCardView()
        taskCardView.setController(self)
        taskCardView.updateTasks(orb.tasks, projectName: orb.name, orbColor: orb.color, orbId: orb.id)
        taskCardView.setAmbientAnimationActive(true)
        
        // Ensure the view has the correct frame
        taskCardView.frame = NSRect(x: 0, y: 0, width: cardWidth, height: cardHeight)
        window.contentView = taskCardView
        
        DebugLog.log("🎯 Task card view frame: \(taskCardView.frame)", category: .tasks)
        DebugLog.log("🎯 Window frame: \(window.frame)", category: .app)
        
        // Position the card below the semi-circle
        guard let screen = NSScreen.main,
              let semiCircleWindow = semiCircleWindow else { return }
        
        let screenFrame = screen.frame
        let semiCircleFrame = semiCircleWindow.frame
        
        // Calculate radial cascade position based on orb's angle
        let windowWidth = window.frame.width
        let windowHeight = window.frame.height
        
        // Semi-circle center point
        let semiCircleCenterX = semiCircleFrame.midX
        let semiCircleCenterY = semiCircleFrame.minY + 79.0 // Match OrbManager's semiCircleCenterY
        
        // Cascade radius depends on number of open cards
        let baseCascadeRadius: CGFloat = 200
        let radiusIncrement: CGFloat = 40
        let cascadeRadius = baseCascadeRadius + (CGFloat(taskCardWindows.count) * radiusIncrement)
        
        // Calculate position along the radial line from orb's angle
        let orbAngle = orb.angle // Radians from orb position
        let cardX = semiCircleCenterX + cos(orbAngle) * cascadeRadius - (windowWidth / 2)
        let cardY = semiCircleCenterY + sin(orbAngle) * cascadeRadius - windowHeight
        
        // Ensure the card stays on screen with boundary checking
        let finalX = max(10, min(cardX, screenFrame.width - windowWidth - 10))
        let finalY = max(10, min(cardY, screenFrame.height - windowHeight - 10))
        let finalFrame = NSRect(x: finalX, y: finalY, width: windowWidth, height: windowHeight)
        
        // Calculate orb center position for animation start point
        let orbCenterX = semiCircleCenterX + cos(orbAngle) * 102.5 // orb radius from semi-circle center
        let orbCenterY = semiCircleCenterY + sin(orbAngle) * 102.5
        
        // Start at orb center with small scale
        let startScale: CGFloat = 0.3
        let startX = orbCenterX - (windowWidth * startScale) / 2
        let startY = orbCenterY - (windowHeight * startScale) / 2
        let startFrame = NSRect(x: startX, y: startY, width: windowWidth * startScale, height: windowHeight * startScale)
        
        window.setFrame(startFrame, display: false)
        window.alphaValue = 0.0
        window.makeKeyAndOrderFront(nil)
        
        // Track it immediately
        taskCardWindows[orb.id] = window
        currentOpenOrb = orb
        
        // Update contextual notch animations
        updateNotchContext(for: orb)
        
        // Animate entry with bounce (scale to 1.1 then 1.0)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1.0)
            window.animator().alphaValue = 1.0
            
            // Animate to slightly oversized (1.1x scale)
            let bounceWidth = windowWidth * 1.1
            let bounceHeight = windowHeight * 1.1
            let bounceX = finalX - (bounceWidth - windowWidth) / 2
            let bounceY = finalY - (bounceHeight - windowHeight) / 2
            let bounceFrame = NSRect(x: bounceX, y: bounceY, width: bounceWidth, height: bounceHeight)
            window.animator().setFrame(bounceFrame, display: true)
        }, completionHandler: {
            // Settle to final size
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.0, 0.2, 1.0)
                window.animator().setFrame(finalFrame, display: true)
            })
        })
        
        DebugLog.log("🎯 Task card animating in at position: \(finalFrame)", category: .tasks)
        DebugLog.log("🎯 Total open task cards: \(taskCardWindows.count)", category: .tasks)
    }
    
    func hideTaskCard() {
        // Hide all task cards
        for (_, window) in taskCardWindows {
            if let cardView = window.contentView as? TaskCardView {
                cardView.setAmbientAnimationActive(false)
            }
            window.orderOut(nil)
        }
        taskCardWindows.removeAll()
        currentOpenOrb = nil
        DebugLog.log("🎯 All task cards hidden", category: .tasks)
    }
    
    func hideTaskCard(for orb: ProjectOrb) {
        if let window = taskCardWindows[orb.id] {
            if let cardView = window.contentView as? TaskCardView {
                cardView.setAmbientAnimationActive(false)
            }
            // Calculate orb center for exit animation
            guard NSScreen.main != nil,
                  let semiCircleWindow = semiCircleWindow else {
            window.orderOut(nil)
            taskCardWindows.removeValue(forKey: orb.id)
                return
            }
            
            let semiCircleFrame = semiCircleWindow.frame
            let semiCircleCenterX = semiCircleFrame.midX
            let semiCircleCenterY = semiCircleFrame.minY + 79.0
            
            let orbAngle = orb.angle
            let orbCenterX = semiCircleCenterX + cos(orbAngle) * 102.5
            let orbCenterY = semiCircleCenterY + sin(orbAngle) * 102.5
            
            // Animate exit to orb center
            let currentFrame = window.frame
            let endScale: CGFloat = 0.3
            let endWidth = currentFrame.width * endScale
            let endHeight = currentFrame.height * endScale
            let endX = orbCenterX - endWidth / 2
            let endY = orbCenterY - endHeight / 2
            let endFrame = NSRect(x: endX, y: endY, width: endWidth, height: endHeight)
            
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.6, 1.0)
                window.animator().alphaValue = 0.0
                window.animator().setFrame(endFrame, display: true)
            }, completionHandler: {
                window.orderOut(nil)
                self.taskCardWindows.removeValue(forKey: orb.id)
                
                if self.currentOpenOrb?.id == orb.id {
                    self.currentOpenOrb = self.taskCardWindows.isEmpty ? nil : self.orbManager.orbs.first { self.taskCardWindows[$0.id] != nil }
                    // Update notch context to the new current orb (or clear if none)
                    self.updateNotchContext(for: self.currentOpenOrb)
                }
                
                DebugLog.log("🎯 Task card animated out for orb: \(orb.name)", category: .tasks)
                DebugLog.log("🎯 Remaining open task cards: \(self.taskCardWindows.count)", category: .tasks)
            })
        }
    }
    
    func taskCardPinStateChanged(isPinned: Bool) {
        DebugLog.log("📌 Task card pin state changed: \(isPinned ? "pinned" : "unpinned")", category: .tasks)
        
        if isPinned {
            // If task card is pinned, don't fade it
            DebugLog.log("📌 Task card is pinned - will not fade", category: .tasks)
        } else {
            // If task card is unpinned, reset the fade timer
            DebugLog.log("📌 Task card is unpinned - resetting fade timer", category: .tasks)
            resetFadeTimer()
        }
    }
    
    func closeTaskCard(for taskCardView: TaskCardView) {
        // Find the orb ID for this task card view
        for (orbId, window) in taskCardWindows {
            if window.contentView === taskCardView {
                DebugLog.log("❌ Closing task card for orb ID: \(orbId)", category: .tasks)
                hideTaskCard(for: orbManager.orbs.first { $0.id == orbId } ?? orbManager.orbs[0])
                return
            }
        }
        DebugLog.log("❌ Could not find orb for task card view", category: .tasks)
    }
    
    func showTaskDetail(for task: Task, orbColor: NSColor) {
        DebugLog.log("🎯 Opening task detail for task: '\(task.title)' (ID: \(task.id))", category: .tasks)
        
        // Close existing task detail window for this task if open
        if taskDetailWindows[task.id] != nil {
            DebugLog.log("🎯 Closing existing window for task ID: \(task.id)", category: .tasks)
            closeTaskDetail(for: task.id)
        }
        
        // Create new task detail window with modern styling
        let window = TaskDetailWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 560),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        DebugLog.log("🎯 Created TaskDetailWindow: \(window)", category: .app)
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.ignoresMouseEvents = false
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovable = true
        window.acceptsMouseMovedEvents = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Add subtle shadow for modern look
        window.hasShadow = true
        
        // Make window key-able
        window.makeKey()
        
        // Create the task detail view
        let taskDetailView = TaskDetailView(task: task, orbColor: orbColor)
        taskDetailView.setDelegate(self)
        DebugLog.log("🎯 Created TaskDetailView: \(taskDetailView)", category: .app)

        // Set the task detail view reference for keyboard shortcuts
        window.taskDetailView = taskDetailView
        
        window.contentView = taskDetailView
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 24
        window.contentView?.layer?.masksToBounds = true
        
        // Position the window to the side of task lists
        let screenFrame = NSScreen.main?.frame ?? NSRect.zero
        let windowWidth: CGFloat = 440
        let windowHeight: CGFloat = 560
        
        // Position to the right side of the screen, centered vertically
        let windowFrame = NSRect(
            x: screenFrame.maxX - windowWidth - 50, // 50px from right edge
            y: screenFrame.midY - windowHeight/2,   // Centered vertically
            width: windowWidth,
            height: windowHeight
        )
        window.setFrame(windowFrame, display: true)
        
        // Show the window
        window.makeKeyAndOrderFront(nil)
        taskDetailWindows[task.id] = window
        
        DebugLog.log("🎯 Task detail window opened and stored for task: '\(task.title)'", category: .tasks)
    }

    func requestProjectDeletion(for taskCardView: TaskCardView) {
        guard let orbId = taskCardView.currentOrbIdentifier(),
              let orb = orbManager.orbs.first(where: { $0.id == orbId }) else {
            DebugLog.log("🗑️ Delete requested but orb lookup failed", category: .overlay)
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Delete \"\(orb.name)\"?"
        alert.informativeText = "This will remove the project and all of its tasks. You can undo this action with Cmd+Z."
        alert.addButton(withTitle: "Delete Project")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() != .alertFirstButtonReturn {
            return
        }

        deleteProject(orb)
    }

    // MARK: - Delete Operations with Undo Support

    func deleteProject(_ orb: ProjectOrb) {
        guard let index = orbManager.removeOrb(orb) else {
            DebugLog.log("🗑️ Failed to remove orb", category: .overlay)
            return
        }

        // Store state for undo
        let deletedOrb = orb
        let savedIndex = index
        let wasOpen = currentOpenOrb?.id == orb.id
        let savedCardSize = customCardSizes[orb.id]

        // Perform deletion
        hideTaskCard(for: orb)
        customCardSizes.removeValue(forKey: orb.id)
        if currentOpenOrb?.id == orb.id {
            currentOpenOrb = nil
        }
        refreshOrbEmbeddingCache()
        semiCircleView?.needsDisplay = true

        DebugLog.log("🗑️ Deleted project \(orb.name)", category: .overlay)
        showUndoNotification(message: "Deleted \"\(deletedOrb.name)\"")

        // Persist immediately to prevent reappearance on app relaunch
        persistEditsImmediately()

        // Register undo
        undoManager.registerUndo(withTarget: self) { controller in
            controller.restoreProject(deletedOrb, at: savedIndex, wasOpen: wasOpen, cardSize: savedCardSize)
        }
        undoManager.setActionName("Delete Project")
    }

    private func restoreProject(_ orb: ProjectOrb, at index: Int, wasOpen: Bool, cardSize: CGSize?) {
        orbManager.insertOrb(orb, at: index)

        if let size = cardSize {
            customCardSizes[orb.id] = size
        }

        if wasOpen {
            currentOpenOrb = orb
            showTaskCard(for: orb)
        }

        refreshOrbEmbeddingCache()
        semiCircleView?.needsDisplay = true

        DebugLog.log("↩️ Restored project \(orb.name)", category: .overlay)
        showUndoNotification(message: "Restored \"\(orb.name)\"")

        // Register redo
        undoManager.registerUndo(withTarget: self) { controller in
            controller.deleteProject(orb)
        }
        undoManager.setActionName("Restore Project")
    }

    func deleteTask(_ task: Task, from orb: ProjectOrb) {
        guard let index = orb.deleteTask(task) else {
            DebugLog.log("🗑️ Failed to delete task", category: .tasks)
            return
        }

        // Close task detail window if open
        closeTaskDetail(for: task.id)

        // Refresh task card
        if let cardWindow = taskCardWindows[orb.id],
           let cardView = cardWindow.contentView as? TaskCardView {
            cardView.updateTasks(orb.tasks, projectName: orb.name, orbColor: orb.color, orbId: orb.id)
        }

        DebugLog.log("🗑️ Deleted task \"\(task.title)\"", category: .tasks)
        showUndoNotification(message: "Deleted \"\(task.title)\"")

        // Register undo
        undoManager.registerUndo(withTarget: self) { controller in
            controller.restoreTask(task, to: orb, at: index)
        }
        undoManager.setActionName("Delete Task")
    }

    private func restoreTask(_ task: Task, to orb: ProjectOrb, at index: Int) {
        orb.insertTask(task, at: index)

        // Refresh task card
        if let cardWindow = taskCardWindows[orb.id],
           let cardView = cardWindow.contentView as? TaskCardView {
            cardView.updateTasks(orb.tasks, projectName: orb.name, orbColor: orb.color, orbId: orb.id)
        }

        DebugLog.log("↩️ Restored task \"\(task.title)\"", category: .tasks)
        showUndoNotification(message: "Restored \"\(task.title)\"")

        // Register redo
        undoManager.registerUndo(withTarget: self) { controller in
            controller.deleteTask(task, from: orb)
        }
        undoManager.setActionName("Restore Task")
    }

    private func showUndoNotification(message: String) {
        // Create a simple toast-style notification
        print("💬 \(message) - Press Cmd+Z to undo")
        AudioFeedback.shared.play(.success, volume: 0.3)
    }

    func performUndo() {
        guard undoManager.canUndo else {
            print("⚠️ Nothing to undo")
            return
        }

        undoManager.undo()
        AudioFeedback.shared.play(.wake, volume: 0.4)
        print("↩️ Undo: \(undoManager.undoActionName)")
    }

    func performRedo() {
        guard undoManager.canRedo else {
            print("⚠️ Nothing to redo")
            return
        }

        undoManager.redo()
        AudioFeedback.shared.play(.wake, volume: 0.4)
        print("↪️ Redo: \(undoManager.redoActionName)")
    }

    func closeTaskDetail(for taskId: UUID) {
        DebugLog.log("🎯 Close requested for task ID: \(taskId)", category: .tasks)
        
        guard let window = taskDetailWindows.removeValue(forKey: taskId) else {
            DebugLog.log("⚠️ Close requested but no window found for task ID: \(taskId)", category: .tasks)
            return
        }
        
        if let detailView = window.contentView as? TaskDetailView {
            detailView.prepareForClose()
        }

        // Ensure any pending edits are flushed and synced before hiding
        persistEditsImmediately()
        
        window.makeFirstResponder(nil)
        window.orderOut(nil)
        window.contentView = nil
        window.delegate = nil
        
        DebugLog.log("🎯 Task detail window closed for task ID: \(taskId)", category: .tasks)
    }
    
    func taskDetailView(_ view: TaskDetailView, didTogglePin isPinned: Bool) {
        if let window = view.window as? TaskDetailWindow {
            window.isPinned = isPinned
        }
        DebugLog.log("📌 Task detail pin state changed: \(isPinned ? "pinned" : "unpinned")", category: .tasks)
    }

    func persistEditsNow(for taskId: UUID) {
        persistEditsImmediately()
    }
    
    // MARK: - Task Drag and Drop Between Cards
    
    func updateTaskDragLocation(_ location: NSPoint, from sourceCard: TaskCardView) {
        // Convert location to screen coordinates for checking other cards
        guard let sourceWindow = sourceCard.window else { return }
        let screenLocation = NSPoint(
            x: sourceWindow.frame.origin.x + location.x,
            y: sourceWindow.frame.origin.y + location.y
        )
        
        // Check if we're over any other task card
        for (_, window) in taskCardWindows {
            if window.contentView !== sourceCard && window.isVisible {
                let windowFrame = window.frame
                if windowFrame.contains(screenLocation) {
                    // We're over another task card - show drop indicator
                    if let targetCard = window.contentView as? TaskCardView {
                        targetCard.showDropIndicator(true)
                    }
                } else {
                    // Not over this card - hide drop indicator
                    if let targetCard = window.contentView as? TaskCardView {
                        targetCard.showDropIndicator(false)
                    }
                }
            }
        }
    }
    
    func handleTaskDrop(from sourceCard: TaskCardView, draggedTask: Task?, draggedTaskIndex: Int) {
        guard let task = draggedTask else { return }
        
        // Find the target card (the one with drop indicator)
        var targetCard: TaskCardView?
        for (_, window) in taskCardWindows {
            if let card = window.contentView as? TaskCardView, card !== sourceCard {
                if card.isShowingDropIndicator {
                    targetCard = card
                    break
                }
            }
        }
        
        // Hide all drop indicators
        for (_, window) in taskCardWindows {
            if let card = window.contentView as? TaskCardView {
                card.showDropIndicator(false)
            }
        }
        
        if let target = targetCard {
            // Transfer task to target orb
            transferTask(task, from: sourceCard, to: target)
        } else {
            // No valid drop target - task stays in original position
            DebugLog.log("🎯 No valid drop target - task stays in original position", category: .tasks)
        }
    }
    
    private func transferTask(_ task: Task, from sourceCard: TaskCardView, to targetCard: TaskCardView) {
        // Find source and target orbs
        var sourceOrb: ProjectOrb?
        var targetOrb: ProjectOrb?
        
        for (orbId, window) in taskCardWindows {
            if window.contentView === sourceCard {
                sourceOrb = orbManager.orbs.first { $0.id == orbId }
            }
            if window.contentView === targetCard {
                targetOrb = orbManager.orbs.first { $0.id == orbId }
            }
        }
        
        guard let source = sourceOrb, let target = targetOrb else {
            DebugLog.log("❌ Could not find source or target orb for task transfer", category: .tasks)
            return
        }
        
        // Transfer task between orbs
        if let taskIndex = source.tasks.firstIndex(where: { $0.id == task.id }) {
            let transferredTask = source.tasks.remove(at: taskIndex)
            target.tasks.append(transferredTask)
            
            // Update both task cards
            sourceCard.updateTasks(source.tasks, projectName: source.name, orbColor: source.color, orbId: source.id)
            targetCard.updateTasks(target.tasks, projectName: target.name, orbColor: target.color, orbId: target.id)

            let sourceMidY = sourceCard.window?.frame.midY ?? targetCard.window?.frame.midY ?? 0
            let targetMidY = targetCard.window?.frame.midY ?? sourceMidY
            targetCard.animateTaskDrop(transferredTask, verticalTravel: sourceMidY - targetMidY)
            
            // Update orb task counters
            source.syncTaskCount()
            target.syncTaskCount()
            
            // Recalculate scroll for both task cards
            sourceCard.calculateMaxScrollOffset()
            targetCard.calculateMaxScrollOffset()
            
            // Trigger orb display update to refresh task counters
            semiCircleView?.needsDisplay = true
            
            DebugLog.log("🎯 Transferred task '\(task.title)' from '\(source.name)' to '\(target.name)'", category: .tasks)
            DebugLog.log("🎯 Updated task counts - \(source.name): \(source.taskCount), \(target.name): \(target.taskCount)", category: .tasks)
        }
    }
    
    // MARK: - Celebration System
    
    func triggerOrbCelebration() {
        DebugLog.log("🎉 Triggering orb celebration rattle!", category: .app)
        
        // Start continuous rattling for all orbs
        startOrbRattling()
        
        // Also trigger a brief intense glow on the semi-circle
        triggerSemiCircleCelebration()
    }
    
    private func startOrbRattling() {
        // Create a timer for continuous rattling
        var rattleCount = 0
        let maxRattles = 30  // 30 rattles over 3 seconds (10 per second)
        
        let rattleTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // Apply rapid, small impulses to all orbs
            for orb in self.orbManager.orbs {
                // Small, quick impulses in random directions
                let rattleForce = 8.0 + Double.random(in: -3...3)  // Vary force slightly
                let randomAngle = Double.random(in: 0...2*Double.pi)
                let forceX = cos(randomAngle) * rattleForce
                let forceY = sin(randomAngle) * rattleForce
                
                orb.applyImpulse(CGPoint(x: forceX, y: forceY))
            }
            
            rattleCount += 1
            
            // Stop rattling after 3 seconds
            if rattleCount >= maxRattles {
                timer.invalidate()
                DebugLog.log("🎉 Orb rattling complete!", category: .app)
            }
        }
        
        // Store timer reference to prevent deallocation
        orbRattleTimer = rattleTimer
    }
    
    private func triggerSemiCircleCelebration() {
        // This could trigger a brief glow effect on the semi-circle itself
        // For now, just log that we're celebrating
        DebugLog.log("🎉 Semi-circle celebration triggered!", category: .app)
    }
    
    deinit {
        // Clean up all timers
        fadeTimer?.invalidate()
        orbRattleTimer?.invalidate()
    }
    
    // MARK: - Auto-Fade System

    /// Check if user is actively interacting with any UI elements
    private func hasActiveInteractions() -> Bool {
        // Check if any task cards are visible
        let hasVisibleTaskCards = taskCardWindows.values.contains { $0.isVisible }

        // Check if any task detail windows are visible
        let hasVisibleTaskDetails = taskDetailWindows.values.contains { $0.isVisible }

        // Check if any task card has active search
        let hasActiveSearch = taskCardWindows.values.compactMap { window in
            window.contentView as? TaskCardView
        }.contains { taskCardView in
            taskCardView.getSearchActiveState()
        }

        // Check if user is hovering over or dragging an orb
        let isHoveringOrb = semiCircleView?.hoveredOrbId != nil
        let isDraggingOrb = semiCircleView?.isDragging == true

        let hasInteractions = hasVisibleTaskCards || hasVisibleTaskDetails || hasActiveSearch || isHoveringOrb || isDraggingOrb

        if hasInteractions {
            DebugLog.log("🔄 Active interactions detected - taskCards: \(hasVisibleTaskCards), taskDetails: \(hasVisibleTaskDetails), search: \(hasActiveSearch), hoveringOrb: \(isHoveringOrb), draggingOrb: \(isDraggingOrb)", category: .app)
        }

        return hasInteractions
    }
    
    func resetFadeTimer() {
        if isAutoFadeSuspended {
            DebugLog.log("🛑 resetFadeTimer() ignored - auto fade suspended", category: .app)
            if isFaded {
                DebugLog.log("🔄 Auto fade suspended while faded - showing elements", category: .app)
                showAllElements()
            }
            return
        }

        // Cancel existing timer
        fadeTimer?.invalidate()
        fadeTimer = nil
        
        DebugLog.log("🔄 resetFadeTimer() called - isFaded: \(isFaded)", category: .app)
        
        // If we were faded, show everything again
        if isFaded {
            DebugLog.log("🔄 Elements were faded, calling showAllElements()", category: .app)
            showAllElements()
        }
        
        // Start new timer
        fadeTimer = Timer.scheduledTimer(withTimeInterval: fadeDelay, repeats: false) { [weak self] _ in
            self?.fadeAllElements()
        }
        
        DebugLog.log("🎯 Fade timer reset - will fade in \(fadeDelay) seconds", category: .app)
    }
    
    func resetFadeTimerWithoutShowing() {
        if isAutoFadeSuspended {
            DebugLog.log("🛑 resetFadeTimerWithoutShowing() ignored - auto fade suspended", category: .app)
            return
        }

        // Cancel existing timer
        fadeTimer?.invalidate()
        fadeTimer = nil
        
        DebugLog.log("🔄 resetFadeTimerWithoutShowing() called - isFaded: \(isFaded)", category: .app)
        
        // Reset faded state since elements are being shown normally
        isFaded = false
        DebugLog.log("🔄 Reset isFaded to false", category: .app)
        
        // Don't show elements - just reset the timer
        // This is used when elements are already being shown normally
        
        // Start new timer
        fadeTimer = Timer.scheduledTimer(withTimeInterval: fadeDelay, repeats: false) { [weak self] _ in
            self?.fadeAllElements()
        }
        
        DebugLog.log("🎯 Fade timer reset (without showing) - will fade in \(fadeDelay) seconds", category: .app)
    }

    func suspendAutoFade() {
        guard !isAutoFadeSuspended else { return }
        DebugLog.log("🛑 Suspending auto fade", category: .app)
        isAutoFadeSuspended = true
        fadeTimer?.invalidate()
        fadeTimer = nil
        if isFaded {
            DebugLog.log("🔄 Auto fade suspended while faded - showing elements immediately", category: .app)
            showAllElements()
        }
    }

    func resumeAutoFade() {
        guard isAutoFadeSuspended else { return }
        DebugLog.log("▶️ Resuming auto fade", category: .app)
        isAutoFadeSuspended = false
        resetFadeTimer()
    }
    
    private func fadeAllElements() {
        if isAutoFadeSuspended {
            DebugLog.log("🛑 fadeAllElements() skipped - auto fade suspended", category: .app)
            return
        }
        
        guard !isFaded else { return }

        // Don't fade if user is actively interacting with any elements
        if hasActiveInteractions() {
            DebugLog.log("🔄 Skipping auto-fade due to active user interactions - rescheduling timer", category: .app)
            // Reschedule the fade timer to check again later
            fadeTimer?.invalidate()
            fadeTimer = Timer.scheduledTimer(withTimeInterval: fadeDelay, repeats: false) { [weak self] _ in
                self?.fadeAllElements()
            }
            return
        }
        
        isFaded = true
        DebugLog.log("🎯 Auto-fading all elements after \(fadeDelay) seconds of inactivity", category: .app)
        
        // Fade out semi-circle
        if let semiCircleWindow = semiCircleWindow {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                semiCircleWindow.animator().alphaValue = 0.0
            }
        }
        
        // Fade out task cards that are not pinned
        for (orbId, window) in taskCardWindows {
            if window.isVisible {
                if let taskCardView = window.contentView as? TaskCardView, taskCardView.getPinnedState() {
                    DebugLog.log("📌 Task card for orb \(orbId) is pinned - skipping fade", category: .tasks)
                } else {
                    if let taskCardView = window.contentView as? TaskCardView {
                        taskCardView.setAmbientAnimationActive(false)
                    }
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.5
                        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                        window.animator().alphaValue = 0.0
                    }
                }
            }
        }
        
        // Hide elements after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.semiCircleWindow?.orderOut(nil)
            self.semiCircleView?.setAnimationsActive(false)
            
            // Hide task cards that are not pinned
            var pinnedCards: [UUID: NSWindow] = [:]
            for (orbId, window) in self.taskCardWindows {
                if window.isVisible {
                    if let taskCardView = window.contentView as? TaskCardView, taskCardView.getPinnedState() {
                        DebugLog.log("📌 Task card for orb \(orbId) is pinned - keeping visible", category: .tasks)
                        pinnedCards[orbId] = window
                    } else {
                        window.orderOut(nil)
                    }
                }
            }
            
            // Update the task card windows to only include pinned ones
            self.taskCardWindows = pinnedCards
            self.currentOpenOrb = self.taskCardWindows.isEmpty ? nil : self.orbManager.orbs.first { self.taskCardWindows[$0.id] != nil }
            
            self.isSemiCircleVisible = false

            // Show notch base rim when fading
            if let notchView = self.notchIndicatorWindow?.contentView as? NotchIndicatorView {
                notchView.isSemiCircleVisible = false
                notchView.needsDisplay = true
            }
        }
    }
    
    private func showAllElements() {
        guard isFaded else { 
            DebugLog.log("🔄 showAllElements() called but isFaded is false, returning", category: .app)
            return 
        }
        
        isFaded = false
        DebugLog.log("🎯 Showing all elements due to user interaction - isFaded was true", category: .app)
        
        // Re-establish notification observers to ensure they're still active
        reestablishNotificationObservers()
        
        // Check if view hierarchy needs rebuilding
        if semiCircleView == nil || semiCircleView?.controller == nil {
            DebugLog.log("🔄 View hierarchy appears corrupted, rebuilding...", category: .app)
            rebuildViewHierarchy()
        }
        
        // Show semi-circle
        if let semiCircleWindow = semiCircleWindow {
            DebugLog.log("🔄 Showing semi-circle window", category: .app)
            semiCircleWindow.alphaValue = 1.0
            
            // Ensure the window can become key before making it key
            semiCircleWindow.level = .statusBar
            semiCircleWindow.acceptsMouseMovedEvents = true
            semiCircleWindow.ignoresMouseEvents = false
            
            // Make it visible first, then try to make it key
            semiCircleWindow.orderFront(nil)
            semiCircleView?.setAnimationsActive(true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if semiCircleWindow.canBecomeKey {
                    semiCircleWindow.makeKey()
                } else {
                    DebugLog.log("🔄 Window cannot become key, but will still receive mouse events", category: .app)
                }
            }
            
            isSemiCircleVisible = true

            // Hide notch base rim when showing all elements
            if let notchView = notchIndicatorWindow?.contentView as? NotchIndicatorView {
                notchView.isSemiCircleVisible = true
                notchView.needsDisplay = true
            }
        }
        
        // Show task cards if any were open (using new dynamic system)
        for (orbId, window) in taskCardWindows {
            if window.isVisible {
                if let taskCardView = window.contentView as? TaskCardView, taskCardView.getPinnedState() {
                    DebugLog.log("🔄 Showing pinned task card for orb \(orbId)", category: .tasks)
                    window.alphaValue = 1.0
                    window.makeKeyAndOrderFront(nil)
                    
                    // Ensure the window can receive mouse events
                    window.acceptsMouseMovedEvents = true
                    window.ignoresMouseEvents = false
                    taskCardView.setAmbientAnimationActive(true)
                }
            }
        }
        
        // Re-setup mouse tracking after showing elements with a longer delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Ensure the semi-circle view has a valid controller reference
            if let semiCircleView = self.semiCircleView {
                semiCircleView.controller = self
                DebugLog.log("🔄 Controller reference re-established for semi-circle view", category: .app)
            }
            
            self.semiCircleView?.setupMouseTracking()
            DebugLog.log("🖱️ Mouse tracking re-setup after showing all elements", category: .app)
            
            // Force a redraw to ensure everything is properly rendered
            self.semiCircleView?.needsDisplay = true
            
            // Test if the view is responsive
            self.testViewResponsiveness()
        }
    }
    
    func createNewProject(name: String) {
        // Validate and sanitize orb name using InputValidator
        let validatedName: String
        do {
            validatedName = try InputValidator.validateOrbName(name)
        } catch {
            DebugLog.logValidationError(error as! InputValidator.ValidationError, category: .app)
            DebugLog.log("Project creation failed due to validation error", category: .app)
            return
        }

        let sanitizedName = sanitizeOrbName(validatedName)
        DebugLog.log("🎯 Creating new project: \(sanitizedName)", category: .app)
        DebugLog.log("🎯 Current orb count before: \(orbManager.orbs.count)", category: .app)
        
        if let existing = findSimilarOrb(to: sanitizedName) {
            DebugLog.log("🎯 Found similar orb: \(existing.name) – pulsing instead of creating duplicate", category: .app)
            existing.badgePulse = max(existing.badgePulse, 1.1)
            existing.badgePulseDirection = 1.0
            existing.badgeRipplePhase = 0.0
            revealOverlayForVoice { [weak self] in
                self?.semiCircleView?.needsDisplay = true
            }
            return
        }
        
        let maxOrbs = UserDefaults.standard.integer(forKey: "maxOrbCount")
        let effectiveMax = maxOrbs > 0 ? maxOrbs : 6
        if orbManager.orbs.count >= effectiveMax {
            DebugLog.log("🎯 Maximum number of orbs (\(effectiveMax)) reached. Cannot create new project.", category: .app)
            showMaximumOrbsNotification(max: effectiveMax)
            return
        }
        
        let newOrb = orbManager.createOrb(name: sanitizedName)
        primeEmbedding(for: newOrb)
        DebugLog.log("🎯 Created orb '\(sanitizedName)' with taskCount: \(newOrb.taskCount)", category: .tasks)

        DebugLog.log("🎯 Current orb count after: \(orbManager.orbs.count)", category: .app)
        DebugLog.log("🎯 Semi-circle visible: \(isSemiCircleVisible)", category: .app)
        DebugLog.log("🎯 Semi-circle window visible: \(semiCircleWindow?.isVisible ?? false)", category: .app)
        
        if semiCircleWindow?.isVisible != true {
            DebugLog.log("🎯 Showing semi-circle for first time", category: .app)
            showSemiCircle()
        } else {
            DebugLog.log("🎯 Semi-circle already visible, orbs will reposition automatically", category: .app)
            semiCircleView?.needsDisplay = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.semiCircleView?.needsDisplay = true
            }
        }
        
    }

    private func sanitizeOrbName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        if trimmed.isEmpty { return "Untitled Project" }
        return trimmed.split(separator: " ").map { word in
            var lower = word.lowercased()
            if let first = lower.first {
                lower.replaceSubrange(lower.startIndex...lower.startIndex, with: String(first).uppercased())
            }
            return lower
        }.joined(separator: " ")
    }
    
    private func findSimilarOrb(to name: String) -> ProjectOrb? {
        guard !orbManager.orbs.isEmpty else { return nil }
        let target = name.lowercased()
        var candidate: (orb: ProjectOrb, distance: Int)?
        for orb in orbManager.orbs {
            let distance = levenshteinDistance(between: orb.name.lowercased(), and: target)
            if distance <= 2 {
                if let current = candidate {
                    if distance < current.distance {
                        candidate = (orb, distance)
                    }
                } else {
                    candidate = (orb, distance)
                }
            }
        }
        return candidate?.orb
    }
    
    private func levenshteinDistance(between lhs: String, and rhs: String) -> Int {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)
        let m = lhsChars.count
        let n = rhsChars.count
        if m == 0 { return n }
        if n == 0 { return m }
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }
        for i in 1...m {
            for j in 1...n {
                let cost = lhsChars[i - 1] == rhsChars[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }
        return matrix[m][n]
    }
    
    private func showMaximumOrbsNotification(max: Int) {
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }

            switch settings.authorizationStatus {
            case .authorized, .provisional:
                self.scheduleMaximumOrbsNotification(using: center, max: max)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
                    guard let self, granted else { return }
                    self.scheduleMaximumOrbsNotification(using: center, max: max)
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    private func scheduleMaximumOrbsNotification(using center: UNUserNotificationCenter, max: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Maximum Project Orbs Reached"
        content.body = "You can have up to \(max) project orbs. Remove an existing project to create a new one, or increase the limit in settings."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "NotchMaxProjectOrbs",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        
        center.add(request, withCompletionHandler: nil)
    }
    
    private func setupNotificationObservers() {
        // Remove any existing observers first to avoid duplicates
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("OrbClicked"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("TestNotification"), object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrbClicked(_:)),
            name: NSNotification.Name("OrbClicked"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTestNotification(_:)),
            name: NSNotification.Name("TestNotification"),
            object: nil
        )
        DebugLog.log("🎯 Notification observers setup complete", category: .app)
    }
    
    private func reestablishNotificationObservers() {
        DebugLog.log("🔄 Re-establishing notification observers", category: .app)
        setupNotificationObservers()
        
        // Test that the notification system is working
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            DebugLog.log("🔄 Testing notification system...", category: .app)
            // This is just a test to verify the observer is working
            NotificationCenter.default.post(name: NSNotification.Name("TestNotification"), object: nil)
        }
    }
    
    private func rebuildViewHierarchy() {
        DebugLog.log("🔄 Rebuilding view hierarchy due to potential corruption", category: .app)
        
        // Recreate the semi-circle view if it's corrupted
        if let semiCircleWindow = semiCircleWindow {
            let newSemiCircleView = SemiCircleWithOrbsView(orbManager: orbManager, controller: self)
            semiCircleWindow.contentView = newSemiCircleView
            self.semiCircleView = newSemiCircleView
            
            // Re-setup mouse tracking
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                newSemiCircleView.setupMouseTracking()
                DebugLog.log("🖱️ Mouse tracking re-setup after view hierarchy rebuild", category: .app)
            }
        }
    }
    
    @objc private func handleTestNotification(_ notification: Notification) {
        DebugLog.log("🔄 Test notification received - notification system is working", category: .app)
    }
    
    private func testViewResponsiveness() {
        guard let semiCircleView = semiCircleView else {
            DebugLog.log("🔄 ERROR: Semi-circle view is nil during responsiveness test", category: .app)
            return
        }
        
        DebugLog.log("🔄 Testing view responsiveness...", category: .app)
        DebugLog.log("🔄 View bounds: \(semiCircleView.bounds)", category: .app)
        DebugLog.log("🔄 View window: \(semiCircleView.window != nil)", category: .app)
        DebugLog.log("🔄 View acceptsFirstMouse: \(semiCircleView.acceptsFirstMouse(for: nil))", category: .app)
        DebugLog.log("🔄 View acceptsFirstResponder: \(semiCircleView.acceptsFirstResponder)", category: .app)
        DebugLog.log("🔄 View isHidden: \(semiCircleView.isHidden)", category: .app)
        DebugLog.log("🔄 View alphaValue: \(semiCircleView.alphaValue)", category: .app)
        
        // Test if we can post a test notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            DebugLog.log("🔄 Posting test notification to verify responsiveness...", category: .app)
            NotificationCenter.default.post(name: NSNotification.Name("TestNotification"), object: nil)
        }
    }
    
    @objc private func handleOrbClicked(_ notification: Notification) {
        DebugLog.log("🎯 handleOrbClicked called", category: .app)
        DebugLog.log("🎯 Notification object: \(String(describing: notification.object))", category: .app)
        DebugLog.log("🎯 Notification name: \(notification.name)", category: .app)
        
        guard let orb = notification.object as? ProjectOrb else {
            DebugLog.log("🚨 ERROR: Invalid orb object in notification", category: .app)
            return
        }
        
        DebugLog.log("🎯 Received orb click notification for: \(orb.name)", category: .app)
        DebugLog.log("🎯 Current open orb: \(currentOpenOrb?.name ?? "none")", category: .app)
        
        // Reset auto-fade timer on orb interaction
        DebugLog.log("🎯 Calling resetFadeTimer()", category: .app)
        resetFadeTimer()
        
        DebugLog.log("🎯 Calling showTaskCard()", category: .app)
        showTaskCard(for: orb)
        DebugLog.log("🎯 showTaskCard() completed", category: .app)
    }
    
    internal func showSemiCircle(completion: (() -> Void)? = nil) {
        guard let window = semiCircleWindow else { 
            DebugLog.log("🚨 ERROR: semiCircleWindow is nil!", category: .app)
            completion?()
            return 
        }
        
        if isSemiCircleVisible {
            windowManager.positionSemiCircle(window)
            window.alphaValue = 1.0
            window.orderFront(nil)
            // Re-animate orbs when re-showing an already visible semi-circle
            if orbManager.visibleOrbCount == 0 {
                orbManager.showOrbs {
                    self.semiCircleView?.needsDisplay = true
                    completion?()
                }
            } else {
                // Orbs already visible, just trigger animation again
                orbManager.hideOrbs()
                orbManager.showOrbs {
                    self.semiCircleView?.needsDisplay = true
                    completion?()
                }
            }
            semiCircleView?.setAnimationsActive(true)
            resetFadeTimerWithoutShowing()
            return 
        }
        
        DebugLog.log("🎯 showSemiCircle() called", category: .app)
        DebugLog.log("🎯 Window frame: \(window.frame)", category: .app)
        DebugLog.log("🎯 Window level: \(window.level.rawValue)", category: .app)
        DebugLog.log("🎯 Window isVisible: \(window.isVisible)", category: .app)

        // Reset orbs to invisible before first show animation
        orbManager.hideOrbs()
        
        // Ensure window is positioned correctly before animation
        windowManager.positionSemiCircle(window)
        
        // Start with semi-circle hidden and scaled down from center top
        let finalFrame = window.frame
        let centerTopX = finalFrame.midX
        let centerTopY = finalFrame.maxY
        
        // Start with tiny frame at center top
        let startFrame = NSRect(x: centerTopX - 5, y: centerTopY - 5, width: 10, height: 10)
        window.setFrame(startFrame, display: false)
        window.alphaValue = 0.0
        
        // Ensure proper window level and mouse event handling
        window.level = .statusBar
        window.acceptsMouseMovedEvents = true
        window.ignoresMouseEvents = false
        
        // Make it visible first, then try to make it key
        window.orderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if window.canBecomeKey {
                window.makeKey()
            } else {
                DebugLog.log("🔄 Window cannot become key in showSemiCircle, but will still receive mouse events", category: .app)
            }
        }
        
        DebugLog.log("🎯 Window made key and ordered front", category: .app)
        DebugLog.log("🎯 Window isVisible after makeKeyAndOrderFront: \(window.isVisible)", category: .app)
        
        // Mark as visible
        isSemiCircleVisible = true
        semiCircleView?.setAnimationsActive(true)

        // Hide notch base rim when semi-circle is visible
        if let notchView = notchIndicatorWindow?.contentView as? NotchIndicatorView {
            notchView.isSemiCircleVisible = true
            notchView.needsDisplay = true
        }
        
        // Animate expansion from center top
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.6
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0)
            
            // Animate both frame expansion and fade in
            window.animator().setFrame(finalFrame, display: true)
            window.animator().alphaValue = 1.0
        } completionHandler: {
            // Show orbs after semi-circle appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                DebugLog.log("🔄 About to show orbs - isFaded: \(self.isFaded)", category: .app)
                self.orbManager.showOrbs {
                    DebugLog.log("🔄 Orbs shown", category: .app)
                // Force redraw of the semi-circle view
                self.semiCircleView?.needsDisplay = true
                    completion?()
                }
                
                // Set up mouse tracking after everything is visible
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.semiCircleView?.setupMouseTracking()
                    DebugLog.log("🖱️ Mouse tracking setup attempted after semi-circle show", category: .app)
                    
                    // Start auto-fade timer after everything is fully loaded
                    self.resetFadeTimerWithoutShowing()
                }
            }
        }
    }
    
    internal func getNotchInfo(for screen: NSScreen) -> (width: CGFloat, height: CGFloat, centerX: CGFloat, safeAreaTop: CGFloat) {
        let screenFrame = screen.frame
        let safeAreaInsets = screen.safeAreaInsets
        let safeAreaTop = safeAreaInsets.top
        
        // Check if this screen actually has a notch
        if !screen.hasTopNotchDesign {
            DebugLog.log("🔍 No notch detected on this screen", category: .app)
            return (width: 0, height: 0, centerX: screenFrame.midX, safeAreaTop: 0)
        }
        
        // Try to get the actual notch width by looking at the safe area insets
        // The notch creates a "cutout" in the top of the screen
        
        // Use manual dimensions as specified - make wider by 12px + 7px + 4px each side, then reduce by 1px from left
        let notchWidth: CGFloat = 145 + 24 + 14 + 8 - 1 // 12px + 7px + 4px each side - 1px from left = 45px total
        let notchHeight: CGFloat = 45
        
        // Calculate notch center position - try different approaches
        let centerX = screenFrame.midX
        
        // Let's also try the screen's actual center point
        let screenCenter = CGPoint(x: screenFrame.midX, y: screenFrame.midY)
        DebugLog.log("Screen center point: \(screenCenter)", category: .app)
        
        DebugLog.log("🔍 Screen Frame Info:", category: .app)
        DebugLog.log("Screen frame: \(screenFrame)", category: .app)
        DebugLog.log("Visible frame: \(screen.visibleFrame)", category: .app)
        DebugLog.log("Screen midX: \(screenFrame.midX)", category: .app)
        DebugLog.log("Visible midX: \(screen.visibleFrame.midX)", category: .app)
        
        DebugLog.log("🔍 Proper Notch Detection:", category: .app)
        DebugLog.log("Screen frame: \(screenFrame)", category: .app)
        DebugLog.log("Safe area insets: \(safeAreaInsets)", category: .app)
        DebugLog.log("Has notch: \(screen.hasTopNotchDesign)", category: .app)
        DebugLog.log("Notch width: \(notchWidth)px", category: .app)
        DebugLog.log("Notch height: \(notchHeight)px", category: .app)
        DebugLog.log("Notch center X: \(centerX)px", category: .app)
        
        return (
            width: notchWidth,
            height: notchHeight,
            centerX: centerX,
            safeAreaTop: safeAreaTop
        )
    }
    
}

// MARK: - Notch Indicator View

// MARK: - Semi-Circle View
class SemiCircleView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Clear background
        context.clear(dirtyRect)
        
        // Create semi-circle path - positioned to look like it's coming from notch
        let centerX = bounds.midX
        let centerY = bounds.maxY - 20 // Move center up so arc starts from top
        let radius = min(bounds.width, bounds.height) / 2 + 20 // Bigger radius
        
        let path = CGMutablePath()
        // Create a wider arc that looks like it's emerging from the notch
        path.addArc(center: CGPoint(x: centerX, y: centerY), 
                   radius: radius, 
                   startAngle: 0, // Start at 0 degrees
                   endAngle: 2 * .pi, // Full circle (360 degrees)
                   clockwise: false)
        path.closeSubpath()
        
        // Fill with black
        context.setFillColor(NSColor.black.cgColor)
        context.addPath(path)
        context.fillPath()
        
        // Add subtle shadow
        context.setShadow(offset: CGSize(width: 0, height: -5), blur: 10, color: NSColor.black.withAlphaComponent(0.3).cgColor)
        context.addPath(path)
        context.fillPath()
    }
}

    // MARK: - Semi-Circle with Orbs View
// Implementation moved to `Views/SemiCircleWithOrbsView.swift`.

// MARK: - TaskCardWindow
class TaskCardWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
}

// MARK: - TaskDetailWindow
class TaskDetailWindow: NSWindow {
    var isPinned: Bool = false
    weak var taskDetailView: TaskDetailView?

    override var canBecomeKey: Bool {
            return true
        }
        
    override var canBecomeMain: Bool {
            return true
        }
        
    override func keyDown(with event: NSEvent) {
        // Space - Toggle task complete
        if event.keyCode == 49 && !event.modifierFlags.contains(.command) { // Space key
            taskDetailView?.toggleTaskCompletion()
                    return 
                }
                
        // Cmd+W or Esc - Close window
        if (event.modifierFlags.contains(.command) && event.keyCode == 13) || event.keyCode == 53 {
            taskDetailView?.requestClose()
            return 
        }
        
        super.keyDown(with: event)
    }
}
