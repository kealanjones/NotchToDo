import QuartzCore
import Cocoa
import AVFoundation

// MARK: - Task Card View
class TaskCardView: NSView, FrameUpdatable {
    private struct DropAnimationState {
        var offset: SpringValue
        var scale: SpringValue

        mutating func advance(by deltaTime: CFTimeInterval) -> Bool {
            let offsetAnimating = offset.update(deltaTime: deltaTime)
            let scaleAnimating = scale.update(deltaTime: deltaTime)
            return offsetAnimating || scaleAnimating || !isAtRest
        }

        var offsetValue: CGFloat { offset.value }
        var scaleValue: CGFloat { scale.value }

        var isAtRest: Bool {
            offset.isAtRest && scale.isAtRest
        }
    }

    private var tasks: [Task] = []
    private var searchQuery: String = ""
    private var isSearchActive: Bool = false
    private var searchFieldRect = NSRect.zero
    private var projectName: String = ""
    private var orbColor: NSColor = .systemBlue
    private var animationPhase: Double = 0.0
    private weak var controller: NotchOverlayController?
    private let celebrationManager = CelebrationManager.shared

    // Text size scale factor
    private var textScale: CGFloat {
        return TextSizePreference.scaleFactor
    }

    // Computed filtered tasks based on search
    private var filteredTasks: [Task] {
        guard !searchQuery.isEmpty else { return tasks }
        return tasks.filter { task in
            task.title.localizedCaseInsensitiveContains(searchQuery) ||
            task.details.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    private let glassEffectView = PassthroughVisualEffectView()
    private let baseShadowRadius: CGFloat = 12.0
    private let baseShadowOffset = CGSize(width: 0, height: -2)
    private let baseShadowOpacity: Float = 0.55
    private var cardLiftSpring = SpringValue(
        value: 0.0,
        target: 0.0,
        stiffness: 220.0,
        damping: 26.0,
        threshold: 0.0005
    )
    
    // Pin functionality
    private var isPinned = false
    private var pinButtonRect = NSRect.zero
    private var isHoveringPin = false
    private var deleteButtonRect = NSRect.zero
    private var isHoveringDelete = false
    
    // Close button functionality
    private var closeButtonRect = NSRect.zero
    private var isHoveringClose = false
    
    // Card hover state
    private var isHoveringCard = false

    // Card dragging
    private var isDraggingCard = false
    private var dragStartScreenLocation = NSPoint.zero
    private var initialWindowOrigin = NSPoint.zero
    
    // Task drag and drop functionality
    private var isDraggingTask = false
    private var draggedTask: Task?
    private var draggedTaskIndex: Int = -1
    private var taskDragStartLocation = NSPoint.zero
    private var rowGeometries: [TaskRowGeometry] = []
    var isShowingDropIndicator = false
    
    // Scroll functionality
    private var taskScrollOffset: CGFloat = 0
    private var maxScrollOffset: CGFloat = 0
    private var scrollBarRect = NSRect.zero
    private var isHoveringScrollBar = false
    
    // Highlight for newly added tasks
    private var highlightedTaskID: UUID?
    private var highlightAlpha: CGFloat = 0.0
    private var highlightSpring = SpringValue(
        value: 0.0,
        target: 0.0,
        stiffness: 210.0,
        damping: 26.0,
        threshold: 0.0005
    )
    private var dropAnimations: [UUID: DropAnimationState] = [:]

    private var dragWindowSpringX = SpringValue(value: 0.0, target: 0.0, stiffness: 220.0, damping: 28.0, threshold: 0.001)
    private var dragWindowSpringY = SpringValue(value: 0.0, target: 0.0, stiffness: 220.0, damping: 28.0, threshold: 0.001)
    private var isDragWindowSpringActive = false

    private var scrollOffsetSpring = SpringValue(value: 0.0, target: 0.0, stiffness: 170.0, damping: 24.0, threshold: 0.0005)
    private var isScrollSpringActive = false

    private var dragGripRect = NSRect.zero
    private var isHoveringDragGrip = false
    private var currentOrbId: UUID?
    
    // Celebration animation properties
    private var celebrationPhase: CGFloat = 0.0
    private var isCelebrating = false

    // Task completion animation
    private var completionAnimations: [UUID: CGFloat] = [:]
    private var isAmbientAnimationActive = false
    private var isTickerRegistered = false

    // Checkbox pop animation
    private var checkboxPopAnimations: [UUID: SpringValue] = [:]
    
    // Resize functionality
    private var isResizing = false
    private var resizeStartLocation = NSPoint.zero
    private var resizeStartSize = NSSize.zero
    private var resizeHandleRect = NSRect.zero
    private var isHoveringResizeHandle = false
    
    private func currentDragRect() -> NSRect {
        if dragGripRect != .zero {
            return dragGripRect
        }
        let cardRect = bounds.insetBy(dx: TaskRowMetrics.cardInset, dy: TaskRowMetrics.cardInset)
        let fallbackHeight = TaskRowMetrics.controlBarHeight + 12.0
        return NSRect(
            x: cardRect.minX + 16,
            y: cardRect.maxY - fallbackHeight,
            width: cardRect.width - 32,
            height: fallbackHeight
        )
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = 28
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.22).cgColor
        layer?.shadowOpacity = baseShadowOpacity
        layer?.shadowOffset = baseShadowOffset
        layer?.shadowRadius = baseShadowRadius
        setupDragTracking()
        configureGlassEffect()
        applyCardLiftShadow()
        setupTextSizeObserver()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = 28
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.22).cgColor
        layer?.shadowOpacity = baseShadowOpacity
        layer?.shadowOffset = baseShadowOffset
        layer?.shadowRadius = baseShadowRadius
        setupDragTracking()
        configureGlassEffect()
        applyCardLiftShadow()
        setupTextSizeObserver()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .textSizeDidChange, object: nil)
    }

    private func setupTextSizeObserver() {
        NotificationCenter.default.addObserver(
            forName: .textSizeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.needsDisplay = true
        }
    }
    
    func updateTasks(_ tasks: [Task], projectName: String, orbColor: NSColor, orbId: UUID) {
        self.tasks = tasks
        self.projectName = projectName
        self.orbColor = orbColor
        self.currentOrbId = orbId
        scrollOffsetSpring.snap(to: taskScrollOffset)
        scrollOffsetSpring.setTarget(taskScrollOffset)
        isScrollSpringActive = false
        self.needsDisplay = true
    }
    
    func currentOrbIdentifier() -> UUID? {
        currentOrbId
    }
    
    func highlightTask(_ task: Task) {
        highlightedTaskID = task.id
        highlightSpring.snap(to: 1.0)
        highlightSpring.setTarget(0.0)
        highlightAlpha = 1.0
        if dropAnimations[task.id] == nil {
            animateTaskDrop(task, verticalTravel: 24.0)
        }
        updateTickerSubscription()
        needsDisplay = true
    }

    func animateTaskDrop(_ task: Task, verticalTravel: CGFloat) {
        guard tasks.contains(where: { $0.id == task.id }) else { return }

        let initialOffset = max(min(verticalTravel, 80.0), -80.0)
        let offsetSpring = SpringValue(
            value: initialOffset,
            target: 0.0,
            stiffness: 240.0,
            damping: 28.0,
            threshold: 0.001
        )
        let scaleSpring = SpringValue(
            value: 1.08,
            target: 1.0,
            stiffness: 210.0,
            damping: 26.0,
            threshold: 0.001
        )

        dropAnimations[task.id] = DropAnimationState(offset: offsetSpring, scale: scaleSpring)
        updateTickerSubscription()
        needsDisplay = true
    }

    func setController(_ controller: NotchOverlayController?) {
        self.controller = controller
    }
    
    func setAmbientAnimationActive(_ isActive: Bool) {
        isAmbientAnimationActive = isActive
        updateTickerSubscription()
    }
    
    private func completionAnimationValues(for progress: CGFloat) -> (scale: CGFloat, opacity: CGFloat) {
        let clamped = max(0.0, min(1.0, progress))
        let scaleProgress = clamped * 2.0
        let scale: CGFloat
        if scaleProgress <= 1.0 {
            scale = 1.0 + (0.05 * scaleProgress)
        } else {
            scale = 1.05 - (0.05 * (scaleProgress - 1.0))
        }
        let opacity = 1.0 - (0.5 * clamped)
        return (scale, opacity)
    }

    private func updateCardLiftTarget() {
        var target: CGFloat = 0.0
        if isDraggingCard {
            target = 1.0
        } else if isHoveringCard {
            target = isPinned ? 0.45 : 0.35
        } else if isPinned {
            target = 0.2
        }
        cardLiftSpring.setTarget(target)
        applyCardLiftShadow()
        updateTickerSubscription()
    }

    private func applyCardLiftShadow() {
        guard let layer else { return }
        let lift = max(0.0, min(1.0, cardLiftSpring.value))
        let shadowAlpha = min(1.0, CGFloat(baseShadowOpacity) + 0.25 * lift)
        let shadowRadius = baseShadowRadius + 10.0 * lift
        let shadowOffset = CGSize(width: baseShadowOffset.width, height: baseShadowOffset.height - (6.0 * lift))
        layer.shadowRadius = shadowRadius
        layer.shadowOpacity = Float(shadowAlpha)
        layer.shadowOffset = shadowOffset
        layer.shadowColor = NSColor.black.withAlphaComponent(0.22 + 0.18 * lift).cgColor
        layer.setAffineTransform(CGAffineTransform(translationX: 0, y: 2.0 * lift))
    }
    
    private func updateTickerSubscription() {
        let highlightActive = highlightedTaskID != nil || !highlightSpring.isAtRest || highlightAlpha > 0.001
        let dropActive = dropAnimations.contains { !$0.value.isAtRest }
        let dragWindowActive = isDragWindowSpringActive || isDraggingTask
        let scrollSpringActive = isScrollSpringActive || !scrollOffsetSpring.isAtRest
        let liftActive = isDraggingCard || !cardLiftSpring.isAtRest
        let hasParticles = celebrationManager.hasActiveEffects
        let hasCheckboxPops = !checkboxPopAnimations.isEmpty
        let shouldObserve = isAmbientAnimationActive || highlightActive || isCelebrating || !completionAnimations.isEmpty || dropActive || dragWindowActive || scrollSpringActive || liftActive || hasParticles || hasCheckboxPops
        if shouldObserve && !isTickerRegistered {
            FrameTicker.shared.addObserver(self)
            isTickerRegistered = true
        } else if !shouldObserve && isTickerRegistered {
            FrameTicker.shared.removeObserver(self)
            isTickerRegistered = false
        }
    }
    
    func frameTick(deltaTime: CFTimeInterval) {
        DebugLog.log("📊 frameTick called - deltaTime: \(deltaTime), isScrollSpringActive: \(isScrollSpringActive)", category: .tasks)
        var requiresDisplay = false
        
        if isAmbientAnimationActive {
            animationPhase += deltaTime * 0.6
            requiresDisplay = true
        }
        
        if highlightedTaskID != nil || highlightAlpha > 0.0 || !highlightSpring.isAtRest {
            let previousAlpha = highlightAlpha
            _ = highlightSpring.update(deltaTime: deltaTime)
            highlightAlpha = max(0.0, min(1.0, highlightSpring.value))
            if abs(previousAlpha - highlightAlpha) > 0.0001 {
                requiresDisplay = true
            }
            if highlightSpring.isAtRest && highlightSpring.value <= 0.0 {
                highlightAlpha = 0.0
                highlightedTaskID = nil
            }
        }

        if isCelebrating {
            celebrationPhase += CGFloat(deltaTime * 6.0)
            if celebrationPhase >= 18.0 {
                endCelebrationAnimation()
            }
            requiresDisplay = true
        }
        
        if !completionAnimations.isEmpty {
            let increment = CGFloat(deltaTime / 0.3)
            var updatedAnimations: [UUID: CGFloat] = [:]
            for (id, progress) in completionAnimations {
                let newProgress = min(1.0, progress + increment)
                if newProgress < 1.0 {
                    updatedAnimations[id] = newProgress
                }
            }
            completionAnimations = updatedAnimations
            requiresDisplay = true
        }

        // Update checkbox pop animations
        if !checkboxPopAnimations.isEmpty {
            var activeAnimations: [UUID: SpringValue] = [:]
            for (id, var spring) in checkboxPopAnimations {
                _ = spring.update(deltaTime: deltaTime)
                if !spring.isAtRest {
                    activeAnimations[id] = spring
                } else {
                    activeAnimations.removeValue(forKey: id)
                }
            }
            checkboxPopAnimations = activeAnimations
            if !checkboxPopAnimations.isEmpty {
                requiresDisplay = true
            }
        }

        if !dropAnimations.isEmpty {
            var activeAnimations: [UUID: DropAnimationState] = [:]
            for (id, var animation) in dropAnimations {
                let previousOffset = animation.offsetValue
                let previousScale = animation.scaleValue
                _ = animation.advance(by: deltaTime)
                if abs(previousOffset - animation.offsetValue) > 0.0001 || abs(previousScale - animation.scaleValue) > 0.0001 {
                    requiresDisplay = true
                }
                if !animation.isAtRest {
                    activeAnimations[id] = animation
                }
            }
            dropAnimations = activeAnimations
        }

        if isScrollSpringActive || !scrollOffsetSpring.isAtRest {
            DebugLog.log("📊 Scroll spring update - active: \(isScrollSpringActive), atRest: \(scrollOffsetSpring.isAtRest)", category: .tasks)
            let previousValue = scrollOffsetSpring.value
            let stillAnimating = scrollOffsetSpring.update(deltaTime: deltaTime)
            let clamped = max(0.0, min(scrollOffsetSpring.value, maxScrollOffset))
            DebugLog.log("📊 Spring values - previous: \(previousValue), current: \(scrollOffsetSpring.value), clamped: \(clamped), taskScrollOffset: \(taskScrollOffset), maxScrollOffset: \(maxScrollOffset)", category: .tasks)
            if abs(previousValue - clamped) > 0.0001 || abs(taskScrollOffset - clamped) > 0.0001 {
                DebugLog.log("📊 Updating taskScrollOffset from \(taskScrollOffset) to \(clamped), setting requiresDisplay=true", category: .tasks)
                taskScrollOffset = clamped
                requiresDisplay = true
            } else {
                DebugLog.log("📊 No offset change needed (diff too small)", category: .tasks)
            }
            isScrollSpringActive = stillAnimating || !scrollOffsetSpring.isAtRest
            DebugLog.log("📊 After update - stillAnimating: \(stillAnimating), isScrollSpringActive: \(isScrollSpringActive)", category: .tasks)
        }

        if (isDragWindowSpringActive || isDraggingTask), let dragWindow = controller?.draggedTaskWindow {
            let xAnimating = dragWindowSpringX.update(deltaTime: deltaTime)
            let yAnimating = dragWindowSpringY.update(deltaTime: deltaTime)
            dragWindow.setFrameOrigin(NSPoint(x: dragWindowSpringX.value, y: dragWindowSpringY.value))
            isDragWindowSpringActive = xAnimating || yAnimating || isDraggingTask
        } else if !isDraggingTask {
            isDragWindowSpringActive = false
        }

        let previousLift = cardLiftSpring.value
        let liftAnimating = cardLiftSpring.update(deltaTime: deltaTime)
        if liftAnimating || abs(cardLiftSpring.value - previousLift) > 0.0001 {
            applyCardLiftShadow()
        }

        // Update celebration effects (particles, ripples)
        if celebrationManager.hasActiveEffects {
            celebrationManager.update(deltaTime: deltaTime)
            requiresDisplay = true
        }

        if requiresDisplay || liftAnimating {
            DebugLog.log("📊 Setting needsDisplay=true (requiresDisplay: \(requiresDisplay), liftAnimating: \(liftAnimating))", category: .tasks)
            needsDisplay = true
        } else {
            DebugLog.log("📊 NOT setting needsDisplay (requiresDisplay: \(requiresDisplay), liftAnimating: \(liftAnimating))", category: .tasks)
        }

        updateTickerSubscription()
    }
    
    override func layout() {
        super.layout()
        let cardRect = bounds.insetBy(dx: TaskRowMetrics.cardInset, dy: TaskRowMetrics.cardInset)
        glassEffectView.frame = cardRect
        glassEffectView.layer?.cornerRadius = 24  // Match TaskDetailView
    }
    
    override var isOpaque: Bool {
        return false
    }
    
    func getPinnedState() -> Bool {
        return isPinned
    }

    func getSearchActiveState() -> Bool {
        return isSearchActive
    }

    func setPinned(_ pinned: Bool) {
        isPinned = pinned
        needsDisplay = true
        updateCardLiftTarget()
    }
    
    private func togglePin() {
        isPinned.toggle()
        needsDisplay = true
        updateCardLiftTarget()
        controller?.taskCardPinStateChanged(isPinned: isPinned)
    }
    
    private func closeTaskCard() {
        if isPinned {
            isPinned = false
            controller?.taskCardPinStateChanged(isPinned: false)
        }
        needsDisplay = true
        updateCardLiftTarget()
        // Notify controller to close this specific task card
        controller?.closeTaskCard(for: self)
    }

    // MARK: - Export Tasks

    private func exportTasks() {
        guard !tasks.isEmpty else {
            showExportError("No tasks to export")
            return
        }

        let alert = NSAlert()
        alert.messageText = "Export \"\(projectName)\" Tasks"
        alert.informativeText = "Choose export format:"
        alert.addButton(withTitle: "Text (.txt)")
        alert.addButton(withTitle: "Markdown (.md)")
        alert.addButton(withTitle: "JSON (.json)")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            saveExportFile(content: exportAsText(), fileExtension: "txt", fileType: "Text")
        case .alertSecondButtonReturn:
            saveExportFile(content: exportAsMarkdown(), fileExtension: "md", fileType: "Markdown")
        case .alertThirdButtonReturn:
            saveExportFile(content: exportAsJSON(), fileExtension: "json", fileType: "JSON")
        default:
            break
        }
    }

    private func exportAsText() -> String {
        var output = "\(projectName)\n"
        output += String(repeating: "=", count: projectName.count) + "\n\n"

        for (index, task) in tasks.enumerated() {
            let status = task.isCompleted ? "[✓]" : "[ ]"
            output += "\(index + 1). \(status) \(task.title)\n"
            if !task.details.isEmpty {
                output += "   \(task.details)\n"
            }
            output += "\n"
        }

        output += "\nTotal: \(tasks.count) tasks (\(tasks.filter { $0.isCompleted }.count) completed)\n"
        return output
    }

    private func exportAsMarkdown() -> String {
        var output = "# \(projectName)\n\n"

        for task in tasks {
            let checkbox = task.isCompleted ? "[x]" : "[ ]"
            output += "- \(checkbox) \(task.title)\n"
            if !task.details.isEmpty {
                output += "  > \(task.details)\n"
            }
        }

        output += "\n---\n"
        output += "*Total: \(tasks.count) tasks (\(tasks.filter { $0.isCompleted }.count) completed)*\n"
        return output
    }

    private func exportAsJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let exportData: [String: Any] = [
            "project": projectName,
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "totalTasks": tasks.count,
            "completedTasks": tasks.filter { $0.isCompleted }.count,
            "tasks": tasks.map { task in
                [
                    "id": task.id.uuidString,
                    "title": task.title,
                    "details": task.details,
                    "isCompleted": task.isCompleted,
                    "sortOrder": task.sortOrder
                ]
            }
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }

        return "{}"
    }

    private func saveExportFile(content: String, fileExtension: String, fileType: String) {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "\(projectName).\(fileExtension)"
        savePanel.allowedContentTypes = [.init(filenameExtension: fileExtension)!]
        savePanel.message = "Export \(fileType) file"

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }

            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                self.showExportSuccess()
            } catch {
                self.showExportError("Failed to save file: \(error.localizedDescription)")
            }
        }
    }

    private func showExportSuccess() {
        let alert = NSAlert()
        alert.messageText = "Export Successful"
        alert.informativeText = "Tasks exported successfully!"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showExportError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Export Failed"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Task Drag and Drop
    
    private func rowGeometry(at location: NSPoint) -> TaskRowGeometry? {
        return rowGeometries.first { $0.rowRect.contains(location) }
    }
    
    private func getClickedTaskIndex(at location: NSPoint) -> Int? {
        return rowGeometry(at: location)?.index
    }
    
    private func getClickedGrabHandleIndex(at location: NSPoint) -> Int? {
        return rowGeometries.first { $0.dragRect.contains(location) }?.index
    }
    
    private func getClickedCheckboxIndex(at location: NSPoint) -> Int? {
        return rowGeometries.first { $0.checkboxRect.contains(location) }?.index
    }
    
    private func toggleTaskCompletion(at index: Int) {
        guard index < tasks.count else { return }

        let task = tasks[index]
        let wasCompleted = task.isCompleted
        task.isCompleted.toggle()

        // Trigger checkbox pop animation
        triggerCheckboxPop(for: task)

        // Trigger completion animation if task was just completed
        if !wasCompleted && task.isCompleted {
            startTaskCompletionAnimation(for: task)
            startCelebrationAnimation()

            // Trigger celebration effects at checkbox location
            if let geometry = rowGeometries.first(where: { $0.index == index }) {
                let checkboxCenter = CGPoint(
                    x: geometry.checkboxRect.midX,
                    y: geometry.checkboxRect.midY
                )
                celebrationManager.celebrateTaskCompletion(at: checkboxCenter, color: orbColor)
                updateTickerSubscription() // Keep animations running for particles
            }

            // Notify controller to trigger orb dancing
            controller?.triggerOrbCelebration()
        } else if wasCompleted && !task.isCompleted {
            // Reset animation state when uncompleting
            completionAnimations.removeValue(forKey: task.id)

            // Trigger undo effect at checkbox location
            if let geometry = rowGeometries.first(where: { $0.index == index }) {
                let checkboxCenter = CGPoint(
                    x: geometry.checkboxRect.midX,
                    y: geometry.checkboxRect.midY
                )
                celebrationManager.celebrateUndo(at: checkboxCenter)
                updateTickerSubscription() // Keep animations running for particles
            }
        }

        // Recalculate scroll in case task visibility changed
        calculateMaxScrollOffset()
        needsDisplay = true

        DebugLog.log("Task \(task.title) marked as \(task.isCompleted ? "completed" : "incomplete")", category: .tasks)
    }

    private func triggerCheckboxPop(for task: Task) {
        // Create a spring that bounces from 1.3 back to 1.0
        var spring = SpringValue(value: 1.0, target: 1.3, stiffness: 400.0, damping: 20.0, threshold: 0.001)
        spring.snap(to: 1.3)
        spring.setTarget(1.0)
        checkboxPopAnimations[task.id] = spring
        updateTickerSubscription()
    }
    
    private func startTaskCompletionAnimation(for task: Task) {
        completionAnimations[task.id] = 0.0
        updateTickerSubscription()
        needsDisplay = true
    }
    
    private func openTaskDetail(for index: Int) {
        guard index < tasks.count else {
            DebugLog.log("❌ openTaskDetail: index \(index) out of range (tasks.count: \(tasks.count))", category: .tasks)
            return
        }

        let task = tasks[index]
        DebugLog.log("✅ openTaskDetail: calling controller?.showTaskDetail for task '\(task.title)'", category: .tasks)
        controller?.showTaskDetail(for: task, orbColor: orbColor)
    }
    
    private func startCelebrationAnimation() {
        guard !isCelebrating else { return }
        
        isCelebrating = true
        celebrationPhase = 0.0
        updateTickerSubscription()
        needsDisplay = true
        
        DebugLog.log("Starting celebration animation", category: .tasks)
    }
    
    private func endCelebrationAnimation() {
        isCelebrating = false
        celebrationPhase = 0.0
        updateTickerSubscription()
        
        DebugLog.log("Celebration animation ended", category: .tasks)
    }
    
    private func drawCelebrationRimGlow(in context: CGContext, cardRect: NSRect) {
        context.saveGState()
        
        // Create massive soft glow from edges outward
        let glowSize: CGFloat = 60.0  // Massive glow extending far out
        let glowRect = cardRect.insetBy(dx: -glowSize, dy: -glowSize)
        
        // Create multiple layers of rainbow glow
        let layerCount = 12
        let maxIntensity = 0.8 + 0.4 * sin(celebrationPhase)
        
        // Rainbow colors for cycling effect
        let colors: [NSColor] = [
            .systemRed, .systemOrange, .systemYellow, .systemGreen,
            .systemBlue, .systemPurple, .systemPink, .systemTeal,
            .systemIndigo, .systemMint, .systemBrown, .systemGray
        ]
        
        for layer in 0..<layerCount {
            let layerProgress = CGFloat(layer) / CGFloat(layerCount - 1)
            let layerSize = glowSize * layerProgress
            let currentGlowRect = cardRect.insetBy(dx: -layerSize, dy: -layerSize)
            
            // Calculate color cycling through the celebration phase
            let colorIndex = (Int(celebrationPhase * 3) + layer) % colors.count
            let baseColor = colors[colorIndex]
            
            // Create soft gradient from edge outward
            let alpha = maxIntensity * (1.0 - layerProgress) * (1.0 - layerProgress)
            let color1 = baseColor.withAlphaComponent(alpha)
            let color2 = baseColor.withAlphaComponent(alpha * 0.3)
            let color3 = NSColor.clear
            
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: [color1.cgColor, color2.cgColor, color3.cgColor] as CFArray,
                                       locations: [0.0, 0.4, 1.0]) {
                
                // Draw gradient from card edge outward
                let path = NSBezierPath(roundedRect: currentGlowRect, xRadius: 28 + layerSize, yRadius: 28 + layerSize)
                path.addClip()
                
                context.drawLinearGradient(gradient,
                                         start: CGPoint(x: cardRect.minX, y: cardRect.midY),
                                         end: CGPoint(x: cardRect.minX - layerSize, y: cardRect.midY),
                                         options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                
                context.drawLinearGradient(gradient,
                                         start: CGPoint(x: cardRect.maxX, y: cardRect.midY),
                                         end: CGPoint(x: cardRect.maxX + layerSize, y: cardRect.midY),
                                         options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                
                context.drawLinearGradient(gradient,
                                         start: CGPoint(x: cardRect.midX, y: cardRect.minY),
                                         end: CGPoint(x: cardRect.midX, y: cardRect.minY - layerSize),
                                         options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                
                context.drawLinearGradient(gradient,
                                         start: CGPoint(x: cardRect.midX, y: cardRect.maxY),
                                         end: CGPoint(x: cardRect.midX, y: cardRect.maxY + layerSize),
                                         options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
        }
        
        context.restoreGState()
    }
    
    private func startTaskDrag(taskIndex: Int, location: NSPoint) {
        guard taskIndex < tasks.count else { return }
        
        isDraggingTask = true
        draggedTask = tasks[taskIndex]
        draggedTaskIndex = taskIndex
        taskDragStartLocation = location
        
        // Create floating drag window
        createDragWindow(for: tasks[taskIndex])
        
        // Change cursor to indicate task dragging
        NSCursor.closedHand.set()
        
        // Reset fade timer
        if !isPinned {
            controller?.resetFadeTimer()
        }
        
        DebugLog.log("Started dragging task: \(tasks[taskIndex].title)", category: .tasks)
    }
    
    private func createDragWindow(for task: Task) {
        // Create a floating window for the dragged task (1.1x scale)
        let baseWidth: CGFloat = 260
        let baseHeight: CGFloat = 35
        let scaleFactor: CGFloat = 1.1
        let dragWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: baseWidth * scaleFactor, height: baseHeight * scaleFactor),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        dragWindow.isOpaque = false
        dragWindow.backgroundColor = NSColor.clear
        dragWindow.hasShadow = true // Enable shadow
        dragWindow.level = .floating
        dragWindow.ignoresMouseEvents = true
        dragWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        // Create drag view
        let dragView = TaskDragView(task: task, orbColor: orbColor)
        dragView.frame = NSRect(x: 0, y: 0, width: baseWidth * scaleFactor, height: baseHeight * scaleFactor)
        dragWindow.contentView = dragView
        
        if let contentView = dragWindow.contentView {
            contentView.wantsLayer = true
            contentView.layer?.shadowColor = NSColor.black.cgColor
            contentView.layer?.shadowOpacity = 0.4
            contentView.layer?.shadowOffset = CGSize(width: 0, height: -4)
            contentView.layer?.shadowRadius = 16
        }
        
        // Position window at current mouse location
        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = dragWindow.frame
        let windowOrigin = NSPoint(
            x: mouseLocation.x - windowFrame.width / 2,
            y: mouseLocation.y - windowFrame.height / 2
        )
        dragWindow.setFrameOrigin(windowOrigin)
        
        // Show the window
        dragWindow.orderFront(nil)
        

    // Store references
    controller?.draggedTaskWindow = dragWindow
    controller?.draggedTaskView = dragView

    let springOrigin = windowOrigin
    dragWindowSpringX.snap(to: springOrigin.x)
    dragWindowSpringY.snap(to: springOrigin.y)
    dragWindowSpringX.setTarget(springOrigin.x)
    dragWindowSpringY.setTarget(springOrigin.y)
    isDragWindowSpringActive = true
    updateTickerSubscription()

    // Disable pulse animation for stability
}
    
    private func updateTaskDrag(location: NSPoint) {
        guard isDraggingTask else { return }
        
        // Update floating drag window position
        updateDragWindowPosition()
        
        // Update visual feedback during drag
        needsDisplay = true
        
        // Check if we're over another task card
        controller?.updateTaskDragLocation(location, from: self)
    }
    
    private func updateDragWindowPosition() {
        guard let dragWindow = controller?.draggedTaskWindow else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = dragWindow.frame
        let targetOrigin = NSPoint(
            x: mouseLocation.x - windowFrame.width / 2,
            y: mouseLocation.y - windowFrame.height / 2
        )
        
        dragWindowSpringX.setTarget(targetOrigin.x)
        dragWindowSpringY.setTarget(targetOrigin.y)
        if !isDragWindowSpringActive {
            dragWindowSpringX.snap(to: dragWindow.frame.origin.x)
            dragWindowSpringY.snap(to: dragWindow.frame.origin.y)
        }
        isDragWindowSpringActive = true
        updateTickerSubscription()
    }
    
    private func endTaskDrag() {
        guard isDraggingTask else { return }
        
        DebugLog.log("Ending task drag", category: .tasks)
        
        // Check for drop target
        controller?.handleTaskDrop(from: self, draggedTask: draggedTask, draggedTaskIndex: draggedTaskIndex)
        
        // Clean up floating drag window
        cleanupDragWindow()
        
        // Reset drag state
        isDraggingTask = false
        draggedTask = nil
        draggedTaskIndex = -1
        
        // Reset cursor
        NSCursor.arrow.set()
        
        // Update display
        needsDisplay = true
    }
    
    private func cleanupDragWindow() {
        controller?.draggedTaskWindow?.orderOut(nil)
        controller?.draggedTaskWindow = nil
        controller?.draggedTaskView = nil
        isDragWindowSpringActive = false
        updateTickerSubscription()
    }
    
    func showDropIndicator(_ show: Bool) {
        isShowingDropIndicator = show
        needsDisplay = true
    }
    
    // MARK: - Scroll Functionality
    
    func calculateMaxScrollOffset(forListHeight listHeight: CGFloat? = nil) {
        let resolvedHeight = listHeight ?? defaultListHeight()
        DebugLog.log("🔢 calculateMaxScrollOffset - resolvedHeight: \(resolvedHeight)", category: .tasks)
        guard resolvedHeight > 0 else {
            DebugLog.log("🔢 resolvedHeight <= 0, setting maxScrollOffset=0", category: .tasks)
            maxScrollOffset = 0
            taskScrollOffset = 0
            scrollOffsetSpring.snap(to: 0)
            scrollOffsetSpring.setTarget(0)
            isScrollSpringActive = false
            return
        }

        let taskCount = CGFloat(tasks.count)
        if taskCount <= 0 {
            DebugLog.log("🔢 taskCount <= 0, setting maxScrollOffset=0", category: .tasks)
            maxScrollOffset = 0
            taskScrollOffset = 0
            scrollOffsetSpring.snap(to: 0)
            scrollOffsetSpring.setTarget(0)
            isScrollSpringActive = false
            return
        }

        let contentHeight = taskCount * TaskRowMetrics.rowHeight + max(0, taskCount - 1) * TaskRowMetrics.rowSpacing
        let calculatedMaxScroll = contentHeight - resolvedHeight
        DebugLog.log("🔢 taskCount: \(taskCount), contentHeight: \(contentHeight), resolvedHeight: \(resolvedHeight), calculated: \(calculatedMaxScroll)", category: .tasks)
        maxScrollOffset = max(0, contentHeight - resolvedHeight)
        DebugLog.log("🔢 Final maxScrollOffset: \(maxScrollOffset)", category: .tasks)

        // Only reset scroll state if there's no active scroll animation
        if !isScrollSpringActive {
            taskScrollOffset = max(0, min(taskScrollOffset, maxScrollOffset))
            scrollOffsetSpring.snap(to: taskScrollOffset)
            scrollOffsetSpring.setTarget(taskScrollOffset)
        } else {
            // During scroll animation, just clamp the current offset
            taskScrollOffset = max(0, min(taskScrollOffset, maxScrollOffset))
            DebugLog.log("🔢 Preserving active scroll animation - not resetting spring", category: .tasks)
        }
    }

    private func defaultListHeight() -> CGFloat {
        let cardRect = bounds.insetBy(dx: TaskRowMetrics.cardInset, dy: TaskRowMetrics.cardInset)
        let headerBottom = cardRect.maxY - TaskRowMetrics.headerHeight
        let listHeight = max(0, headerBottom - (cardRect.minY + TaskRowMetrics.listInset) - TaskRowMetrics.headerDividerSpacing)
        DebugLog.log("🔢 defaultListHeight - bounds: \(bounds.size), cardRect: \(cardRect.size), listHeight: \(listHeight)", category: .tasks)
        return listHeight
    }
    
    private func configureGlassEffect() {
        glassEffectView.material = .hudWindow  // Same as TaskDetailView
        glassEffectView.state = .active
        glassEffectView.blendingMode = .withinWindow
        glassEffectView.wantsLayer = true
        glassEffectView.layer?.cornerRadius = 24  // Match TaskDetailView (was 28)
        glassEffectView.layer?.masksToBounds = true
        glassEffectView.layer?.zPosition = -100
        addSubview(glassEffectView, positioned: .below, relativeTo: nil)
    }
    private func setupDragTracking() {
        // Set up tracking area for mouse events
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        self.addTrackingArea(trackingArea)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // Remove existing tracking areas
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        
        // Add new tracking area with current bounds
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        let locationInView = convert(event.locationInWindow, from: nil)

        print("🖱️ Right-click detected at: \(locationInView)")

        // Check if right-click is on a task
        if let taskIndex = getClickedTaskIndex(at: locationInView) {
            print("🖱️ Right-clicked on task index: \(taskIndex)")
            showTaskContextMenu(for: taskIndex, at: locationInView)
            return
        }

        print("🖱️ Right-click not on a task, passing to super")
        super.rightMouseDown(with: event)
    }

    private func showTaskContextMenu(for taskIndex: Int, at location: CGPoint) {
        guard taskIndex >= 0 && taskIndex < tasks.count else {
            print("❌ Invalid task index: \(taskIndex)")
            return
        }
        guard let orb = controller?.orbManager.orbs.first(where: { $0.id == currentOrbId }) else {
            print("❌ Could not find orb for ID: \(currentOrbId ?? UUID())")
            return
        }

        let task = tasks[taskIndex]
        print("✅ Showing context menu for task: \(task.title)")

        let menu = NSMenu()
        menu.autoenablesItems = false

        let deleteItem = NSMenuItem(title: "Delete \"\(task.title)\"", action: #selector(handleDeleteTaskFromMenu(_:)), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.representedObject = task
        deleteItem.isEnabled = true
        menu.addItem(deleteItem)

        // Position menu at the click location
        NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent!, for: self)
    }

    @objc private func handleDeleteTaskFromMenu(_ sender: NSMenuItem) {
        guard let task = sender.representedObject as? Task else {
            print("❌ No task in menu item")
            return
        }
        guard let orb = controller?.orbManager.orbs.first(where: { $0.id == currentOrbId }) else {
            print("❌ Could not find orb for deletion")
            return
        }

        print("🗑️ Deleting task: \(task.title)")
        controller?.deleteTask(task, from: orb)
    }

    override func mouseDown(with event: NSEvent) {
        let locationInView = convert(event.locationInWindow, from: nil)
        DebugLog.log("🖱️ mouseDown at: \(locationInView), rowGeometries count: \(rowGeometries.count)", category: .tasks)

        // Check for Control+Click (right-click on Mac)
        if event.modifierFlags.contains(.control) {
            print("🖱️ Control+Click detected, treating as right-click")
            rightMouseDown(with: event)
            return
        }

        // Check if click is on the resize handle
        if resizeHandleRect.contains(locationInView) {
            guard let window = window else { return }
            isResizing = true
            resizeStartLocation = NSEvent.mouseLocation
            resizeStartSize = window.frame.size
            return
        }

        // Check if click is on the close button
        if closeButtonRect.contains(locationInView) {
            closeTaskCard()
            return
        }

        // Check if click is on the pin button
        if pinButtonRect.contains(locationInView) {
            togglePin()
            return
        }

        // Check if click is on the delete button
        if deleteButtonRect.contains(locationInView) {
            controller?.requestProjectDeletion(for: self)
            return
        }

        // Check if click is on the search field
        if searchFieldRect.contains(locationInView) {
            DebugLog.log("🔍 Search field clicked - isSearchActive: \(isSearchActive)", category: .tasks)
            if !isSearchActive {
                isSearchActive = true
                needsDisplay = true
                DebugLog.log("🔍 Search activated", category: .tasks)
                // Reset fade timer when search is activated
                controller?.resetFadeTimer()
            }
            let success = window?.makeFirstResponder(self)
            DebugLog.log("🔍 makeFirstResponder result: \(success == true ? "success" : "failed")", category: .tasks)
            return
        }

        // Scroll bar is now visual only - no drag interaction needed

        // Check if click is on a grab handle (only way to start dragging)
        if let grabHandleIndex = getClickedGrabHandleIndex(at: locationInView) {
            startTaskDrag(taskIndex: grabHandleIndex, location: locationInView)
            return
        }

        // Check if click is on a checkbox
        if let checkboxIndex = getClickedCheckboxIndex(at: locationInView) {
            DebugLog.log("🖱️ Checkbox clicked at index: \(checkboxIndex)", category: .tasks)
            toggleTaskCompletion(at: checkboxIndex)
            return
        }

        // Check if click is on a task (to open task detail)
        if let taskIndex = getClickedTaskIndex(at: locationInView) {
            DebugLog.log("🖱️ Task clicked at index: \(taskIndex), opening detail", category: .tasks)
            openTaskDetail(for: taskIndex)
            return
        }

        DebugLog.log("🖱️ Click did not match any task row", category: .tasks)

        // Reset fade timer on any mouse interaction (only if not pinned)
        if !isPinned {
            controller?.resetFadeTimer()
        }

        // Check if click is in the drag grip area (top border strip of the card)
        if currentDragRect().contains(locationInView) {
            guard let window = window else { return }
            isDraggingCard = true
            dragStartScreenLocation = NSEvent.mouseLocation
            initialWindowOrigin = window.frame.origin
            NSCursor.closedHand.set()
            updateCardLiftTarget()
            return
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        // Handle resize dragging
        if isResizing {
            guard let window = window else { return }
            
            let currentLocation = NSEvent.mouseLocation
            let deltaX = currentLocation.x - resizeStartLocation.x
            let deltaY = currentLocation.y - resizeStartLocation.y
            
            // Calculate new size with constraints
            let minWidth: CGFloat = 250
            let maxWidth: CGFloat = 500
            let minHeight: CGFloat = 200
            let maxHeight: CGFloat = 800
            
            var newWidth = resizeStartSize.width + deltaX
            var newHeight = resizeStartSize.height - deltaY
            
            newWidth = max(minWidth, min(maxWidth, newWidth))
            newHeight = max(minHeight, min(maxHeight, newHeight))
            
            let newSize = NSSize(width: newWidth, height: newHeight)
            var newFrame = window.frame
            newFrame.size = newSize
            newFrame.origin.y = window.frame.origin.y + (window.frame.height - newHeight)
            
            window.setFrame(newFrame, display: true, animate: false)
            
            calculateMaxScrollOffset()
            needsDisplay = true
            
            if !isPinned {
                controller?.resetFadeTimer()
            }
            return
        }
        
        // Handle task dragging
        if isDraggingTask {
            updateTaskDrag(location: convert(event.locationInWindow, from: nil))
            return
        }
        
        if isDraggingCard {
            guard let window = window, let screen = window.screen else { return }
            
            let currentLocation = NSEvent.mouseLocation
            let deltaX = currentLocation.x - dragStartScreenLocation.x
            let deltaY = currentLocation.y - dragStartScreenLocation.y
            
            var newOrigin = NSPoint(
                x: initialWindowOrigin.x + deltaX,
                y: initialWindowOrigin.y + deltaY
            )
            
            let screenFrame = screen.visibleFrame
            let windowSize = window.frame.size
            newOrigin.x = max(screenFrame.minX, min(newOrigin.x, screenFrame.maxX - windowSize.width))
            newOrigin.y = max(screenFrame.minY, min(newOrigin.y, screenFrame.maxY - windowSize.height))
            
            window.setFrameOrigin(newOrigin)
            
            if !isPinned {
                controller?.resetFadeTimer()
            }
            return
        }
        
        if !isPinned {
            controller?.resetFadeTimer()
        }
        
        super.mouseDragged(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        // Handle resize completion
        if isResizing {
            isResizing = false
            if let window = window {
                // Save custom size to controller for this orb
                if let orbId = controller?.currentOpenOrb?.id {
                    controller?.customCardSizes[orbId] = window.frame.size
                }
            }
            NSCursor.arrow.set()
            return
        }
        
        // Handle task drop
        if isDraggingTask {
            endTaskDrag()
            return
        }
        
        if isDraggingCard {
            isDraggingCard = false
            NSCursor.arrow.set()
            updateCardLiftTarget()
        }
        
        // Reset fade timer on mouse up (only if not pinned)
        if !isPinned {
            controller?.resetFadeTimer()
        }
        NSCursor.arrow.set()
    }
    
    override func mouseEntered(with event: NSEvent) {
        // Reset fade timer on hover (only if not pinned)
        if !isPinned {
            controller?.resetFadeTimer()
        }
        
        // Set card hover state
        isHoveringCard = true
        needsDisplay = true
        updateCardLiftTarget()
        
        // Change cursor when hovering over drag grip
        let locationInView = convert(event.locationInWindow, from: nil)
        if currentDragRect().contains(locationInView) && !closeButtonRect.contains(locationInView) && !pinButtonRect.contains(locationInView) && !deleteButtonRect.contains(locationInView) {
            NSCursor.openHand.set()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        isHoveringCard = false
        isHoveringClose = false
        isHoveringPin = false
        isHoveringDelete = false
        isHoveringDragGrip = false
        needsDisplay = true
        updateCardLiftTarget()
        NSCursor.arrow.set()
    }
    
    override func mouseMoved(with event: NSEvent) {
        // Reset fade timer on mouse movement (only if not pinned)
        if !isPinned {
            controller?.resetFadeTimer()
        }
        
        // Update cursor based on mouse position
        let locationInView = convert(event.locationInWindow, from: nil)
        
        // Check button hover states
        let wasHoveringClose = isHoveringClose
        let wasHoveringPin = isHoveringPin
        let wasHoveringDelete = isHoveringDelete
        isHoveringClose = closeButtonRect.contains(locationInView)
        isHoveringPin = pinButtonRect.contains(locationInView)
        isHoveringDelete = deleteButtonRect.contains(locationInView)
        if wasHoveringClose != isHoveringClose || wasHoveringPin != isHoveringPin || wasHoveringDelete != isHoveringDelete {
            needsDisplay = true
        }

        // Check drag grip hover
        let wasHoveringDragGrip = isHoveringDragGrip
        isHoveringDragGrip = dragGripRect.contains(locationInView) && !isHoveringClose && !isHoveringPin && !isHoveringDelete
        if wasHoveringDragGrip != isHoveringDragGrip {
            needsDisplay = true
        }

        // Check resize handle hover
        if resizeHandleRect.contains(locationInView) {
            if !isHoveringResizeHandle {
                isHoveringResizeHandle = true
                needsDisplay = true
            }
            NSCursor.arrow.set() // Could use a resize cursor if desired
            return
        } else {
            if isHoveringResizeHandle {
                isHoveringResizeHandle = false
                needsDisplay = true
            }
        }
        
        // Check scroll bar hover
        if scrollBarRect.contains(locationInView) && maxScrollOffset > 0 {
            if !isHoveringScrollBar {
                isHoveringScrollBar = true
                needsDisplay = true
            }
            NSCursor.arrow.set()
        } else {
            if isHoveringScrollBar {
                isHoveringScrollBar = false
                needsDisplay = true
            }
            
            if currentDragRect().contains(locationInView) && !closeButtonRect.contains(locationInView) && !pinButtonRect.contains(locationInView) && !deleteButtonRect.contains(locationInView) {
                NSCursor.openHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
    
    override func scrollWheel(with event: NSEvent) {
        DebugLog.log("📜 scrollWheel called - tasks: \(tasks.count), filtered: \(filteredTasks.count), maxScrollOffset: \(maxScrollOffset), isDragging: \(isDraggingTask), delta: \(event.scrollingDeltaY)", category: .tasks)

        // Only handle scrolling if there are tasks to scroll and we're not dragging
        guard maxScrollOffset > 0 && !isDraggingTask else {
            DebugLog.log("📜 Scroll blocked - maxScrollOffset: \(maxScrollOffset), isDraggingTask: \(isDraggingTask)", category: .tasks)
            // Pass the event up if we can't handle it
            super.scrollWheel(with: event)
            return
        }

        // Reset fade timer on scroll
        if !isPinned {
            controller?.resetFadeTimer()
        }

        let scrollDelta = event.scrollingDeltaY
        let scrollSensitivity: CGFloat = 2.0

        // Calculate new offset (reverse direction: scroll down = negative delta = decrease offset)
        let newOffset = taskScrollOffset - (scrollDelta * scrollSensitivity)

        let clampedOffset = max(0, min(newOffset, maxScrollOffset))
        DebugLog.log("📜 Scrolling: delta=\(scrollDelta), old offset=\(taskScrollOffset), new offset=\(clampedOffset), spring current=\(scrollOffsetSpring.value), spring target will be=\(clampedOffset)", category: .tasks)

        scrollOffsetSpring.setTarget(clampedOffset)
        if !isScrollSpringActive {
            scrollOffsetSpring.snap(to: taskScrollOffset)
            DebugLog.log("📜 Spring was not active, snapped to current position: \(taskScrollOffset)", category: .tasks)
        }
        isScrollSpringActive = true
        needsDisplay = true
        DebugLog.log("📜 isScrollSpringActive=\(isScrollSpringActive), isTickerRegistered=\(isTickerRegistered)", category: .tasks)
        updateTickerSubscription()
        DebugLog.log("📜 After updateTickerSubscription: isTickerRegistered=\(isTickerRegistered)", category: .tasks)
    }

    override func keyDown(with event: NSEvent) {
        DebugLog.log("🔍 keyDown - isSearchActive: \(isSearchActive), characters: \(event.characters ?? "nil"), keyCode: \(event.keyCode)", category: .tasks)

        // Cmd+F to toggle search
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "f" {
            toggleSearch()
            return
        }

        // Cmd+E to export tasks
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "e" {
            exportTasks()
            return
        }

        // Only handle text input if search is active
        guard isSearchActive else {
            DebugLog.log("🔍 Search not active, passing to super", category: .tasks)
            super.keyDown(with: event)
            return
        }

        // Reset fade timer on any keyboard input while search is active
        controller?.resetFadeTimer()

        // Handle Escape to clear/deactivate search
        if event.keyCode == 53 { // Escape key
            clearSearch()
            return
        }

        // Handle backspace
        if event.keyCode == 51 { // Delete/Backspace
            if !searchQuery.isEmpty {
                searchQuery.removeLast()
                needsDisplay = true
            }
            return
        }

        // Handle regular character input
        if let characters = event.characters, !characters.isEmpty {
            // Filter out non-printable characters
            let printableChars = characters.filter { $0.isLetter || $0.isNumber || $0.isWhitespace || $0.isPunctuation }
            if !printableChars.isEmpty {
                searchQuery.append(printableChars)
                DebugLog.log("🔍 Search query updated: '\(searchQuery)' - filtered tasks: \(filteredTasks.count)", category: .tasks)
                taskScrollOffset = 0  // Reset scroll when filtering
                scrollOffsetSpring.snap(to: 0)
                needsDisplay = true
            }
        }
    }

    private func toggleSearch() {
        isSearchActive.toggle()
        if !isSearchActive {
            searchQuery = ""
        }
        needsDisplay = true
    }

    private func clearSearch() {
        searchQuery = ""
        isSearchActive = false
        needsDisplay = true
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        DebugLog.log("🎨 draw() called - taskScrollOffset: \(taskScrollOffset), maxScrollOffset: \(maxScrollOffset)", category: .tasks)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Clear to transparent
        context.clear(dirtyRect)
        
        let cardRect = bounds.insetBy(dx: TaskRowMetrics.cardInset, dy: TaskRowMetrics.cardInset)
        
        drawGlassBackground(in: context, cardRect: cardRect)
        let headerBottom = drawHeaderControls(in: context, cardRect: cardRect)

        if isShowingDropIndicator {
            drawDropTargetHalo(in: context, cardRect: cardRect)
        }

        if isCelebrating {
            drawCelebrationRimGlow(in: context, cardRect: cardRect)
        }

        drawTaskList(in: context, cardRect: cardRect, headerBottom: headerBottom)
        drawResizeHandle(in: context, cardRect: cardRect)

        // Draw celebration effects (confetti, particles, ripples)
        celebrationManager.draw(in: context)
    }
    
    private func drawGlassBackground(in context: CGContext, cardRect: CGRect) {
        // Let the NSVisualEffectView (.hudWindow material) handle the frosted glass background
        // Just add a subtle border for definition
        let cornerRadius: CGFloat = 24
        let borderPath = NSBezierPath(roundedRect: cardRect, xRadius: cornerRadius, yRadius: cornerRadius)

        context.saveGState()
        // Very subtle border to define edges
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.15).cgColor)
        context.setLineWidth(1.0)
        borderPath.stroke()
        context.restoreGState()
    }
    
    @discardableResult
    private func drawHeaderControls(in context: CGContext, cardRect: CGRect) -> CGFloat {
        // CLEAR DRAG HANDLE at top + controls below
        let topPadding: CGFloat = 12
        let horizontalPadding: CGFloat = 20
        let iconSize: CGFloat = 28

        // Draw clear drag handle pill at very top center
        let dragHandleWidth: CGFloat = 48
        let dragHandleHeight: CGFloat = 5
        let dragHandleY = cardRect.maxY - topPadding - dragHandleHeight
        let dragHandleRect = CGRect(
            x: cardRect.midX - dragHandleWidth / 2,
            y: dragHandleY,
            width: dragHandleWidth,
            height: dragHandleHeight
        )

        context.saveGState()
        let dragHandlePath = NSBezierPath(roundedRect: dragHandleRect, xRadius: dragHandleHeight / 2, yRadius: dragHandleHeight / 2)
        let dragOpacity: CGFloat = isHoveringDragGrip ? 0.25 : 0.15
        context.setFillColor(NSColor(calibratedWhite: 0.3, alpha: dragOpacity).cgColor)
        dragHandlePath.fill()
        context.restoreGState()

        // Larger drag area around the pill
        dragGripRect = CGRect(
            x: cardRect.midX - 80,
            y: dragHandleY - 8,
            width: 160,
            height: dragHandleHeight + 16
        )

        // Icon buttons below drag handle
        let iconY = dragHandleY - 18 - iconSize
        var currentX = cardRect.maxX - horizontalPadding - iconSize

        // Delete button (rightmost) - using SF Symbol
        deleteButtonRect = CGRect(x: currentX, y: iconY, width: iconSize, height: iconSize)
        drawMinimalIconButton(in: context, rect: deleteButtonRect, isHovered: isHoveringDelete) { ctx, rect in
            let color = isHoveringDelete ? NSColor.systemRed : NSColor(calibratedWhite: 0.4, alpha: 0.8)
            drawSFSymbol(named: "trash", in: rect, color: color, context: ctx)
        }
        currentX -= iconSize + 12

        // Pin button - using SF Symbol
        pinButtonRect = CGRect(x: currentX, y: iconY, width: iconSize, height: iconSize)
        drawMinimalIconButton(in: context, rect: pinButtonRect, isHovered: isHoveringPin) { ctx, rect in
            let color = isPinned ? orbColor : NSColor(calibratedWhite: 0.4, alpha: 0.8)
            let symbolName = isPinned ? "pin.fill" : "pin"
            drawSFSymbol(named: symbolName, in: rect, color: color, context: ctx)
        }

        // Close button (left) - using SF Symbol
        closeButtonRect = CGRect(x: cardRect.minX + horizontalPadding, y: iconY, width: iconSize, height: iconSize)
        drawMinimalIconButton(in: context, rect: closeButtonRect, isHovered: isHoveringClose) { ctx, rect in
            let color = isHoveringClose ? NSColor.systemRed : NSColor(calibratedWhite: 0.4, alpha: 0.8)
            drawSFSymbol(named: "xmark", in: rect, color: color, context: ctx)
        }

        // Task counters at same level as icon buttons (centered between close and pin/delete)
        let completedCount = tasks.filter { $0.isCompleted }.count
        let openTasks = tasks.count - completedCount
        let statsString = "\(openTasks) open  •  \(completedCount) done"

        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.alignment = .center
        let titleColor = NSColor(calibratedWhite: 0.1, alpha: 0.95)

        let statsAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12 * textScale, weight: .medium),
            .foregroundColor: titleColor.withAlphaComponent(0.5),
            .paragraphStyle: titleParagraph
        ]
        // Position stats centered vertically with buttons
        let statsRect = CGRect(x: cardRect.minX + 32, y: iconY + (iconSize - 16) / 2, width: cardRect.width - 64, height: 16)
        statsString.draw(in: statsRect, withAttributes: statsAttributes)

        // Title below buttons
        var currentY = iconY - 16
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 19 * textScale, weight: .semibold),
            .foregroundColor: titleColor,
            .paragraphStyle: titleParagraph
        ]
        let titleRect = CGRect(x: cardRect.minX + 32, y: currentY - 24, width: cardRect.width - 64, height: 24)
        projectName.draw(in: titleRect, withAttributes: titleAttributes)

        currentY = titleRect.minY - 16  // Space after title

        // Clean search box BELOW title
        if !tasks.isEmpty {
            let searchY = currentY
            drawMinimalSearchBox(in: context, cardRect: cardRect, topY: searchY)

            // Separator line below search box
            let separatorY = searchY - 36 - 16  // Below search box (36px height)
            context.saveGState()
            context.move(to: CGPoint(x: cardRect.minX + 28, y: separatorY))
            context.addLine(to: CGPoint(x: cardRect.maxX - 28, y: separatorY))
            context.setStrokeColor(orbColor.withAlphaComponent(0.15).cgColor)
            context.setLineWidth(1.0)
            context.strokePath()
            context.restoreGState()

            return separatorY - 16
        }

        return currentY - 20
    }

    private func drawMinimalIconButton(in context: CGContext, rect: CGRect, isHovered: Bool, icon: (CGContext, CGRect) -> Void) {
        // Only show background on hover (widget style)
        if isHovered {
            context.saveGState()
            let bgPath = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
            context.setFillColor(NSColor(calibratedWhite: 0.0, alpha: 0.08).cgColor)
            bgPath.fill()
            context.restoreGState()
        }

        // Draw icon
        icon(context, rect)
    }

    private func drawMinimalSearchBox(in context: CGContext, cardRect: CGRect, topY: CGFloat) {
        let horizontalPadding: CGFloat = 20
        let searchHeight: CGFloat = 36

        searchFieldRect = CGRect(
            x: cardRect.minX + horizontalPadding,
            y: topY - searchHeight,
            width: cardRect.width - horizontalPadding * 2,
            height: searchHeight
        )

        let searchPath = NSBezierPath(roundedRect: searchFieldRect, xRadius: 10, yRadius: 10)

        // Widget-style search box
        context.saveGState()
        let bgAlpha = isSearchActive ? 0.15 : 0.08
        context.setFillColor(NSColor(calibratedWhite: 0.0, alpha: bgAlpha).cgColor)
        searchPath.fill()

        // Subtle border
        context.setStrokeColor(NSColor(calibratedWhite: 0.5, alpha: 0.15).cgColor)
        context.setLineWidth(0.5)
        searchPath.stroke()
        context.restoreGState()

        // Search icon and text
        let iconSize: CGFloat = 16
        let iconX = searchFieldRect.minX + 12
        let iconY = searchFieldRect.midY - iconSize / 2
        let iconRect = CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize)

        context.saveGState()
        context.setStrokeColor(NSColor(calibratedWhite: 0.5, alpha: 0.6).cgColor)
        context.setLineWidth(1.5)
        context.setLineCap(.round)

        let searchCircle = NSBezierPath(ovalIn: iconRect.insetBy(dx: 2, dy: 2))
        searchCircle.stroke()

        context.move(to: CGPoint(x: iconRect.maxX - 3, y: iconRect.maxY - 3))
        context.addLine(to: CGPoint(x: iconRect.maxX, y: iconRect.maxY))
        context.strokePath()
        context.restoreGState()

        // Search text or placeholder
        let textX = iconRect.maxX + 8
        let textWidth = searchFieldRect.maxX - textX - 12
        let textRect = CGRect(x: textX, y: searchFieldRect.minY, width: textWidth, height: searchHeight)

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13 * textScale, weight: .regular),
            .foregroundColor: searchQuery.isEmpty ?
                NSColor(calibratedWhite: 0.5, alpha: 0.6) :
                NSColor(calibratedWhite: 0.2, alpha: 0.9)
        ]

        let displayText = searchQuery.isEmpty ? "Search tasks..." : searchQuery
        let textSize = displayText.size(withAttributes: textAttributes)
        let centeredTextRect = CGRect(
            x: textRect.minX,
            y: textRect.midY - textSize.height / 2,
            width: textRect.width,
            height: textSize.height
        )

        displayText.draw(in: centeredTextRect, withAttributes: textAttributes)
    }

    private func drawSearchBox(in context: CGContext, cardRect: CGRect, topY: CGFloat) {
        let horizontalPadding: CGFloat = 24
        let searchHeight: CGFloat = 32

        searchFieldRect = CGRect(
            x: cardRect.minX + horizontalPadding,
            y: topY - searchHeight,
            width: cardRect.width - horizontalPadding * 2,
            height: searchHeight
        )

        let radius = searchHeight / 2
        let searchPath = NSBezierPath(roundedRect: searchFieldRect, xRadius: radius, yRadius: radius)

        // Background
        context.saveGState()
        let bgColor = isSearchActive ?
            NSColor(calibratedWhite: 0.12, alpha: 0.35) :
            NSColor(calibratedWhite: 0.08, alpha: 0.22)
        context.setFillColor(bgColor.cgColor)
        searchPath.fill()

        // Border
        let borderColor = isSearchActive ?
            orbColor.withAlphaComponent(0.3) :
            NSColor.white.withAlphaComponent(0.08)
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(1.0)
        searchPath.stroke()
        context.restoreGState()

        // Search icon
        let iconSize: CGFloat = 14
        let iconRect = CGRect(
            x: searchFieldRect.minX + 12,
            y: searchFieldRect.midY - iconSize / 2,
            width: iconSize,
            height: iconSize
        )
        drawSearchIcon(in: context, rect: iconRect)

        // Text
        let textX = iconRect.maxX + 8
        let textWidth = searchFieldRect.width - (textX - searchFieldRect.minX) - 12

        if !searchQuery.isEmpty {
            let textRect = CGRect(
                x: textX,
                y: searchFieldRect.minY,
                width: textWidth,
                height: searchFieldRect.height
            )
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byTruncatingTail
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12 * textScale, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.9),
                .paragraphStyle: paragraphStyle
            ]
            let textY = searchFieldRect.midY - searchQuery.size(withAttributes: textAttributes).height / 2
            searchQuery.draw(at: CGPoint(x: textX, y: textY), withAttributes: textAttributes)
        } else {
            // Placeholder
            let placeholder = "Search tasks... (⌘F)"
            let textRect = CGRect(
                x: textX,
                y: searchFieldRect.minY,
                width: textWidth,
                height: searchFieldRect.height
            )
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byTruncatingTail
            let placeholderAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12 * textScale, weight: .regular),
                .foregroundColor: NSColor.white.withAlphaComponent(0.4),
                .paragraphStyle: paragraphStyle
            ]
            let textY = searchFieldRect.midY - placeholder.size(withAttributes: placeholderAttributes).height / 2
            placeholder.draw(at: CGPoint(x: textX, y: textY), withAttributes: placeholderAttributes)
        }
    }

    private func drawSearchIcon(in context: CGContext, rect: CGRect) {
        context.saveGState()
        let color = isSearchActive ?
            orbColor.withAlphaComponent(0.7) :
            NSColor.white.withAlphaComponent(0.5)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.5)

        // Circle
        let circleRect = rect.insetBy(dx: 2, dy: 2)
        context.strokeEllipse(in: circleRect)

        // Handle
        context.move(to: CGPoint(x: rect.maxX - 3, y: rect.minY + 3))
        context.addLine(to: CGPoint(x: rect.maxX - 1, y: rect.minY + 1))
        context.strokePath()
        context.restoreGState()
    }

    private func drawHeaderButton(
        in context: CGContext,
        rect: CGRect,
        baseFill: NSColor,
        activeFill: NSColor,
        isHovered: Bool,
        isActive: Bool,
        iconRenderer: (CGContext, CGRect, NSColor) -> Void
    ) {
        let radius = rect.height / 2
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        let fillColor = isActive ? activeFill : baseFill
        let hoveredFill = isHovered ? fillColor.withAlphaComponent(min(1.0, fillColor.alphaComponent + 0.15)) : fillColor

        context.saveGState()
        context.setFillColor(hoveredFill.cgColor)
        path.fill()
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.08).cgColor)
        context.setLineWidth(1.0)
        path.stroke()
        context.restoreGState()

        let iconInset = max(4, rect.height * 0.28)
        let iconRect = rect.insetBy(dx: iconInset, dy: iconInset)
        let iconColor = NSColor.white.withAlphaComponent(isActive ? 1.0 : (isHovered ? 0.92 : 0.78))
        iconRenderer(context, iconRect, iconColor)
    }

    private func drawDragHandle(in context: CGContext, rect: CGRect) {
        context.saveGState()
        let path = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        context.setFillColor(NSColor.white.withAlphaComponent(0.18).cgColor)
        path.fill()
        context.restoreGState()

        context.saveGState()
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(1.1)
        let lineCount = 3
        let spacing = rect.width / CGFloat(lineCount + 1)
        for index in 1...lineCount {
            let x = rect.minX + spacing * CGFloat(index)
            context.move(to: CGPoint(x: x, y: rect.minY + 1.5))
            context.addLine(to: CGPoint(x: x, y: rect.maxY - 1.5))
        }
        context.strokePath()
        context.restoreGState()
    }

    private func drawCloseGlyph(in context: CGContext, rect: CGRect, color: NSColor) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.6)
        context.setLineCap(.round)
        context.move(to: CGPoint(x: rect.minX, y: rect.minY))
        context.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        context.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        context.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        context.strokePath()
        context.restoreGState()
    }

    private func drawPinGlyph(in context: CGContext, rect: CGRect, color: NSColor) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.4)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        let headRect = CGRect(x: rect.midX - rect.width * 0.25, y: rect.maxY - rect.height * 0.55, width: rect.width * 0.5, height: rect.height * 0.45)
        context.addEllipse(in: headRect)
        if color.alphaComponent > 0.95 {
            context.fillPath()
        } else {
            context.strokePath()
        }

        context.move(to: CGPoint(x: rect.midX, y: rect.minY))
        context.addLine(to: CGPoint(x: rect.midX, y: headRect.minY + 2))
        context.strokePath()
        context.restoreGState()
    }
    
    private func drawDeleteGlyph(in context: CGContext, rect: CGRect, color: NSColor) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.6)
        context.setLineCap(.round)
        let midY = rect.midY
        context.move(to: CGPoint(x: rect.minX, y: midY))
        context.addLine(to: CGPoint(x: rect.maxX, y: midY))
        context.strokePath()
        context.restoreGState()
    }

    private func drawSFSymbol(named symbolName: String, in rect: CGRect, color: NSColor, context: CGContext) {
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else { return }

        let config = NSImage.SymbolConfiguration(pointSize: rect.height * 0.6, weight: .regular)
        let configuredSymbol = symbol.withSymbolConfiguration(config) ?? symbol

        context.saveGState()

        // Center the symbol in the rect
        let imageSize = configuredSymbol.size
        let x = rect.midX - imageSize.width / 2
        let y = rect.midY - imageSize.height / 2
        let imageRect = CGRect(x: x, y: y, width: imageSize.width, height: imageSize.height)

        // Draw the symbol with the specified color
        if let cgImage = configuredSymbol.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.setFillColor(color.cgColor)
            context.clip(to: imageRect, mask: cgImage)
            context.fill(imageRect)
        }

        context.restoreGState()
    }

    private func createNoiseTexture() -> CGImage? {
        let size = 128
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        
        for i in 0..<(size * size) {
            let noise = UInt8.random(in: 0...255)
            pixels[i * 4] = noise
            pixels[i * 4 + 1] = noise
            pixels[i * 4 + 2] = noise
            pixels[i * 4 + 3] = 255
        }
        
        guard let dataProvider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        
        return CGImage(
            width: size,
            height: size,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
    
    private func drawDropTargetHalo(in context: CGContext, cardRect: CGRect) {
        context.saveGState()
        let haloRect = cardRect.insetBy(dx: 6, dy: 6)
        let haloPath = NSBezierPath(roundedRect: haloRect, xRadius: 24, yRadius: 24)
        context.setStrokeColor(orbColor.withAlphaComponent(0.35).cgColor)
        context.setLineWidth(1.5)
        haloPath.stroke()
        context.restoreGState()
    }
    
    private func calculateAdaptiveFontSize(for text: String, in rect: NSRect) -> CGFloat {
        let baseFontSize: CGFloat = 18.0
        let minFontSize: CGFloat = 12.0
        let maxFontSize: CGFloat = 22.0
        
        // Calculate text length factor (longer text = smaller font)
        let textLength = text.count
        let lengthFactor = max(0.6, min(1.0, 1.0 - (Double(textLength - 10) * 0.02)))
        
        // Calculate available width factor
        let availableWidth = rect.width - 20 // Account for padding
        let widthFactor = min(1.0, availableWidth / 200.0) // Normalize to 200px baseline
        
        // Combine factors and calculate final font size
        let combinedFactor = lengthFactor * widthFactor
        let adaptiveSize = baseFontSize * combinedFactor
        
        // Clamp to min/max bounds
        return max(minFontSize, min(maxFontSize, adaptiveSize))
    }
    
    private func drawTaskList(in context: CGContext, cardRect: NSRect, headerBottom: CGFloat) {
        // Use the actual header bottom from drawHeaderControls (prevents overlap)

        // Calculate max scroll first to determine if we need scrollbar space
        let tempListHeight = max(0, headerBottom - (cardRect.minY + TaskRowMetrics.listInset))
        let tempRowStride = TaskRowMetrics.rowHeight + TaskRowMetrics.rowSpacing
        let totalRowsHeight = CGFloat(filteredTasks.count) * tempRowStride - TaskRowMetrics.rowSpacing
        let needsScrollbar = totalRowsHeight > tempListHeight

        // Only reserve space for scrollbar if we actually need one
        let scrollbarReserve: CGFloat = needsScrollbar ? (TaskRowMetrics.scrollBarWidth + TaskRowMetrics.scrollBarSpacing) : 0
        let contentWidth = cardRect.width - TaskRowMetrics.listInset * 2 - scrollbarReserve

        let listRect = NSRect(
            x: cardRect.minX + TaskRowMetrics.listInset,
            y: cardRect.minY + TaskRowMetrics.listInset,
            width: contentWidth,
            height: tempListHeight
        )
        let scrollTrackRect = NSRect(
            x: listRect.maxX + TaskRowMetrics.scrollBarSpacing,
            y: listRect.minY,
            width: TaskRowMetrics.scrollBarWidth,
            height: listRect.height
        )

        calculateMaxScrollOffset(forListHeight: listRect.height)
        rowGeometries.removeAll()

        if filteredTasks.isEmpty {
            if !searchQuery.isEmpty {
                drawNoSearchResultsState(in: context, rect: listRect)
            } else {
                drawEmptyTaskState(in: context, rect: listRect)
            }
            return
        }

        if maxScrollOffset > 0 {
            drawScrollBar(in: context, trackRect: scrollTrackRect)
        }

        context.saveGState()
        context.clip(to: listRect)

        let rowStride = TaskRowMetrics.rowHeight + TaskRowMetrics.rowSpacing
        DebugLog.log("🎨 Drawing tasks - count: \(filteredTasks.count), taskScrollOffset: \(taskScrollOffset), rowStride: \(rowStride)", category: .tasks)
        for (index, task) in filteredTasks.enumerated() {
            if isDraggingTask && draggedTaskIndex == index { continue }

            let offset = CGFloat(index) * rowStride - taskScrollOffset
            if index == 0 {
                DebugLog.log("🎨 First task - index: \(index), offset: \(offset), rowY will be: \(listRect.maxY - offset - TaskRowMetrics.rowHeight)", category: .tasks)
            }
            let rowY = listRect.maxY - offset - TaskRowMetrics.rowHeight
            let rowRect = CGRect(
                x: listRect.minX,
                y: rowY,
                width: listRect.width,
                height: TaskRowMetrics.rowHeight
            )
            
            guard rowRect.maxY > listRect.minY - TaskRowMetrics.rowHeight else { continue }
            guard rowRect.minY < listRect.maxY + TaskRowMetrics.rowHeight else { continue }
            
            if rowRect.intersects(listRect) {
                // Checkbox now on left side for minimal design
                let checkboxRect = CGRect(
                    x: rowRect.minX + TaskRowMetrics.checkboxLeadingInset,
                    y: rowRect.midY - TaskRowMetrics.checkboxSize / 2,
                    width: TaskRowMetrics.checkboxSize,
                    height: TaskRowMetrics.checkboxSize
                )
                let dragRect = CGRect(
                    x: rowRect.minX,
                    y: rowRect.minY,
                    width: TaskRowMetrics.dragHitWidth,
                    height: rowRect.height
                )

                rowGeometries.append(TaskRowGeometry(
                    index: index,
                    rowRect: rowRect,
                    checkboxRect: checkboxRect,
                    dragRect: dragRect
                ))

                drawTaskRow(in: context, rect: rowRect, task: task, index: index, checkboxRect: checkboxRect)
            }
        }
        
        context.restoreGState()
    }

    private func drawScrollBar(in context: CGContext, trackRect: NSRect) {
        let scrollBarWidth = trackRect.width
        let scrollBarHeight = trackRect.height
        let thumbHeight = max(24, scrollBarHeight * (trackRect.height / (trackRect.height + maxScrollOffset)))
        // Invert the position: when taskScrollOffset=0 (top), thumb should be at top (maxY)
        let thumbOffset = (scrollBarHeight - thumbHeight) * (maxScrollOffset == 0 ? 0 : 1.0 - (taskScrollOffset / maxScrollOffset))
        let thumbRect = NSRect(x: trackRect.minX, y: trackRect.minY + thumbOffset, width: scrollBarWidth, height: thumbHeight)

        scrollBarRect = trackRect

        context.saveGState()
        let trackPath = NSBezierPath(roundedRect: scrollBarRect.insetBy(dx: 1.5, dy: 6), xRadius: scrollBarWidth/2, yRadius: scrollBarWidth/2)
        NSColor(calibratedWhite: 0.08, alpha: 0.08).setFill()
        trackPath.fill()
        context.restoreGState()

        context.saveGState()
        let thumbPath = NSBezierPath(roundedRect: thumbRect.insetBy(dx: 0.5, dy: 2), xRadius: scrollBarWidth/2, yRadius: scrollBarWidth/2)
        if let thumbGradient = GradientCache.shared.gradient(
            colors: [
                orbColor.withAlphaComponent(isHoveringScrollBar ? 0.75 : 0.55),
                orbColor.highlighted().withAlphaComponent(isHoveringScrollBar ? 0.65 : 0.45)
            ],
            locations: [0.0, 1.0]
        ) {
            context.saveGState()
            thumbPath.addClip()
            context.drawLinearGradient(
                thumbGradient,
                start: CGPoint(x: thumbRect.minX, y: thumbRect.maxY),
                end: CGPoint(x: thumbRect.minX, y: thumbRect.minY),
                options: []
            )
            context.restoreGState()
        }
        context.setStrokeColor(NSColor.white.withAlphaComponent(isHoveringScrollBar ? 0.6 : 0.35).cgColor)
        context.setLineWidth(1.0)
        thumbPath.stroke()
        context.restoreGState()
    }
    
    private func drawResizeHandle(in context: CGContext, cardRect: CGRect) {
        // CLEAR RESIZE GRIP - macOS-style indicator at bottom right
        let handleSize: CGFloat = 16
        let inset: CGFloat = 8
        resizeHandleRect = CGRect(
            x: cardRect.maxX - handleSize - inset,
            y: cardRect.minY + inset,
            width: handleSize,
            height: handleSize
        )

        // Subtle background circle on hover for better visibility
        if isHoveringResizeHandle {
            context.saveGState()
            let circleRect = resizeHandleRect.insetBy(dx: -4, dy: -4)
            let circlePath = NSBezierPath(ovalIn: circleRect)
            context.setFillColor(NSColor.black.withAlphaComponent(0.04).cgColor)
            circlePath.fill()
            context.restoreGState()
        }

        // Draw grip dots in a diagonal pattern (3x3 dots)
        context.saveGState()
        let baseOpacity: CGFloat = isHoveringResizeHandle ? 0.5 : 0.35
        let dotSize: CGFloat = 1.8
        let spacing: CGFloat = 3.5

        for row in 0..<3 {
            for col in 0..<3 {
                // Only draw dots in lower-right triangle pattern
                guard col >= row else { continue }

                let x = resizeHandleRect.minX + CGFloat(col) * spacing + 2
                let y = resizeHandleRect.minY + CGFloat(2 - row) * spacing + 2

                let dotRect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                let dotPath = NSBezierPath(ovalIn: dotRect)

                // Fade dots based on distance from corner for depth effect
                let distanceFactor = CGFloat(row + col) / 4.0
                let opacity = baseOpacity * (0.6 + (0.4 * distanceFactor))

                context.setFillColor(NSColor(calibratedWhite: 0.3, alpha: opacity).cgColor)
                dotPath.fill()
            }
        }
        context.restoreGState()
    }

    private func drawAmbientBokeh(in context: CGContext, cardRect: CGRect) {
        context.saveGState()
        let bokehColors: [NSColor] = [
            orbColor.withAlphaComponent(0.3),
            NSColor.white.withAlphaComponent(0.25),
            NSColor.white.withAlphaComponent(0.15)
        ]
        for i in 0..<5 {
            let size = CGFloat(60 + i * 20)
            let alpha = CGFloat(0.12 - Double(i) * 0.015)
            let circleRect = CGRect(
                x: cardRect.midX + CGFloat.random(in: -80...80) - size/2,
                y: cardRect.midY + CGFloat.random(in: -60...60) - size/2,
                width: size,
                height: size
            )
            let color = bokehColors[i % bokehColors.count].withAlphaComponent(alpha)
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: circleRect)
        }
        context.restoreGState()
    }

    private func drawEmptyTaskState(in context: CGContext, rect: CGRect) {
        let quietBackground = NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18)
        context.saveGState()
        context.setFillColor(NSColor(calibratedWhite: 0.96, alpha: 0.18).cgColor)
        quietBackground.fill()
        context.restoreGState()

        let heading = "No tasks yet"
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let headingAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15 * textScale, weight: .semibold),
            .foregroundColor: NSColor(calibratedWhite: 0.1, alpha: 0.9),
            .paragraphStyle: style
        ]
        let headingSize = heading.size(withAttributes: headingAttributes)
        let headingRect = CGRect(
            x: rect.midX - headingSize.width / 2,
            y: rect.midY + 20,
            width: headingSize.width,
            height: headingSize.height
        )
        heading.draw(in: headingRect, withAttributes: headingAttributes)

        // Main instruction
        let detail = "Say \"add [task]\" or press ⌘N"
        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12.5 * textScale, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.2, alpha: 0.9),
            .paragraphStyle: style
        ]
        let detailSize = detail.size(withAttributes: detailAttributes)
        let detailRect = CGRect(
            x: rect.midX - detailSize.width / 2,
            y: headingRect.minY - detailSize.height - 8,
            width: detailSize.width,
            height: detailSize.height
        )
        detail.draw(in: detailRect, withAttributes: detailAttributes)

        // Additional hint
        let hint = "You can also drag and drop items here"
        let hintAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11 * textScale, weight: .regular),
            .foregroundColor: NSColor(calibratedWhite: 0.35, alpha: 0.75),
            .paragraphStyle: style
        ]
        let hintSize = hint.size(withAttributes: hintAttributes)
        let hintRect = CGRect(
            x: rect.midX - hintSize.width / 2,
            y: detailRect.minY - hintSize.height - 6,
            width: hintSize.width,
            height: hintSize.height
        )
        hint.draw(in: hintRect, withAttributes: hintAttributes)
    }

    private func drawNoSearchResultsState(in context: CGContext, rect: CGRect) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let message = "No matching tasks"
        let messageAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14 * textScale, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.25, alpha: 0.85),
            .paragraphStyle: style
        ]
        let messageSize = message.size(withAttributes: messageAttributes)
        let messageRect = CGRect(
            x: rect.midX - messageSize.width / 2,
            y: rect.midY + 10,
            width: messageSize.width,
            height: messageSize.height
        )
        message.draw(in: messageRect, withAttributes: messageAttributes)

        let hint = "Try a different search term"
        let hintAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11 * textScale, weight: .regular),
            .foregroundColor: NSColor(calibratedWhite: 0.35, alpha: 0.7),
            .paragraphStyle: style
        ]
        let hintSize = hint.size(withAttributes: hintAttributes)
        let hintRect = CGRect(
            x: rect.midX - hintSize.width / 2,
            y: messageRect.minY - hintSize.height - 6,
            width: hintSize.width,
            height: hintSize.height
        )
        hint.draw(in: hintRect, withAttributes: hintAttributes)
    }

    private func drawTaskRow(in context: CGContext, rect: CGRect, task: Task, index: Int, checkboxRect: CGRect) {
        var rowRect = rect
        var animatedOpacity: CGFloat = 1.0
        var animatedScale: CGFloat = 1.0

        // Handle drop animation
        if let animation = dropAnimations[task.id] {
            rowRect.origin.y += animation.offsetValue
            animatedScale *= animation.scaleValue
        }

        // Handle completion animation
        if let progress = completionAnimations[task.id] {
            let values = completionAnimationValues(for: progress)
            animatedOpacity = values.opacity
            animatedScale = values.scale
        } else if task.isCompleted {
            animatedOpacity = 0.65
        }

        context.saveGState()
        if animatedScale != 1.0 {
            let centerX = rowRect.midX
            let centerY = rowRect.midY
            context.translateBy(x: centerX, y: centerY)
            context.scaleBy(x: animatedScale, y: animatedScale)
            context.translateBy(x: -centerX, y: -centerY)
        }

        // Liquid glass background - translucent with subtle blur effect
        let rowPath = NSBezierPath(roundedRect: rowRect, xRadius: 14, yRadius: 14)

        context.saveGState()
        // Liquid glass base - white with high translucency
        let glassBase = NSColor.white.withAlphaComponent(0.7 * animatedOpacity)
        context.setFillColor(glassBase.cgColor)
        rowPath.fill()
        context.restoreGState()

        // Subtle hover with orb color
        if highlightAlpha > 0.0, task.id == highlightedTaskID {
            context.saveGState()
            let highlightColor = orbColor.withAlphaComponent(Double(highlightAlpha) * 0.12)
            highlightColor.setFill()
            rowPath.fill()
            context.restoreGState()
        }

        // Very subtle border for definition
        context.saveGState()
        let borderColor = NSColor.white.withAlphaComponent(0.4 * animatedOpacity)
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(1.5)
        rowPath.stroke()
        context.restoreGState()

        // Inner shadow for depth
        context.saveGState()
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.04 * animatedOpacity).cgColor)
        context.setLineWidth(0.5)
        let innerPath = NSBezierPath(roundedRect: rowRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 14, yRadius: 14)
        innerPath.stroke()
        context.restoreGState()

        // STACKED BLOCK LAYOUT - Clear visual sections with breathing room

        // Define the two vertical sections
        let topSectionY = rowRect.maxY - TaskRowMetrics.rowVerticalPadding - 22  // Title section
        let bottomSectionY = topSectionY - TaskRowMetrics.titleMetadataGap - 18  // Metadata section

        // Checkbox aligned with title at the top
        let checkboxX = rowRect.minX + TaskRowMetrics.checkboxLeadingInset
        let checkboxY = topSectionY - (TaskRowMetrics.checkboxSize / 2) + 11  // Align with title baseline
        let newCheckboxRect = CGRect(
            x: checkboxX,
            y: checkboxY,
            width: TaskRowMetrics.checkboxSize,
            height: TaskRowMetrics.checkboxSize
        )
        drawRoundedCheckbox(in: context, rect: newCheckboxRect, isCompleted: task.isCompleted, taskId: task.id)

        // Content area - to the right of checkbox
        let contentX = newCheckboxRect.maxX + TaskRowMetrics.contentSpacing
        let contentWidth = max(0, rowRect.maxX - contentX - TaskRowMetrics.rowHorizontalPadding)

        // --- TOP SECTION: TITLE ---
        let titleRect = CGRect(x: contentX, y: topSectionY, width: contentWidth, height: 22)
        let titleFont = NSFont.systemFont(ofSize: 15 * textScale, weight: task.isCompleted ? .regular : .semibold)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let titleColor = task.isCompleted ?
            NSColor(calibratedWhite: 0.4, alpha: animatedOpacity) :
            NSColor(calibratedWhite: 0.1, alpha: animatedOpacity)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: titleColor,
            .paragraphStyle: paragraph
        ]
        task.title.draw(in: titleRect, withAttributes: titleAttributes)

        // Strikethrough for completed tasks
        if task.isCompleted, let progress = completionAnimations[task.id] {
            let strikethroughY = titleRect.midY
            let strikethroughWidth = titleRect.width * min(progress, 1.0)
            context.saveGState()
            context.setStrokeColor(NSColor(calibratedWhite: 0.35, alpha: 0.6 * animatedOpacity).cgColor)
            context.setLineWidth(1.2)
            context.move(to: CGPoint(x: titleRect.minX, y: strikethroughY))
            context.addLine(to: CGPoint(x: titleRect.minX + strikethroughWidth, y: strikethroughY))
            context.strokePath()
            context.restoreGState()
        } else if task.isCompleted {
            let strikethroughY = titleRect.midY
            context.saveGState()
            context.setStrokeColor(NSColor(calibratedWhite: 0.35, alpha: 0.6 * animatedOpacity).cgColor)
            context.setLineWidth(1.2)
            context.move(to: CGPoint(x: titleRect.minX, y: strikethroughY))
            context.addLine(to: CGPoint(x: titleRect.maxX, y: strikethroughY))
            context.strokePath()
            context.restoreGState()
        }

        // --- BOTTOM SECTION: METADATA (with clear visual separation) ---
        var metadataX = contentX
        let metadataFont = NSFont.systemFont(ofSize: 11.5 * textScale, weight: .medium)
        let metadataColor = NSColor(calibratedWhite: 0.5, alpha: animatedOpacity)

        // Note count (instead of showing snippet)
        let noteLines = task.details.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if !noteLines.isEmpty {
            let noteText = noteLines.count == 1 ? "1 note" : "\(noteLines.count) notes"
            let noteAttributes: [NSAttributedString.Key: Any] = [
                .font: metadataFont,
                .foregroundColor: metadataColor
            ]
            let noteSize = noteText.size(withAttributes: noteAttributes)
            let noteRect = CGRect(x: metadataX, y: bottomSectionY, width: noteSize.width, height: noteSize.height)
            noteText.draw(in: noteRect, withAttributes: noteAttributes)
            metadataX += noteSize.width + 10
        }

        // Priority and deadline chips in the metadata section
        let chips = makeTaskRowChips(for: task, orbColor: orbColor)
        if !chips.isEmpty {
            for chip in chips {
                let chipWidth = chip.text.size(withAttributes: [.font: NSFont.systemFont(ofSize: 11 * textScale, weight: .medium)]).width + TaskRowMetrics.chipHorizontalPadding * 2

                let chipRect = CGRect(
                    x: metadataX,
                    y: bottomSectionY - 1,
                    width: chipWidth,
                    height: TaskRowMetrics.chipHeight - 2
                )

                if chipRect.maxX <= rowRect.maxX - TaskRowMetrics.rowHorizontalPadding {
                    drawCompactChip(chip, in: context, rect: chipRect, opacity: animatedOpacity)
                    metadataX += chipWidth + TaskRowMetrics.chipSpacing
                }
            }
        }

        context.restoreGState()
    }

    private func drawLiquidChip(_ chip: TaskRowChip, in context: CGContext, rect: CGRect, opacity: CGFloat) {
        let chipPath = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)

        context.saveGState()
        // Liquid glass chip background
        let bgColor = chip.background.withAlphaComponent(0.18 * opacity)
        context.setFillColor(bgColor.cgColor)
        chipPath.fill()
        context.restoreGState()

        // Subtle border
        context.saveGState()
        context.setStrokeColor(chip.background.withAlphaComponent(0.25 * opacity).cgColor)
        context.setLineWidth(1.0)
        chipPath.stroke()
        context.restoreGState()

        // Text
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12 * textScale, weight: .medium),
            .foregroundColor: chip.foreground.withAlphaComponent(0.85 * opacity)
        ]
        let textSize = chip.text.size(withAttributes: textAttributes)
        let textRect = CGRect(
            x: rect.minX + (rect.width - textSize.width) / 2,
            y: rect.minY + (rect.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        chip.text.draw(in: textRect, withAttributes: textAttributes)
    }

    private func drawMinimalChip(_ chip: TaskRowChip, in context: CGContext, rect: CGRect, opacity: CGFloat) {
        let chipPath = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)

        context.saveGState()
        // Subtle background
        let bgColor = chip.background.withAlphaComponent(0.12 * opacity)
        context.setFillColor(bgColor.cgColor)
        chipPath.fill()
        context.restoreGState()

        // Text
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11 * textScale, weight: .medium),
            .foregroundColor: chip.foreground.withAlphaComponent(0.75 * opacity)
        ]
        let textSize = chip.text.size(withAttributes: textAttributes)
        let textRect = CGRect(
            x: rect.minX + (rect.width - textSize.width) / 2,
            y: rect.minY + (rect.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        chip.text.draw(in: textRect, withAttributes: textAttributes)
    }

    private func drawCompactChip(_ chip: TaskRowChip, in context: CGContext, rect: CGRect, opacity: CGFloat) {
        // Compact chip for metadata section - even more minimal
        let chipPath = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)

        context.saveGState()
        // Very subtle background
        let bgColor = chip.background.withAlphaComponent(0.1 * opacity)
        context.setFillColor(bgColor.cgColor)
        chipPath.fill()
        context.restoreGState()

        // Text - smaller font for metadata section
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11 * textScale, weight: .medium),
            .foregroundColor: chip.foreground.withAlphaComponent(0.7 * opacity)
        ]
        let textSize = chip.text.size(withAttributes: textAttributes)
        let textRect = CGRect(
            x: rect.minX + (rect.width - textSize.width) / 2,
            y: rect.minY + (rect.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        chip.text.draw(in: textRect, withAttributes: textAttributes)
    }

    private func drawRoundedCheckbox(in context: CGContext, rect: CGRect, isCompleted: Bool, taskId: UUID) {
        // Get checkbox pop scale if animating
        let scale = checkboxPopAnimations[taskId]?.value ?? 1.0

        context.saveGState()

        // Apply scale transformation around checkbox center
        if scale != 1.0 {
            context.translateBy(x: rect.midX, y: rect.midY)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -rect.midX, y: -rect.midY)
        }

        // Circular checkbox with liquid glass aesthetic
        let checkboxPath = NSBezierPath(roundedRect: rect, xRadius: rect.width / 2, yRadius: rect.height / 2)

        context.saveGState()
        // Liquid glass background
        if isCompleted {
            // Solid orb color when completed
            context.setFillColor(orbColor.cgColor)
        } else {
            // Translucent white when uncompleted
            context.setFillColor(NSColor.white.withAlphaComponent(0.5).cgColor)
        }
        checkboxPath.fill()
        context.restoreGState()

        // Refined border
        context.saveGState()
        if isCompleted {
            // Subtle border on completed - slightly darker shade
            context.setStrokeColor(orbColor.withAlphaComponent(0.9).cgColor)
            context.setLineWidth(2.0)
        } else {
            // Light border on uncompleted
            context.setStrokeColor(NSColor(calibratedWhite: 0.6, alpha: 0.8).cgColor)
            context.setLineWidth(2.0)
        }
        checkboxPath.stroke()
        context.restoreGState()

        // Clean checkmark
        if isCompleted {
            context.saveGState()
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(2.2)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            let checkmarkPath = NSBezierPath()
            let checkmarkSize = rect.width * 0.48
            let startX = rect.midX - checkmarkSize * 0.3
            let startY = rect.midY - checkmarkSize * 0.05
            let midX = rect.midX - checkmarkSize * 0.05
            let midY = rect.midY + checkmarkSize * 0.3
            let endX = rect.midX + checkmarkSize * 0.35
            let endY = rect.midY - checkmarkSize * 0.25
            checkmarkPath.move(to: CGPoint(x: startX, y: startY))
            checkmarkPath.line(to: CGPoint(x: midX, y: midY))
            checkmarkPath.line(to: CGPoint(x: endX, y: endY))
            checkmarkPath.stroke()
            context.restoreGState()
        }

        context.restoreGState()
    }
    
    private func drawLiquidParticles(in context: CGContext, cardRect: NSRect) {
        // Subtle flowing particles for liquid effect
        for i in 0..<5 {
            let particlePhase = animationPhase + Double(i) * 1.2
            let particleX = cardRect.minX + CGFloat(cos(particlePhase * 0.2) * cardRect.width * 0.3) + cardRect.width * 0.5
            let particleY = cardRect.minY + CGFloat(sin(particlePhase * 0.15) * cardRect.height * 0.2) + cardRect.height * 0.5
            let particleSize = 1.5 + CGFloat(sin(particlePhase * 0.8) * 0.8)
            let particleAlpha = 0.3 + CGFloat(sin(particlePhase * 0.6) * 0.2)
            
            context.saveGState()
            context.setFillColor(NSColor.white.withAlphaComponent(particleAlpha).cgColor)
            context.addEllipse(in: CGRect(x: particleX - particleSize/2, y: particleY - particleSize/2, width: particleSize, height: particleSize))
            context.fillPath()
            context.restoreGState()
        }
    }
}


