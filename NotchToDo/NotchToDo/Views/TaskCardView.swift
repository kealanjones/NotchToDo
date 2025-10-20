import QuartzCore
import Cocoa

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
    private var projectName: String = ""
    private var orbColor: NSColor = .systemBlue
    private var animationPhase: Double = 0.0
    private weak var controller: NotchOverlayController?
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
    private var currentOrbId: UUID?
    
    // Celebration animation properties
    private var celebrationPhase: CGFloat = 0.0
    private var isCelebrating = false
    
    // Task completion animation
    private var completionAnimations: [UUID: CGFloat] = [:]
    private var isAmbientAnimationActive = false
    private var isTickerRegistered = false
    
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
        let shouldObserve = isAmbientAnimationActive || highlightActive || isCelebrating || !completionAnimations.isEmpty || dropActive || dragWindowActive || scrollSpringActive || liftActive
        if shouldObserve && !isTickerRegistered {
            FrameTicker.shared.addObserver(self)
            isTickerRegistered = true
        } else if !shouldObserve && isTickerRegistered {
            FrameTicker.shared.removeObserver(self)
            isTickerRegistered = false
        }
    }
    
    func frameTick(deltaTime: CFTimeInterval) {
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
            let previousValue = scrollOffsetSpring.value
            let stillAnimating = scrollOffsetSpring.update(deltaTime: deltaTime)
            let clamped = max(0.0, min(scrollOffsetSpring.value, maxScrollOffset))
            if abs(previousValue - clamped) > 0.0001 || abs(taskScrollOffset - clamped) > 0.0001 {
                taskScrollOffset = clamped
                requiresDisplay = true
            }
            isScrollSpringActive = stillAnimating || !scrollOffsetSpring.isAtRest
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

        if requiresDisplay || liftAnimating {
            needsDisplay = true
        }

        updateTickerSubscription()
    }
    
    override func layout() {
        super.layout()
        let cardRect = bounds.insetBy(dx: TaskRowMetrics.cardInset, dy: TaskRowMetrics.cardInset)
        glassEffectView.frame = cardRect
        glassEffectView.layer?.cornerRadius = 28
    }
    
    override var isOpaque: Bool {
        return false
    }
    
    func getPinnedState() -> Bool {
        return isPinned
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
        
        // Trigger completion animation if task was just completed
        if !wasCompleted && task.isCompleted {
            startTaskCompletionAnimation(for: task)
            startCelebrationAnimation()
            // Notify controller to trigger orb dancing
            controller?.triggerOrbCelebration()
        } else if wasCompleted && !task.isCompleted {
            // Reset animation state when uncompleting
            completionAnimations.removeValue(forKey: task.id)
            updateTickerSubscription()
        }
        
        // Recalculate scroll in case task visibility changed
        calculateMaxScrollOffset()
        needsDisplay = true
        
        DebugLog.log("Task \(task.title) marked as \(task.isCompleted ? "completed" : "incomplete")", category: .tasks)
    }
    
    private func startTaskCompletionAnimation(for task: Task) {
        completionAnimations[task.id] = 0.0
        updateTickerSubscription()
        needsDisplay = true
    }
    
    private func openTaskDetail(for index: Int) {
        guard index < tasks.count else { return }
        
        let task = tasks[index]
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
        guard resolvedHeight > 0 else {
            maxScrollOffset = 0
            taskScrollOffset = 0
            scrollOffsetSpring.snap(to: 0)
            scrollOffsetSpring.setTarget(0)
            isScrollSpringActive = false
            return
        }
        
        let taskCount = CGFloat(tasks.count)
        if taskCount <= 0 {
            maxScrollOffset = 0
            taskScrollOffset = 0
            scrollOffsetSpring.snap(to: 0)
            scrollOffsetSpring.setTarget(0)
            isScrollSpringActive = false
            return
        }
        
        let contentHeight = taskCount * TaskRowMetrics.rowHeight + max(0, taskCount - 1) * TaskRowMetrics.rowSpacing
        maxScrollOffset = max(0, contentHeight - resolvedHeight)
        taskScrollOffset = max(0, min(taskScrollOffset, maxScrollOffset))
        scrollOffsetSpring.snap(to: taskScrollOffset)
        scrollOffsetSpring.setTarget(taskScrollOffset)
        isScrollSpringActive = false
    }
    
    private func defaultListHeight() -> CGFloat {
        let cardRect = bounds.insetBy(dx: TaskRowMetrics.cardInset, dy: TaskRowMetrics.cardInset)
        let headerBottom = cardRect.maxY - TaskRowMetrics.headerHeight
        return max(0, headerBottom - (cardRect.minY + TaskRowMetrics.listInset) - TaskRowMetrics.headerDividerSpacing)
    }
    
    private func configureGlassEffect() {
        glassEffectView.material = .hudWindow
        glassEffectView.state = .active
        glassEffectView.blendingMode = .withinWindow
        glassEffectView.isEmphasized = true
        glassEffectView.wantsLayer = true
        glassEffectView.layer?.cornerRadius = 28
        glassEffectView.layer?.masksToBounds = true
        glassEffectView.alphaValue = 0.65
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
    
    override func mouseDown(with event: NSEvent) {
        let locationInView = convert(event.locationInWindow, from: nil)
        
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
        
        // Scroll bar is now visual only - no drag interaction needed

        // Check if click is on a grab handle (only way to start dragging)
        if let grabHandleIndex = getClickedGrabHandleIndex(at: locationInView) {
            startTaskDrag(taskIndex: grabHandleIndex, location: locationInView)
            return
        }
        
        // Check if click is on a checkbox
        if let checkboxIndex = getClickedCheckboxIndex(at: locationInView) {
            toggleTaskCompletion(at: checkboxIndex)
            return
        }
        
        // Check if click is on a task (to open task detail)
        if let taskIndex = getClickedTaskIndex(at: locationInView) {
            openTaskDetail(for: taskIndex)
            return
        }
        
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
        // Only handle scrolling if there are tasks to scroll and we're not dragging
        guard maxScrollOffset > 0 && !isDraggingTask else { return }
        
        // Reset fade timer on scroll
        if !isPinned {
            controller?.resetFadeTimer()
        }
        
        let scrollDelta = event.scrollingDeltaY
        let scrollSensitivity: CGFloat = 2.0
        
        // Calculate new offset (reverse direction: scroll down = negative delta = decrease offset)
        let newOffset = taskScrollOffset - (scrollDelta * scrollSensitivity)
        
        let clampedOffset = max(0, min(newOffset, maxScrollOffset))
        scrollOffsetSpring.setTarget(clampedOffset)
        if !isScrollSpringActive {
            scrollOffsetSpring.snap(to: taskScrollOffset)
        }
        isScrollSpringActive = true
        needsDisplay = true
        updateTickerSubscription()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Clear to transparent
        context.clear(dirtyRect)
        
        let cardRect = bounds.insetBy(dx: TaskRowMetrics.cardInset, dy: TaskRowMetrics.cardInset)
        
        drawGlassBackground(in: context, cardRect: cardRect)
        let controlsBottom = drawHeaderControls(in: context, cardRect: cardRect)
        
        if isShowingDropIndicator {
            drawDropTargetHalo(in: context, cardRect: cardRect)
        }
        
        if isCelebrating {
            drawCelebrationRimGlow(in: context, cardRect: cardRect)
        }
        
        drawProjectHeader(in: context, cardRect: cardRect, contentTop: controlsBottom - 12.0)
        drawTaskList(in: context, cardRect: cardRect)
        drawResizeHandle(in: context, cardRect: cardRect)
    }
    
    private func drawGlassBackground(in context: CGContext, cardRect: CGRect) {
        let lift = max(0.0, min(1.0, cardLiftSpring.value))
        var fillColor = glassBaseFill(for: orbColor)
        fillColor = fillColor.withAlphaComponent(min(1.0, fillColor.alphaComponent + 0.1 * lift))
        let gradientStops = glassGradientStops(for: orbColor)
        let clipPath = NSBezierPath(roundedRect: cardRect, xRadius: 28, yRadius: 28)

        context.saveGState()
        clipPath.addClip()
        
        // Base fill keeps the palette pale with a subtle orb tint, matching row glass styling
        context.setFillColor(fillColor.cgColor)
        clipPath.fill()
        
        // Apply a linear gradient to tease out the liquid depth (mirrors task row treatment)
        if let gradient = GradientCache.shared.gradient(
            cgColors: gradientStops,
            locations: [0.0, 0.55, 1.0]
        ) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: cardRect.midX, y: cardRect.maxY),
                end: CGPoint(x: cardRect.midX, y: cardRect.minY),
                options: []
            )
            if lift > 0.001 {
                context.setFillColor(orbColor.withAlphaComponent(0.08 * lift).cgColor)
                context.fill(cardRect)
            }
        }
        context.restoreGState()

        // Subtle interior shadow keeps the same pillowy depth used on individual rows
        context.saveGState()
        let shadowPath = NSBezierPath(roundedRect: cardRect, xRadius: 28, yRadius: 28)
        let innerAlpha = 0.4 + (0.15 * lift)
        context.setFillColor(fillColor.withAlphaComponent(innerAlpha).cgColor)
        let shadowBlur = 4.5 + 6.0 * lift
        let shadowOffset = CGSize(width: 0, height: -2.0 + (-1.0 * lift))
        context.setShadow(offset: shadowOffset, blur: shadowBlur, color: NSColor.black.withAlphaComponent(0.05 + 0.06 * lift).cgColor)
        shadowPath.fill()
        context.restoreGState()

        // Orb tinted rim
        context.saveGState()
        let rimAlpha = 0.14 + 0.1 * lift
        context.setStrokeColor(orbColor.withAlphaComponent(rimAlpha).cgColor)
        context.setLineWidth(1.0)
        clipPath.stroke()
        context.restoreGState()
    }
    
    @discardableResult
    private func drawHeaderControls(in context: CGContext, cardRect: CGRect) -> CGFloat {
        let barHeight = TaskRowMetrics.controlBarHeight
        let topPadding: CGFloat = 18
        let horizontalPadding: CGFloat = 24
        let buttonSpacing: CGFloat = 8
        let barRect = CGRect(
            x: cardRect.minX + horizontalPadding,
            y: cardRect.maxY - topPadding - barHeight,
            width: cardRect.width - horizontalPadding * 2,
            height: barHeight
        )

        dragGripRect = barRect.insetBy(dx: -4, dy: 6)

        let barPath = NSBezierPath(roundedRect: barRect, xRadius: barHeight / 2, yRadius: barHeight / 2)
        let baseFill = NSColor(calibratedWhite: 0.08, alpha: 0.28)
        let strokeColor = NSColor.white.withAlphaComponent(0.1)

        context.saveGState()
        context.setFillColor(baseFill.cgColor)
        barPath.fill()
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(1.0)
        barPath.stroke()
        context.restoreGState()

        let controlSize = barHeight - 10
        closeButtonRect = CGRect(
            x: barRect.minX + 10,
            y: barRect.midY - controlSize / 2,
            width: controlSize,
            height: controlSize
        )
        deleteButtonRect = CGRect(
            x: barRect.maxX - controlSize - 10,
            y: barRect.midY - controlSize / 2,
            width: controlSize,
            height: controlSize
        )
        pinButtonRect = CGRect(
            x: deleteButtonRect.minX - buttonSpacing - controlSize,
            y: barRect.midY - controlSize / 2,
            width: controlSize,
            height: controlSize
        )

        drawHeaderButton(
            in: context,
            rect: closeButtonRect,
            baseFill: NSColor(calibratedWhite: 0.16, alpha: 0.55),
            activeFill: NSColor.systemRed.withAlphaComponent(0.75),
            isHovered: isHoveringClose,
            isActive: false
        ) { ctx, iconRect, tint in
            drawCloseGlyph(in: ctx, rect: iconRect, color: tint)
        }

        drawHeaderButton(
            in: context,
            rect: pinButtonRect,
            baseFill: NSColor(calibratedWhite: 0.16, alpha: 0.55),
            activeFill: orbColor.withAlphaComponent(0.75),
            isHovered: isHoveringPin,
            isActive: isPinned
        ) { ctx, iconRect, tint in
            drawPinGlyph(in: ctx, rect: iconRect, color: tint)
        }

        drawHeaderButton(
            in: context,
            rect: deleteButtonRect,
            baseFill: NSColor(calibratedWhite: 0.16, alpha: 0.55),
            activeFill: NSColor.systemRed.withAlphaComponent(0.85),
            isHovered: isHoveringDelete,
            isActive: false
        ) { ctx, iconRect, _ in
            let glyphAlpha: CGFloat = isHoveringDelete ? 1.0 : 0.85
            drawDeleteGlyph(in: ctx, rect: iconRect, color: NSColor.systemRed.withAlphaComponent(glyphAlpha))
        }

        let availableWidth = pinButtonRect.minX - closeButtonRect.maxX - buttonSpacing * 2
        let handleWidth = max(56, availableWidth)
        let handleX = closeButtonRect.maxX + buttonSpacing + max(0, (availableWidth - handleWidth) / 2)
        let handleRect = CGRect(
            x: handleX,
            y: barRect.midY - 4,
            width: handleWidth,
            height: 8
        )
        drawDragHandle(in: context, rect: handleRect)

        return barRect.minY
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
    
    private func drawProjectHeader(in context: CGContext, cardRect: NSRect, contentTop: CGFloat) {
        let titleHeight: CGFloat = 28
        let safeTop = min(cardRect.maxY - TaskRowMetrics.controlBarHeight - 12, contentTop)
        let titleRect = CGRect(x: cardRect.minX + 32, y: safeTop - titleHeight, width: cardRect.width - 64, height: titleHeight)

        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.alignment = .center
        let titleColor = NSColor(calibratedWhite: 0.1, alpha: 0.95)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: titleColor,
            .paragraphStyle: titleParagraph
        ]
        projectName.draw(in: titleRect, withAttributes: titleAttributes)

        let detailTop = titleRect.minY - 6
        let detailRect = CGRect(x: cardRect.minX + 32, y: detailTop - 18, width: cardRect.width - 64, height: 18)
        let completedCount = tasks.filter { $0.isCompleted }.count
        let detailString = "\(tasks.count) task" + (tasks.count == 1 ? "" : "s") + " · \(completedCount) done"
        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: titleColor.withAlphaComponent(0.7),
            .paragraphStyle: titleParagraph
        ]
        detailString.draw(in: detailRect, withAttributes: detailAttributes)

        let openTasks = tasks.count - completedCount
        let statsString = "Open \(max(0, openTasks)) • Done \(completedCount)"
        let statsRect = CGRect(x: cardRect.minX + 32, y: detailRect.minY - 20, width: cardRect.width - 64, height: 14)
        let statsAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: titleColor.withAlphaComponent(0.55),
            .paragraphStyle: titleParagraph
        ]
        statsString.draw(in: statsRect, withAttributes: statsAttributes)

        context.saveGState()
        let separatorY = statsRect.minY - 12
        context.move(to: CGPoint(x: cardRect.minX + 32, y: separatorY))
        context.addLine(to: CGPoint(x: cardRect.maxX - 32, y: separatorY))
        context.setStrokeColor(orbColor.withAlphaComponent(0.16).cgColor)
        context.setLineWidth(1.0)
        context.strokePath()
        context.restoreGState()
    }
    
    private func drawTaskList(in context: CGContext, cardRect: NSRect) {
        let headerBottom = cardRect.maxY - TaskRowMetrics.headerHeight
        let contentWidth = cardRect.width - TaskRowMetrics.listInset * 2 - TaskRowMetrics.scrollBarWidth - TaskRowMetrics.scrollBarSpacing
        let listRect = NSRect(
            x: cardRect.minX + TaskRowMetrics.listInset,
            y: cardRect.minY + TaskRowMetrics.listInset,
            width: contentWidth,
            height: headerBottom - (cardRect.minY + TaskRowMetrics.listInset) - TaskRowMetrics.headerDividerSpacing
        )
        let scrollTrackRect = NSRect(
            x: listRect.maxX + TaskRowMetrics.scrollBarSpacing,
            y: listRect.minY,
            width: TaskRowMetrics.scrollBarWidth,
            height: listRect.height
        )

        calculateMaxScrollOffset(forListHeight: listRect.height)
        rowGeometries.removeAll()

        if tasks.isEmpty {
            drawEmptyTaskState(in: context, rect: listRect)
            return
        }

        if maxScrollOffset > 0 {
            drawScrollBar(in: context, trackRect: scrollTrackRect)
        }

        context.saveGState()
        context.clip(to: listRect)
        
        let rowStride = TaskRowMetrics.rowHeight + TaskRowMetrics.rowSpacing
        for (index, task) in tasks.enumerated() {
            if isDraggingTask && draggedTaskIndex == index { continue }
            
            let offset = CGFloat(index) * rowStride + taskScrollOffset
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
                let checkboxRect = CGRect(
                    x: rowRect.maxX - TaskRowMetrics.checkboxSize - TaskRowMetrics.checkboxTrailingInset,
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
        let thumbOffset = (scrollBarHeight - thumbHeight) * (maxScrollOffset == 0 ? 0 : taskScrollOffset / maxScrollOffset)
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
        let handleSize: CGFloat = 12
        resizeHandleRect = CGRect(
            x: cardRect.maxX - handleSize - 4,
            y: cardRect.minY + 4,
            width: handleSize,
            height: handleSize
        )
        
        // Draw grip lines
        context.saveGState()
        let opacity: CGFloat = isHoveringResizeHandle ? 0.6 : 0.3
        context.setStrokeColor(NSColor.white.withAlphaComponent(opacity).cgColor)
        context.setLineWidth(1.5)
        context.setLineCap(.round)
        
        // Draw three diagonal lines for grip pattern
        for i in 0..<3 {
            let offset = CGFloat(i) * 3.5
            context.move(to: CGPoint(
                x: resizeHandleRect.maxX - offset - 2,
                y: resizeHandleRect.minY + 2
            ))
            context.addLine(to: CGPoint(
                x: resizeHandleRect.maxX - 2,
                y: resizeHandleRect.minY + offset + 2
            ))
        }
        context.strokePath()
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
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor(calibratedWhite: 0.1, alpha: 0.9),
            .paragraphStyle: style
        ]
        let headingSize = heading.size(withAttributes: headingAttributes)
        let headingRect = CGRect(
            x: rect.midX - headingSize.width / 2,
            y: rect.midY - headingSize.height / 2 + 14,
            width: headingSize.width,
            height: headingSize.height
        )
        heading.draw(in: headingRect, withAttributes: headingAttributes)

        let detail = "Add a task or drop items here to begin."
        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12.5, weight: .regular),
            .foregroundColor: NSColor(calibratedWhite: 0.25, alpha: 0.85),
            .paragraphStyle: style
        ]
        let detailSize = detail.size(withAttributes: detailAttributes)
        let detailRect = CGRect(
            x: rect.midX - detailSize.width / 2,
            y: headingRect.minY - detailSize.height - 6,
            width: detailSize.width,
            height: detailSize.height
        )
        detail.draw(in: detailRect, withAttributes: detailAttributes)
    }

    private func drawTaskRow(in context: CGContext, rect: CGRect, task: Task, index: Int, checkboxRect: CGRect) {
        var rowRect = rect
        var currentCheckboxRect = checkboxRect
        var animatedOpacity: CGFloat = 1.0
        var animatedScale: CGFloat = 1.0
        var dropGlowStrength: CGFloat = 0.0

        if let animation = dropAnimations[task.id] {
            rowRect.origin.y += animation.offsetValue
            currentCheckboxRect.origin.y += animation.offsetValue
            animatedScale *= animation.scaleValue
            dropGlowStrength = min(1.0, abs(animation.offsetValue) / 36.0)
        }

        if let progress = completionAnimations[task.id] {
            let values = completionAnimationValues(for: progress)
            animatedOpacity = values.opacity
            animatedScale = values.scale
        } else if task.isCompleted {
            animatedOpacity = 0.5
        }

        context.saveGState()
        if animatedScale != 1.0 {
            let centerX = rowRect.midX
            let centerY = rowRect.midY
            context.translateBy(x: centerX, y: centerY)
            context.scaleBy(x: animatedScale, y: animatedScale)
            context.translateBy(x: -centerX, y: -centerY)
        }

        let rowPath = NSBezierPath(roundedRect: rowRect, xRadius: 16, yRadius: 16)
        context.saveGState()

        let baseGlass = glassBaseFill(for: orbColor)
        let glassAlpha = (task.isCompleted ? 0.28 : 0.55) * animatedOpacity
        let glassColor = baseGlass.withAlphaComponent(glassAlpha)
        context.setFillColor(glassColor.cgColor)
        rowPath.fill()

        context.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: NSColor.black.withAlphaComponent(0.08).cgColor)
        rowPath.fill()

        context.restoreGState()

        if dropGlowStrength > 0.01 {
            context.saveGState()
            context.setShadow(offset: .zero, blur: 20.0 * dropGlowStrength, color: orbColor.withAlphaComponent(0.25 * dropGlowStrength).cgColor)
            context.setFillColor(orbColor.withAlphaComponent(0.12 * dropGlowStrength).cgColor)
            rowPath.fill()
            context.restoreGState()
        }

        if highlightAlpha > 0.0, task.id == highlightedTaskID {
            context.saveGState()
            let highlightColor = orbColor.highlighted().withAlphaComponent(Double(highlightAlpha) * 0.35 + 0.15)
            highlightColor.setFill()
            rowPath.fill()
            context.restoreGState()
        }

        context.saveGState()
        context.setStrokeColor(orbColor.withAlphaComponent(0.12 * animatedOpacity).cgColor)
        context.setLineWidth(1.0)
        rowPath.stroke()
        context.restoreGState()

        let indicatorSize: CGFloat = 6
        let indicatorRect = CGRect(
            x: rowRect.minX + TaskRowMetrics.accentInset,
            y: rowRect.midY - indicatorSize / 2,
            width: indicatorSize,
            height: indicatorSize
        )
        context.saveGState()
        context.setFillColor(orbColor.withAlphaComponent(task.isCompleted ? 0.35 : 0.6).cgColor)
        context.fillEllipse(in: indicatorRect)
        context.restoreGState()

        drawRoundedCheckbox(in: context, rect: currentCheckboxRect, isCompleted: task.isCompleted)

        let contentX = indicatorRect.maxX + TaskRowMetrics.contentSpacing
        let contentWidth = max(0, currentCheckboxRect.minX - contentX - TaskRowMetrics.contentSpacing)
        let contentTop = rowRect.maxY - TaskRowMetrics.rowVerticalPadding

        let titleRect = CGRect(x: contentX, y: contentTop - 24, width: contentWidth, height: 24)
        let titleFont = NSFont.systemFont(ofSize: 15, weight: task.isCompleted ? .regular : .semibold)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let titleColor = task.isCompleted ? NSColor(calibratedWhite: 0.35, alpha: 0.85 * animatedOpacity) : NSColor(calibratedWhite: 0.1, alpha: 0.98 * animatedOpacity)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: titleColor,
            .paragraphStyle: paragraph
        ]
        task.title.draw(in: titleRect, withAttributes: titleAttributes)

        if task.isCompleted, let progress = completionAnimations[task.id] {
            let strikethroughY = titleRect.midY
            let strikethroughWidth = titleRect.width * min(progress, 1.0)
            context.saveGState()
            context.setStrokeColor(NSColor(calibratedWhite: 0.2, alpha: 0.4 * animatedOpacity).cgColor)
            context.setLineWidth(1.5)
            context.move(to: CGPoint(x: titleRect.minX, y: strikethroughY))
            context.addLine(to: CGPoint(x: titleRect.minX + strikethroughWidth, y: strikethroughY))
            context.strokePath()
            context.restoreGState()
        } else if task.isCompleted {
            let strikethroughY = titleRect.midY
            context.saveGState()
            context.setStrokeColor(NSColor(calibratedWhite: 0.2, alpha: 0.4 * animatedOpacity).cgColor)
            context.setLineWidth(1.5)
            context.move(to: CGPoint(x: titleRect.minX, y: strikethroughY))
            context.addLine(to: CGPoint(x: titleRect.maxX, y: strikethroughY))
            context.strokePath()
            context.restoreGState()
        }

        let snippet = task.details
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""

        var snippetBottom = rowRect.minY + TaskRowMetrics.rowVerticalPadding
        if !snippet.isEmpty {
            let snippetRect = CGRect(
                x: contentX,
                y: max(rowRect.minY + TaskRowMetrics.rowVerticalPadding, titleRect.minY - 18),
                width: contentWidth,
                height: 16
            )
            let snippetAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor(calibratedWhite: 0.24, alpha: 0.9),
                .paragraphStyle: paragraph
            ]
            snippet.draw(in: snippetRect, withAttributes: snippetAttributes)
            snippetBottom = snippetRect.maxY
        }

        var chipsBaselineY = max(rowRect.minY + TaskRowMetrics.rowVerticalPadding, snippetBottom + 4)
        let maxBaseline = titleRect.minY - TaskRowMetrics.chipHeight - 2
        chipsBaselineY = min(chipsBaselineY, maxBaseline)
        let chips = makeTaskRowChips(for: task, orbColor: orbColor)
        _ = drawTaskChips(chips, startingAt: contentX, baselineY: chipsBaselineY, context: context)

        context.restoreGState()
    }
    
    private func drawRoundedCheckbox(in context: CGContext, rect: CGRect, isCompleted: Bool) {
        let checkboxPath = NSBezierPath(roundedRect: rect, xRadius: rect.width / 2, yRadius: rect.height / 2)

        context.saveGState()
        // Use orb color when completed
        let fillColor = isCompleted ? orbColor.withAlphaComponent(0.75) : NSColor.white.withAlphaComponent(0.15)
        context.setFillColor(fillColor.cgColor)
        checkboxPath.fill()
        context.restoreGState()

        context.saveGState()
        let borderColor = isCompleted ? orbColor.withAlphaComponent(0.85) : NSColor.white.withAlphaComponent(0.35)
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(1.3)
        checkboxPath.stroke()
        context.restoreGState()

        if isCompleted {
            context.saveGState()
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(2.2)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            let checkmarkPath = NSBezierPath()
            let checkmarkSize = rect.width * 0.56
            let startX = rect.midX - checkmarkSize * 0.35
            let startY = rect.midY - checkmarkSize * 0.1
            let midX = rect.midX - checkmarkSize * 0.05
            let midY = rect.midY + checkmarkSize * 0.34
            let endX = rect.midX + checkmarkSize * 0.4
            let endY = rect.midY - checkmarkSize * 0.3
            checkmarkPath.move(to: CGPoint(x: startX, y: startY))
            checkmarkPath.line(to: CGPoint(x: midX, y: midY))
            checkmarkPath.line(to: CGPoint(x: endX, y: endY))
            checkmarkPath.stroke()
            context.restoreGState()
        }
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
    static let rowHeight: CGFloat = 72
    static let rowSpacing: CGFloat = 16
    static let listInset: CGFloat = 32
    static let rowVerticalPadding: CGFloat = 20
    static let rowHorizontalPadding: CGFloat = 20
    static let accentInset: CGFloat = 20
    static let accentWidth: CGFloat = 4
    static let accentCornerRadius: CGFloat = 2
    static let contentSpacing: CGFloat = 20
    static let checkboxSize: CGFloat = 24
    static let checkboxTrailingInset: CGFloat = 18
    static let dragHitWidth: CGFloat = 44
    static let chipHeight: CGFloat = 18
    static let chipHorizontalPadding: CGFloat = 8
    static let chipSpacing: CGFloat = 6
    static let chipVerticalSpacing: CGFloat = 4
    static let metadataTopInset: CGFloat = 26
    static let controlBarHeight: CGFloat = 34
    static let headerHeight: CGFloat = 96
    static let headerDividerSpacing: CGFloat = 10
    static let cardInset: CGFloat = 24
    static let dragGripHeight: CGFloat = controlBarHeight
    static let scrollBarWidth: CGFloat = 8
    static let scrollBarSpacing: CGFloat = 12
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
    let font = NSFont.systemFont(ofSize: 11, weight: .medium)
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
        let path = NSBezierPath(roundedRect: rowRect, xRadius: 16, yRadius: 16)

        context.saveGState()
        context.setFillColor(NSColor.white.withAlphaComponent(0.32).cgColor)
        path.fill()
        context.restoreGState()

        let indicatorRect = CGRect(x: rowRect.minX + TaskRowMetrics.accentInset, y: rowRect.midY - 3, width: 6, height: 6)
        context.saveGState()
        context.setFillColor(orbColor.withAlphaComponent(0.6).cgColor)
        context.fillEllipse(in: indicatorRect)
        context.restoreGState()

        let checkboxRect = CGRect(
            x: rowRect.maxX - TaskRowMetrics.checkboxSize - TaskRowMetrics.checkboxTrailingInset,
            y: rowRect.midY - TaskRowMetrics.checkboxSize / 2,
            width: TaskRowMetrics.checkboxSize,
            height: TaskRowMetrics.checkboxSize
        )
        drawRoundedCheckbox(in: context, rect: checkboxRect, isCompleted: task.isCompleted)

        let contentX = indicatorRect.maxX + TaskRowMetrics.contentSpacing
        let contentWidth = max(0, checkboxRect.minX - contentX - TaskRowMetrics.contentSpacing)
        let titleRect = CGRect(x: contentX, y: rowRect.midY - 10, width: contentWidth, height: 20)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 0.98),
            .paragraphStyle: paragraph
        ]
        task.title.draw(in: titleRect, withAttributes: titleAttributes)
    }
    private func drawRoundedCheckbox(in context: CGContext, rect: CGRect, isCompleted: Bool) {
        let checkboxPath = NSBezierPath(roundedRect: rect, xRadius: rect.width / 2, yRadius: rect.height / 2)

        context.saveGState()
        // Use orb color when completed, otherwise subtle neutral
        let fillColor = isCompleted ? orbColor.withAlphaComponent(0.75) : NSColor(calibratedWhite: 1.0, alpha: 0.18)
        context.setFillColor(fillColor.cgColor)
        checkboxPath.fill()
        context.restoreGState()

        context.saveGState()
        let borderColor = isCompleted ? orbColor.withAlphaComponent(0.85) : NSColor(calibratedWhite: 0.35, alpha: 0.5)
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(1.2)
        checkboxPath.stroke()
        context.restoreGState()

        if isCompleted {
            context.saveGState()
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(2.2)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            let checkmarkPath = NSBezierPath()
            let size = rect.width * 0.56
            let startX = rect.midX - size * 0.35
            let startY = rect.midY - size * 0.1
            let midX = rect.midX - size * 0.05
            let midY = rect.midY + size * 0.34
            let endX = rect.midX + size * 0.4
            let endY = rect.midY - size * 0.3
            checkmarkPath.move(to: CGPoint(x: startX, y: startY))
            checkmarkPath.line(to: CGPoint(x: midX, y: midY))
            checkmarkPath.line(to: CGPoint(x: endX, y: endY))
            checkmarkPath.stroke()
            context.restoreGState()
        }
    }
}