enum TaskRowMetrics {
    // STACKED BLOCK design with clear visual sections
    static let rowHeight: CGFloat = 72  // Taller for stacked sections
    static let rowSpacing: CGFloat = 10  // Moderate space between blocks
    static let listInset: CGFloat = 28  // Clean insets
    static let rowVerticalPadding: CGFloat = 16  // Padding within each block
    static let rowHorizontalPadding: CGFloat = 20  // Horizontal space
    static let checkboxLeadingInset: CGFloat = 20  // Checkbox on left
    static let contentSpacing: CGFloat = 14  // Space between checkbox and content
    static let checkboxSize: CGFloat = 22  // Nice visible size
    static let dragHitWidth: CGFloat = 44
    static let chipHeight: CGFloat = 20  // Chip size
    static let chipHorizontalPadding: CGFloat = 10
    static let chipSpacing: CGFloat = 8
    static let chipVerticalSpacing: CGFloat = 6
    static let titleMetadataGap: CGFloat = 10  // Gap between title and metadata sections
    static let metadataTopInset: CGFloat = 28
    static let controlBarHeight: CGFloat = 48
    static let headerHeight: CGFloat = 120
    static let headerDividerSpacing: CGFloat = 20
    static let cardInset: CGFloat = 28
    static let dragGripHeight: CGFloat = controlBarHeight
    static let scrollBarWidth: CGFloat = 6
    static let scrollBarSpacing: CGFloat = 16
}

private let taskRowRelativeFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.dateTimeStyle = .named
    formatter.unitsStyle = .short
    return formatter
}()

private func makeTaskRowChips(for task: Task, orbColor: NSColor, referenceDate: Date = Date()) -> [TaskRowChip] {
    var chips: [TaskRowChip] = []
    
    // Build combined pill with priority + deadline
    var pillText = ""
    var pillForeground: NSColor = NSColor(calibratedWhite: 0.1, alpha: 0.94)
    var pillBackground: NSColor = NSColor.white.withAlphaComponent(0.15)
    
    // Priority indicator (textual)
    let priorityColor: NSColor
    let priorityLabelText: String
    switch task.priority {
    case Int.min...1:
        priorityColor = NSColor.systemBlue.withAlphaComponent(0.75)
        priorityLabelText = "Low"
    case 2:
        priorityColor = NSColor.systemGreen.withAlphaComponent(0.75)
        priorityLabelText = "Medium"
    case 3:
        priorityColor = NSColor.systemYellow.withAlphaComponent(0.75)
        priorityLabelText = "High"
    case 4:
        priorityColor = NSColor.systemOrange.withAlphaComponent(0.75)
        priorityLabelText = "Urgent"
    default:
        priorityColor = NSColor.systemRed.withAlphaComponent(0.85)
        priorityLabelText = "Critical"
    }
    
    // Deadline text
    var deadlineText = ""
    if task.isCompleted {
        deadlineText = "Completed"
        pillBackground = NSColor.systemGreen.withAlphaComponent(0.20)
        pillForeground = NSColor(calibratedWhite: 0.35, alpha: 0.95)
    } else if let deadline = task.deadline {
        let calendar = Calendar.current
        if deadline < referenceDate {
            deadlineText = "Overdue"
            pillBackground = NSColor.systemRed.withAlphaComponent(0.20)
            pillForeground = NSColor.systemRed.withAlphaComponent(0.9)
        } else if calendar.isDateInToday(deadline) {
            deadlineText = "Today"
            pillBackground = NSColor.systemOrange.withAlphaComponent(0.20)
            pillForeground = NSColor.systemOrange.withAlphaComponent(0.9)
        } else if calendar.isDateInTomorrow(deadline) {
            deadlineText = "Tomorrow"
            pillBackground = NSColor.systemYellow.withAlphaComponent(0.20)
            pillForeground = NSColor.systemYellow.withAlphaComponent(0.9)
        } else {
            let relative = taskRowRelativeFormatter.localizedString(for: deadline, relativeTo: referenceDate)
            deadlineText = relative
            pillBackground = orbColor.withAlphaComponent(0.18)
            pillForeground = orbColor.withAlphaComponent(0.85)
        }
    }
    
    // Combine priority dots + deadline
    if !task.isCompleted && !deadlineText.isEmpty {
        pillText = "\(priorityLabelText) • \(deadlineText)"
        pillBackground = orbColor.withAlphaComponent(0.14)
        pillForeground = NSColor(calibratedWhite: 0.1, alpha: 0.94)
    } else if !task.isCompleted {
        pillText = "\(priorityLabelText) Priority"
        pillBackground = priorityColor.withAlphaComponent(0.16)
        pillForeground = NSColor(calibratedWhite: 0.1, alpha: 0.94)
    } else {
        pillText = deadlineText
    }

    pillForeground = task.isCompleted ? pillForeground : NSColor(calibratedWhite: 0.1, alpha: 0.94)
    if !pillText.isEmpty {
        chips.append(TaskRowChip(
            text: pillText,
            foreground: pillForeground,
            background: pillBackground,
            border: nil
        ))
    }
    
    return chips
}

private func drawTaskChips(_ chips: [TaskRowChip], startingAt startX: CGFloat, baselineY: CGFloat, context: CGContext) -> CGFloat {
    var currentX = startX
    let font = NSFont.systemFont(ofSize: 11 * TextSizePreference.scaleFactor, weight: .medium)
    let pillPadding: CGFloat = TaskRowMetrics.chipHorizontalPadding
    let pillHeight: CGFloat = TaskRowMetrics.chipHeight
    
    for chip in chips {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: chip.foreground
        ]
        let textSize = chip.text.size(withAttributes: attributes)
        let pillWidth = textSize.width + (pillPadding * 2)
        let pillRect = CGRect(
            x: currentX,
            y: baselineY,
            width: pillWidth,
            height: pillHeight
        )
        
        // Draw pill background
        let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: pillHeight / 2, yRadius: pillHeight / 2)
        context.saveGState()
        context.setFillColor(chip.background.cgColor)
        pillPath.fill()
        context.restoreGState()
        
        // Draw pill border if specified
        if let border = chip.border {
            context.saveGState()
            context.setStrokeColor(border.cgColor)
            context.setLineWidth(1.0)
            pillPath.stroke()
            context.restoreGState()
        }
        
        // Draw text centered in pill
        let textRect = CGRect(
            x: pillRect.minX + pillPadding,
            y: baselineY + (pillHeight - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        chip.text.draw(in: textRect, withAttributes: attributes)
        currentX += pillWidth + TaskRowMetrics.chipSpacing
    }
    return currentX
}

// MARK: - Task Drag View
class TaskDragView: NSView {
    private var task: Task
    private var orbColor: NSColor
    
    init(task: Task, orbColor: NSColor) {
        self.task = task
        self.orbColor = orbColor
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: TaskRowMetrics.rowHeight))
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let rowRect = bounds.insetBy(dx: 4, dy: 4)
        let path = NSBezierPath(roundedRect: rowRect, xRadius: 14, yRadius: 14)

        // Liquid glass background with drop shadow
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 4), blur: 12, color: NSColor.black.withAlphaComponent(0.2).cgColor)
        context.setFillColor(NSColor.white.withAlphaComponent(0.85).cgColor)
        path.fill()
        context.restoreGState()

        // Subtle border
        context.saveGState()
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(1.5)
        path.stroke()
        context.restoreGState()

        // Checkbox on left
        let checkboxRect = CGRect(
            x: rowRect.minX + TaskRowMetrics.checkboxLeadingInset,
            y: rowRect.midY - TaskRowMetrics.checkboxSize / 2,
            width: TaskRowMetrics.checkboxSize,
            height: TaskRowMetrics.checkboxSize
        )
        drawRoundedCheckbox(in: context, rect: checkboxRect, isCompleted: task.isCompleted)

        // Title to the right of checkbox
        let contentX = checkboxRect.maxX + TaskRowMetrics.contentSpacing
        let contentWidth = max(0, rowRect.maxX - contentX - TaskRowMetrics.rowHorizontalPadding)
        let titleRect = CGRect(x: contentX, y: rowRect.midY - 9, width: contentWidth, height: 20)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15 * TextSizePreference.scaleFactor, weight: .semibold),
            .foregroundColor: NSColor(calibratedWhite: 0.1, alpha: 1.0),
            .paragraphStyle: paragraph
        ]
        task.title.draw(in: titleRect, withAttributes: titleAttributes)
    }

    private func drawRoundedCheckbox(in context: CGContext, rect: CGRect, isCompleted: Bool) {
        let checkboxPath = NSBezierPath(roundedRect: rect, xRadius: rect.width / 2, yRadius: rect.height / 2)

        context.saveGState()
        if isCompleted {
            context.setFillColor(orbColor.cgColor)
        } else {
            context.setFillColor(NSColor.white.withAlphaComponent(0.5).cgColor)
        }
        checkboxPath.fill()
        context.restoreGState()

        context.saveGState()
        if isCompleted {
            context.setStrokeColor(orbColor.withAlphaComponent(0.9).cgColor)
            context.setLineWidth(2.0)
        } else {
            context.setStrokeColor(NSColor(calibratedWhite: 0.6, alpha: 0.8).cgColor)
            context.setLineWidth(2.0)
        }
        checkboxPath.stroke()
        context.restoreGState()

        if isCompleted {
            context.saveGState()
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(2.2)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            let checkmarkPath = NSBezierPath()
            let size = rect.width * 0.48
            let startX = rect.midX - size * 0.3
            let startY = rect.midY - size * 0.05
            let midX = rect.midX - size * 0.05
            let midY = rect.midY + size * 0.3
            let endX = rect.midX + size * 0.35
            let endY = rect.midY - size * 0.25
            checkmarkPath.move(to: CGPoint(x: startX, y: startY))
            checkmarkPath.line(to: CGPoint(x: midX, y: midY))
            checkmarkPath.line(to: CGPoint(x: endX, y: endY))
            checkmarkPath.stroke()
            context.restoreGState()
        }
    }
}

// MARK: - Celebration Effects System

/// Particle type for different celebration effects
enum ParticleType {
    case confetti
    case sparkle
    case star
    case check
}

/// Individual particle for animations
class Particle {
    var position: CGPoint
    var velocity: CGPoint
    var color: NSColor
    var size: CGFloat
    var alpha: CGFloat
    var rotation: CGFloat
    var rotationSpeed: CGFloat
    var lifetime: CFTimeInterval
    var age: CFTimeInterval = 0
    var type: ParticleType

    init(position: CGPoint, velocity: CGPoint, color: NSColor, size: CGFloat, type: ParticleType) {
        self.position = position
        self.velocity = velocity
        self.color = color
        self.size = size
        self.alpha = 1.0
        self.rotation = CGFloat.random(in: 0...(.pi * 2))
        self.rotationSpeed = CGFloat.random(in: -8...8)
        self.lifetime = Double.random(in: 0.6...1.2)
        self.type = type
    }

    func update(deltaTime: CFTimeInterval) -> Bool {
        age += deltaTime

        // Physics
        position.x += velocity.x * deltaTime
        position.y += velocity.y * deltaTime

        // Gravity
        velocity.y -= 400 * deltaTime

        // Air resistance
        velocity.x *= 0.98
        velocity.y *= 0.98

        // Rotation
        rotation += rotationSpeed * deltaTime

        // Fade out
        let normalizedAge = age / lifetime
        alpha = max(0, 1.0 - normalizedAge)

        return age < lifetime
    }
}

// MARK: - Particle Emitter

class ParticleEmitter {
    private var particles: [Particle] = []
    private var isActive = false

    func emit(at position: CGPoint, type: ParticleType, count: Int = 20) {
        isActive = true

        let colors: [NSColor] = [
            .systemYellow, .systemOrange, .systemPink,
            .systemPurple, .systemBlue, .systemGreen,
            .systemRed, .systemTeal
        ]

        for _ in 0..<count {
            let angle = CGFloat.random(in: 0...(.pi * 2))
            let speed = CGFloat.random(in: 150...400)
            let velocity = CGPoint(
                x: cos(angle) * speed,
                y: sin(angle) * speed + 200 // Bias upward
            )

            let color = colors.randomElement() ?? .systemYellow
            let size = CGFloat.random(in: 4...10)

            let particle = Particle(
                position: position,
                velocity: velocity,
                color: color,
                size: size,
                type: type
            )

            particles.append(particle)
        }
    }

    func update(deltaTime: CFTimeInterval) {
        particles.removeAll { !$0.update(deltaTime: deltaTime) }

        if particles.isEmpty {
            isActive = false
        }
    }

    func draw(in context: CGContext) {
        guard !particles.isEmpty else { return }

        context.saveGState()

        for particle in particles {
            context.saveGState()

            // Translate and rotate
            context.translateBy(x: particle.position.x, y: particle.position.y)
            context.rotate(by: particle.rotation)

            let color = particle.color.withAlphaComponent(particle.alpha)
            context.setFillColor(color.cgColor)

            switch particle.type {
            case .confetti:
                // Rectangle confetti
                let rect = CGRect(
                    x: -particle.size / 2,
                    y: -particle.size,
                    width: particle.size,
                    height: particle.size * 2
                )
                context.fill(rect)

            case .sparkle, .star:
                // Star shape
                drawStar(in: context, size: particle.size)

            case .check:
                // Checkmark
                drawCheckmark(in: context, size: particle.size, color: color)
            }

            context.restoreGState()
        }

        context.restoreGState()
    }

    private func drawStar(in context: CGContext, size: CGFloat) {
        let points = 5
        let outerRadius = size
        let innerRadius = size * 0.4

        context.beginPath()

        for i in 0..<points * 2 {
            let angle = CGFloat(i) * .pi / CGFloat(points)
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let x = cos(angle - .pi / 2) * radius
            let y = sin(angle - .pi / 2) * radius

            if i == 0 {
                context.move(to: CGPoint(x: x, y: y))
            } else {
                context.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.closePath()
        context.fillPath()
    }

    private func drawCheckmark(in context: CGContext, size: CGFloat, color: NSColor) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(size * 0.2)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        context.beginPath()
        context.move(to: CGPoint(x: -size * 0.3, y: 0))
        context.addLine(to: CGPoint(x: -size * 0.1, y: -size * 0.3))
        context.addLine(to: CGPoint(x: size * 0.4, y: size * 0.4))
        context.strokePath()
    }

    var hasActiveParticles: Bool {
        return isActive && !particles.isEmpty
    }
}

// MARK: - Celebration Sound Manager

class CelebrationSounds {
    static let shared = CelebrationSounds()

    private var completionPlayer: AVAudioPlayer?
    private var celebrationPlayer: AVAudioPlayer?

    private init() {
        setupSounds()
    }

    private func setupSounds() {
        // We'll use system sounds as fallback
        // In production, you'd include custom sound files
    }

    func playCompletion() {
        // Play a satisfying completion sound
        playSystemSound(soundID: 1057) // Pop sound
    }

    func playCelebration() {
        // Play celebration for multiple completions
        playSystemSound(soundID: 1111) // Success sound
    }

    func playUndo() {
        // Subtle undo sound
        playSystemSound(soundID: 1006) // Swoosh
    }

    private func playSystemSound(soundID: SystemSoundID) {
        guard AudioFeedback.shared.isEnabled else { return }
        AudioServicesPlaySystemSound(soundID)
    }
}

// MARK: - Ripple Effect

class RippleEffect {
    private var radius: CGFloat = 0
    private var maxRadius: CGFloat = 100
    private var alpha: CGFloat = 1.0
    private var isActive = false
    private var age: CFTimeInterval = 0
    private let lifetime: CFTimeInterval = 0.8
    private var center: CGPoint = .zero
    private var color: NSColor = .systemGreen

    func trigger(at point: CGPoint, color: NSColor = .systemGreen, maxRadius: CGFloat = 100) {
        self.center = point
        self.color = color
        self.maxRadius = maxRadius
        self.radius = 0
        self.alpha = 1.0
        self.age = 0
        self.isActive = true
    }

    func update(deltaTime: CFTimeInterval) {
        guard isActive else { return }

        age += deltaTime
        let progress = age / lifetime

        radius = maxRadius * CGFloat(progress)
        alpha = 1.0 - CGFloat(progress)

        if age >= lifetime {
            isActive = false
        }
    }

    func draw(in context: CGContext) {
        guard isActive else { return }

        context.saveGState()

        let rippleColor = color.withAlphaComponent(alpha * 0.4)
        context.setStrokeColor(rippleColor.cgColor)
        context.setLineWidth(3)

        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        context.strokeEllipse(in: rect)

        context.restoreGState()
    }

    var hasActiveRipple: Bool {
        return isActive
    }
}

// MARK: - Celebration Manager

class CelebrationManager {
    static let shared = CelebrationManager()

    private let particleEmitter = ParticleEmitter()
    private let rippleEffect = RippleEffect()
    private var consecutiveCompletions = 0
    private var lastCompletionTime: CFTimeInterval = 0

    private init() {}

    func celebrateTaskCompletion(at position: CGPoint, color: NSColor = .systemGreen) {
        let now = CACurrentMediaTime()

        // Track consecutive completions for extra celebration
        if now - lastCompletionTime < 3.0 {
            consecutiveCompletions += 1
        } else {
            consecutiveCompletions = 1
        }

        lastCompletionTime = now

        // Ripple effect
        rippleEffect.trigger(at: position, color: color, maxRadius: 60)

        // Particle count based on streak
        let particleCount = min(20 + consecutiveCompletions * 5, 50)

        // Confetti burst
        particleEmitter.emit(at: position, type: .confetti, count: particleCount)

        // Sound effect
        if consecutiveCompletions >= 3 {
            CelebrationSounds.shared.playCelebration()
        } else {
            CelebrationSounds.shared.playCompletion()
        }

        // Bonus sparkles for streaks
        if consecutiveCompletions >= 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.particleEmitter.emit(at: position, type: .sparkle, count: 15)
            }
        }
    }

    func celebrateUndo(at position: CGPoint) {
        rippleEffect.trigger(at: position, color: .systemOrange, maxRadius: 40)
        CelebrationSounds.shared.playUndo()
    }

    func update(deltaTime: CFTimeInterval) {
        particleEmitter.update(deltaTime: deltaTime)
        rippleEffect.update(deltaTime: deltaTime)
    }

    func draw(in context: CGContext) {
        rippleEffect.draw(in: context)
        particleEmitter.draw(in: context)
    }

    var hasActiveEffects: Bool {
        return particleEmitter.hasActiveParticles || rippleEffect.hasActiveRipple
    }
}
