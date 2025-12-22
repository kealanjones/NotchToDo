import Cocoa
import QuartzCore

class SemiCircleWithOrbsView: NSView, FrameUpdatable {
        private let orbManager: OrbManager
        internal weak var controller: NotchOverlayController?
        internal var hoveredOrbId: UUID? = nil  // Exposed for interaction detection
        private var mouseTrackingArea: NSTrackingArea?
        private var animationsActive = false
        private var isTickerRegistered = false

        // Text size scale factor
        private var textScale: CGFloat {
            return TextSizePreference.scaleFactor
        }

        // Base orb size - smaller when there are 3 or fewer orbs
        private var baseOrbSize: CGFloat {
            let orbCount = orbManager.orbs.count
            return orbCount <= 3 ? 34.0 : 40.0
        }

        // Drag and drop functionality
        internal var isDragging: Bool = false  // Exposed for interaction detection
        private var draggedOrb: ProjectOrb? = nil
        private var dragStartLocation: NSPoint = NSPoint.zero
        private var dragCurrentLocation: NSPoint = NSPoint.zero
        private let maxDragDistance: CGFloat = 35.0
        private var dragShakeOffset: CGPoint = .zero
        private var currentDragStrain: CGFloat = 0.0 // 0 to 1, used for continuous shake

        // Return animation
        private var isReturning: Bool = false
        private var returnStartLocation: NSPoint = NSPoint.zero
        private var returnProgress: CGFloat = 0.0
        private var returnAnimationTimer: Timer?

        // Smooth hover animation properties
        private var currentHoverScale: Double = 1.0
        private var targetHoverScale: Double = 1.0
        
        // Hover tooltip properties
        private var hoveredOrbForTooltip: ProjectOrb? = nil
        private var tooltipAnimationPhase: Double = 0.0
        private var previousBubblePoint: CGPoint?
        private var bubbleVelocity: CGPoint = .zero
        private var bubblePresence: CGFloat = 0.0
        
        init(orbManager: OrbManager, controller: NotchOverlayController) {
            self.orbManager = orbManager
            self.controller = controller
            super.init(frame: NSRect.zero)

            // Enable mouse events
            self.wantsLayer = true

            // Observe text size changes
            NotificationCenter.default.addObserver(
                forName: .textSizeDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.needsDisplay = true
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            NotificationCenter.default.removeObserver(self, name: .textSizeDidChange, object: nil)
            returnAnimationTimer?.invalidate()
        }
        
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil {
                DispatchQueue.main.async {
                    self.setupMouseTracking()
                }
            }
        }
        
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            return true
        }
        
        override var acceptsFirstResponder: Bool {
            return true
        }
        
        func setupMouseTracking() {
            // Remove existing tracking area first
            if let existingArea = mouseTrackingArea {
                removeTrackingArea(existingArea)
            }
            
            // Create tracking area for mouse events with correct options
            mouseTrackingArea = NSTrackingArea(
                rect: bounds,
                options: [.activeInActiveApp, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(mouseTrackingArea!)
        }
        
        func setAnimationsActive(_ isActive: Bool) {
            animationsActive = isActive
            updateTickerSubscription()
            
            if !isActive {
                hoveredOrbId = nil
                hoveredOrbForTooltip = nil
                targetHoverScale = 1.0
                currentHoverScale = 1.0
                tooltipAnimationPhase = 0.0
                previousBubblePoint = nil
                bubbleVelocity = .zero
                bubblePresence = 0.0
            }
        }
        
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            
            if let trackingArea = mouseTrackingArea {
                removeTrackingArea(trackingArea)
            }
            
            mouseTrackingArea = NSTrackingArea(
                rect: bounds,
                options: [.activeInKeyWindow, .mouseEnteredAndExited, .mouseMoved],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(mouseTrackingArea!)
        }
        
        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            // Set up mouse tracking when frame is properly sized
            if newSize.width > 0 && newSize.height > 0 {
                DispatchQueue.main.async {
                    self.setupMouseTracking()
                }
            }
        }
        
        private func semiCircleGeometry() -> (center: CGPoint, radius: CGFloat) {
            let centerX = bounds.midX
            let centerY = bounds.maxY - 10
            let radius = min(bounds.width, bounds.height) / 2 + 18.5
            return (CGPoint(x: centerX, y: centerY), radius)
        }
        
        private func basePosition(for orb: ProjectOrb) -> CGPoint {
            let geometry = semiCircleGeometry()
            let x = geometry.center.x + geometry.radius * CGFloat(cos(orb.angle))
            let y = geometry.center.y + geometry.radius * CGFloat(sin(orb.angle))
            return CGPoint(x: x, y: y)
        }
        
        private func currentPosition(for orb: ProjectOrb) -> CGPoint {
            var point = basePosition(for: orb)
            point.x += orb.physicsDisplacement.x
            point.y += orb.physicsDisplacement.y + orb.hoverVerticalOffset
            return point
        }
        
        override func mouseMoved(with event: NSEvent) {
            // Reset fade timer on any mouse movement
            controller?.resetFadeTimer()
            
            let mouseLocation = convert(event.locationInWindow, from: nil)
            checkOrbHover(at: mouseLocation)
        }
        
        override func mouseEntered(with event: NSEvent) {
            // Reset fade timer when mouse enters semi-circle
            controller?.resetFadeTimer()
        }
        
        override func mouseExited(with event: NSEvent) {
            // Mouse left the view, clear hover
            if hoveredOrbId != nil {
                hoveredOrbId = nil
                hoveredOrbForTooltip = nil
                targetHoverScale = 1.0
                needsDisplay = true
            }
        }
        
        override func mouseDown(with event: NSEvent) {
            // Reset fade timer on mouse down
            controller?.resetFadeTimer()
            
            let mouseLocation = convert(event.locationInWindow, from: nil)
            DebugLog.log("🖱️ Mouse DOWN at: \(mouseLocation)", category: .app)
            
            // Check if we clicked on an orb
            if let clickedOrb = findOrbAt(location: mouseLocation) {
                DebugLog.log("🖱️ Clicked on orb: \(clickedOrb.name)", category: .app)
                startDragOperation(orb: clickedOrb, at: mouseLocation)
            }
        }
        
        override func mouseUp(with event: NSEvent) {
            // Reset fade timer on mouse up
            controller?.resetFadeTimer()
            
            let mouseLocation = convert(event.locationInWindow, from: nil)
            DebugLog.log("🖱️ Mouse UP at: \(mouseLocation)", category: .app)
            
            if isDragging {
                endDragOperation(at: mouseLocation)
            }
        }
        
        override func mouseDragged(with event: NSEvent) {
            // Reset fade timer on mouse drag
            controller?.resetFadeTimer()
            
            let mouseLocation = convert(event.locationInWindow, from: nil)
            
            if isDragging {
                updateDragOperation(to: mouseLocation)
            }
        }
        
        
        private func getClickedOrb(at location: NSPoint) -> ProjectOrb? {
            let centerX = bounds.midX
            let centerY = bounds.maxY - 10
            let radius = min(bounds.width, bounds.height) / 2 + 18.5
            
            DebugLog.log("🖱️ Checking for clicked orb at location: \(location)", category: .app)
            DebugLog.log("🖱️ Center: (\(centerX), \(centerY)), Radius: \(radius)", category: .app)
            DebugLog.log("🖱️ Total orbs: \(orbManager.orbs.count)", category: .app)
            
            for (index, orb) in orbManager.orbs.enumerated() {
                DebugLog.log("🖱️ Orb \(index): \(orb.name), visible: \(orb.isVisible), animationScale: \(orb.animationScale)", category: .app)
                
                // Only check if orb is visible - remove animationScale check for now
                guard orb.isVisible else { 
                    DebugLog.log("🖱️ Orb \(index) not visible, skipping", category: .app)
                    continue 
                }
                
                let angle = orb.angle
                let baseX = centerX + radius * cos(angle)
                let baseY = centerY + radius * sin(angle)
                
                // Add physics displacement to get the actual current position
                let orbX = baseX + orb.physicsDisplacement.x
                let orbY = baseY + orb.physicsDisplacement.y + orb.hoverVerticalOffset
                // Use a minimum scale if animationScale is 0
                let effectiveScale = max(orb.animationScale, 0.1)
                let orbRadius = 15.0 * orb.scale * effectiveScale
                
                let distance = sqrt(pow(location.x - orbX, 2) + pow(location.y - orbY, 2))
                
                DebugLog.log("🖱️ Orb \(index) at (\(orbX), \(orbY)), radius: \(orbRadius), distance: \(distance)", category: .app)
                
                if distance <= orbRadius {
                    DebugLog.log("🖱️ Found clicked orb at index \(index): \(orb.name)", category: .app)
                    return orb
                }
            }
            
            return nil
        }
        
        private func findOrbAt(location: NSPoint) -> ProjectOrb? {
            return getClickedOrb(at: location)
        }
        
        // MARK: - Drag and Drop Operations
        
        private func startDragOperation(orb: ProjectOrb, at location: NSPoint) {
            DebugLog.log("🚀 Starting drag operation for orb: \(orb.name)", category: .app)
            isDragging = true
            draggedOrb = orb
            dragStartLocation = location
            dragCurrentLocation = location
            
            // Reset auto-fade timer on drag start
            controller?.resetFadeTimer()
            
            needsDisplay = true
        }
        
        private func updateDragOperation(to location: NSPoint) {
            // Calculate distance from start
            let dx = location.x - dragStartLocation.x
            let dy = location.y - dragStartLocation.y
            let distance = sqrt(dx * dx + dy * dy)

            // Constrain to max distance
            if distance > maxDragDistance {
                let angle = atan2(dy, dx)
                dragCurrentLocation.x = dragStartLocation.x + cos(angle) * maxDragDistance
                dragCurrentLocation.y = dragStartLocation.y + sin(angle) * maxDragDistance

                // Store strain for continuous shake animation
                currentDragStrain = 1.0
            } else {
                dragCurrentLocation = location

                // Gentle shake starts at 80% of max distance
                let strainThreshold: CGFloat = 0.8
                if distance > maxDragDistance * strainThreshold {
                    let normalizedStrain = (distance - maxDragDistance * strainThreshold) / (maxDragDistance * (1.0 - strainThreshold))
                    currentDragStrain = normalizedStrain
                } else {
                    currentDragStrain = 0.0
                }
            }

            needsDisplay = true
        }
        
        private func endDragOperation(at location: NSPoint) {
            DebugLog.log("🚀 Ending drag operation at: \(location)", category: .app)

            // Check if orb was dragged far enough from original position
            let dragDistance = sqrt(pow(location.x - dragStartLocation.x, 2) + pow(location.y - dragStartLocation.y, 2))
            let threshold: CGFloat = 30.0 // Minimum drag distance to trigger drop

            if dragDistance > threshold {
                DebugLog.log("🚀 Orb dragged far enough, opening task list", category: .tasks)
                // Open task list for the dragged orb
                if let orb = draggedOrb {
                    NotificationCenter.default.post(name: NSNotification.Name("OrbClicked"), object: orb)
                }
            } else {
                DebugLog.log("🚀 Orb not dragged far enough, treating as click", category: .app)
                // Treat as regular click
                if let orb = draggedOrb {
                    NotificationCenter.default.post(name: NSNotification.Name("OrbClicked"), object: orb)
                }
            }

            // Start smooth return animation
            isDragging = false
            dragShakeOffset = .zero
            currentDragStrain = 0.0
            startReturnAnimation()
        }

        private func startReturnAnimation() {
            guard draggedOrb != nil else { return }

            isReturning = true
            returnStartLocation = dragCurrentLocation
            returnProgress = 0.0

            returnAnimationTimer?.invalidate()

            let startTime = CACurrentMediaTime()
            let duration: TimeInterval = 0.7 // Duration of return animation (slower)

            returnAnimationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                let elapsed = CACurrentMediaTime() - startTime
                let progress = min(elapsed / duration, 1.0)

                // Smooth ease-out cubic for gentle return
                let eased: CGFloat = 1.0 - pow(1.0 - progress, 3.0)

                self.returnProgress = eased

                // Interpolate position
                let dx = self.dragStartLocation.x - self.returnStartLocation.x
                let dy = self.dragStartLocation.y - self.returnStartLocation.y
                self.dragCurrentLocation.x = self.returnStartLocation.x + dx * eased
                self.dragCurrentLocation.y = self.returnStartLocation.y + dy * eased

                self.needsDisplay = true

                if progress >= 1.0 {
                    timer.invalidate()
                    self.returnAnimationTimer = nil
                    self.isReturning = false
                    self.draggedOrb = nil
                    self.dragStartLocation = NSPoint.zero
                    self.dragCurrentLocation = NSPoint.zero
                    self.needsDisplay = true
                }
            }
        }
        
        private func checkOrbHover(at location: NSPoint) {
            // Check hover state for all orbs and apply physics interactions
            var newHoveredOrbId: UUID? = nil
            var newHoveredOrb: ProjectOrb? = nil
            
            for orb in orbManager.orbs {
                guard orb.isVisible && orb.animationScale > 0 else { 
                    continue 
                }
                
                // Calculate positions
                let basePoint = basePosition(for: orb)
                let currentPoint = currentPosition(for: orb)
                let currentX = currentPoint.x
                let currentY = currentPoint.y

                let size = baseOrbSize * orb.scale * orb.animationScale
                
                // Check if mouse is within orb bounds (using current position with physics)
                let orbRect = NSRect(x: currentX - size/2.0 - 10.0, y: currentY - size/2.0 - 10.0, width: size + 20.0, height: size + 20.0)
                
                if orbRect.contains(location) {
                    newHoveredOrbId = orb.id
                    newHoveredOrb = orb
                    break
                }
                
                // Apply physics interaction based on mouse proximity (using base position)
                applyPhysicsInteraction(to: orb, at: location, baseX: basePoint.x, baseY: basePoint.y)
            }
            
            // Update hover state if it changed
            if newHoveredOrbId != hoveredOrbId {
                hoveredOrbId = newHoveredOrbId
                hoveredOrbForTooltip = newHoveredOrb
                
                // Start smooth hover animation
                targetHoverScale = (newHoveredOrbId != nil) ? 1.15 : 1.0
                if newHoveredOrb != nil {
                    tooltipAnimationPhase = 0.0
                }
            }
            
            // Reset auto-fade timer when hovering over any orb
            if newHoveredOrbId != nil {
                controller?.resetFadeTimer()
            }
        }
        
        // MARK: - Physics Interaction Methods
        
        /// Apply magnetic attraction physics to an orb based on mouse proximity
        private func applyPhysicsInteraction(to orb: ProjectOrb, at mouseLocation: NSPoint, baseX: CGFloat, baseY: CGFloat) {
            // Calculate distance from mouse to orb center
            let distance = sqrt(pow(mouseLocation.x - baseX, 2) + pow(mouseLocation.y - baseY, 2))
            
            // Define interaction range (in points)
            let interactionRange: CGFloat = 50.0 // Orbs react when mouse is within 50 points
            
            if distance < interactionRange {
                // Calculate direction vector from orb to mouse
                let directionX = mouseLocation.x - baseX
                let directionY = mouseLocation.y - baseY
                
                // Normalize the direction vector
                let normalizedX = directionX / distance
                let normalizedY = directionY / distance
                
                // Calculate force strength based on proximity (closer = stronger)
                let proximityStrength = 1.0 - (distance / interactionRange) // 0.0 at edge, 1.0 at center
                let maxTargetOffset: CGFloat = 32.0 // Increased significantly for more noticeable magnetic pull
                let targetDistance = maxTargetOffset * proximityStrength
                let target = CGPoint(
                    x: normalizedX * targetDistance,
                    y: normalizedY * targetDistance
                )
                orb.setSpringTarget(target)

                let impulseStrength: CGFloat = proximityStrength * 0.9
                let impulse = CGPoint(
                    x: normalizedX * impulseStrength * 0.45, // Increased significantly for stronger attraction
                    y: normalizedY * impulseStrength * 0.45
                )
                orb.applyImpulse(impulse)
            } else if (abs(orb.springTargetDisplacement.x) > 0.05 || abs(orb.springTargetDisplacement.y) > 0.05) && orb.bubbleInfluence < 0.05 {
                orb.setSpringTarget(.zero)
            }
        }
        
        private func applyBubbleInfluence(
            to orb: ProjectOrb,
            basePosition: CGPoint,
            bubblePosition: CGPoint,
            deltaTime: CFTimeInterval,
            bubbleSpeed: CGFloat,
            isTarget: Bool,
            skipInteraction: Bool
        ) {
            let smoothing = min(CGFloat(1.0), CGFloat(deltaTime) * 5.0)
            guard !skipInteraction else {
                orb.bubbleInfluence += (0.0 - orb.bubbleInfluence) * smoothing
                orb.bubbleInfluence = min(max(orb.bubbleInfluence, 0.0), 1.0)
                return
            }
            let influenceRadius: CGFloat = isTarget ? 260.0 : 200.0
            let dx = bubblePosition.x - basePosition.x
            let dy = bubblePosition.y - basePosition.y
            let distance = sqrt(dx * dx + dy * dy)
            let presence = bubblePresence
            if distance < influenceRadius && presence > 0.01 {
                let invDist = 1.0 / max(distance, 0.0001)
                let normalizedX = dx * invDist
                let normalizedY = dy * invDist
                let proximity = max(0.0, 1.0 - (distance / influenceRadius))
                let leanMagnitude = proximity * presence * (isTarget ? 20.0 : 7.0)
                let verticalScale: CGFloat = isTarget ? 0.95 : 0.6
                let bubbleVector = CGPoint(
                    x: normalizedX * leanMagnitude,
                    y: normalizedY * leanMagnitude * verticalScale
                )
                var combinedTarget = orb.springTargetDisplacement
                combinedTarget.x += (bubbleVector.x - combinedTarget.x) * smoothing
                combinedTarget.y += (bubbleVector.y - combinedTarget.y) * smoothing
                orb.setSpringTarget(combinedTarget)
                let baseInfluence = proximity * presence
                let targetInfluence = isTarget ? baseInfluence : baseInfluence * 0.18
                orb.bubbleInfluence += (targetInfluence - orb.bubbleInfluence) * smoothing
                let normalizedSpeed = min(max(bubbleSpeed / 500.0, 0.0), 1.0)
                if isTarget && normalizedSpeed > 0.1 && proximity > 0.45 {
                    let wobbleImpulse = CGPoint(
                        x: normalizedX * normalizedSpeed * 0.55,
                        y: normalizedY * normalizedSpeed * 0.75
                    )
                    orb.applyImpulse(wobbleImpulse)
                }
            } else {
                orb.bubbleInfluence += (0.0 - orb.bubbleInfluence) * smoothing
            }
            orb.bubbleInfluence = min(max(orb.bubbleInfluence, 0.0), 1.0)
        }
        
        private func updateTickerSubscription() {
            let shouldObserve = animationsActive
            if shouldObserve && !isTickerRegistered {
                FrameTicker.shared.addObserver(self)
                isTickerRegistered = true
            } else if !shouldObserve && isTickerRegistered {
                FrameTicker.shared.removeObserver(self)
                isTickerRegistered = false
            }
        }
        
        func frameTick(deltaTime: CFTimeInterval) {
            guard animationsActive else { return }

            // Performance: Skip physics updates if semi-circle is not visible
            guard controller?.isSemiCircleVisible == true else { return }

            let bubblePoint = controller?.speechBubbleCenter(relativeTo: self)
            let bubbleTargetId = controller?.bubbleTargetOrbId()
            if let bubblePoint = bubblePoint {
                if let previous = previousBubblePoint {
                    let dx = bubblePoint.x - previous.x
                    let dy = bubblePoint.y - previous.y
                    let invDt = deltaTime > 0 ? (1.0 / deltaTime) : 0.0
                    bubbleVelocity = CGPoint(x: dx * CGFloat(invDt), y: dy * CGFloat(invDt))
                } else {
                    bubbleVelocity = .zero
                }
                previousBubblePoint = bubblePoint
                let smoothing = min(CGFloat(1.0), CGFloat(deltaTime) * 5.0)
                bubblePresence += (1.0 - bubblePresence) * smoothing
            } else {
                previousBubblePoint = nil
                bubbleVelocity = .zero
                let smoothing = min(CGFloat(1.0), CGFloat(deltaTime) * 4.0)
                bubblePresence += (0.0 - bubblePresence) * smoothing
            }
            bubblePresence = min(max(bubblePresence, 0.0), 1.0)
            let bubbleSpeed = hypot(bubbleVelocity.x, bubbleVelocity.y)
            
            for orb in orbManager.orbs {
                let phaseIncrement = deltaTime * 1.35 * orb.animationSpeed
                orb.animationPhase += phaseIncrement
                orb.updatePhysics(deltaTime: deltaTime)
                orb.updateHover(deltaTime: deltaTime)
                let basePos = basePosition(for: orb)
                let isHovered = (hoveredOrbId == orb.id)
                let isDraggedOrb = (isDragging || isReturning) && draggedOrb?.id == orb.id
                if let bubblePoint = bubblePoint, bubblePresence > 0.01, !isDraggedOrb {
                    applyBubbleInfluence(
                        to: orb,
                        basePosition: basePos,
                        bubblePosition: bubblePoint,
                        deltaTime: deltaTime,
                        bubbleSpeed: bubbleSpeed,
                        isTarget: bubbleTargetId == orb.id,
                        skipInteraction: isHovered
                    )
                } else {
                    let smoothing = min(CGFloat(1.0), CGFloat(deltaTime) * 4.0)
                    orb.bubbleInfluence += (0.0 - orb.bubbleInfluence) * smoothing
                    orb.bubbleInfluence = min(max(orb.bubbleInfluence, 0.0), 1.0)
                    if orb.bubbleInfluence < 0.05 {
                        let relaxRate = min(CGFloat(1.0), CGFloat(deltaTime) * 3.2)
                        var combined = orb.springTargetDisplacement
                        combined.x += (0.0 - combined.x) * relaxRate
                        combined.y += (0.0 - combined.y) * relaxRate
                        orb.setSpringTarget(combined)
                    }
                }
                
                if orb.badgePulse > 0 {
                    let decay = max(0.0, orb.badgePulse - deltaTime * 0.8)
                    orb.badgePulse = decay
                    orb.badgeRipplePhase += deltaTime * 4.2
                } else {
                    orb.badgePulse = 0
                    orb.badgeRipplePhase = 0
                }
            }
            
            let difference = targetHoverScale - currentHoverScale
            if abs(difference) > 0.001 {
                let smoothingRate = min(1.0, deltaTime * 9.0)
                currentHoverScale += difference * smoothingRate
            } else {
                currentHoverScale = targetHoverScale
            }
            
            if hoveredOrbForTooltip != nil {
                tooltipAnimationPhase = min(1.0, tooltipAnimationPhase + deltaTime * 3.0)
            } else {
                tooltipAnimationPhase = max(0.0, tooltipAnimationPhase - deltaTime * 4.0)
            }

            // Update drag shake continuously when under strain
            if isDragging && currentDragStrain > 0.0 {
                // Smaller and quicker shake
                let shakeAmount: CGFloat = 0.5 + currentDragStrain * 0.8 // 0.5-1.3px shake (was 2-5px)
                let shakeSpeed = 50.0 + currentDragStrain * 30.0 // Faster shake (was 30-50)
                let shakePhase = CACurrentMediaTime() * shakeSpeed
                dragShakeOffset.x = cos(shakePhase) * shakeAmount
                dragShakeOffset.y = sin(shakePhase * 1.3) * shakeAmount // Different frequency for y
            } else {
                dragShakeOffset = .zero
            }

            needsDisplay = true
        }
        
        override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Clear background
        context.clear(dirtyRect)
        
        // Draw semi-circle background
        drawSemiCircle(in: context)
        
        // Draw orbs around the rim
        drawOrbs(in: context)
    }
    
    private func drawSemiCircle(in context: CGContext) {
        let centerX = bounds.midX
        let centerY = bounds.maxY - 10 // Move center up so arc starts from top
        let radius = min(bounds.width, bounds.height) / 2 + 18.5 // 10 pixels bigger radius
        
        let path = CGMutablePath()
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
    
        private func drawOrbs(in context: CGContext) {
        
        guard orbManager.isVisible else { 
            DebugLog.log("🎯 Orbs not visible, skipping draw", category: .app)
            return 
        }

        let bubbleTargetId = controller?.bubbleTargetOrbId()
        
        for (index, orb) in orbManager.orbs.enumerated() {

            // Skip drawing the dragged orb in its original position during drag or return
            if (isDragging || isReturning) && draggedOrb?.id == orb.id {
                continue
            }
            
            // Calculate current position with physics and hover offsets
            let currentPoint = currentPosition(for: orb)
            let x = Double(currentPoint.x)
            let y = Double(currentPoint.y)
            let baseSize = baseOrbSize * orb.scale
            let animatedSize = baseSize * orb.animationScale // Apply growth animation

            let displacementMagnitude = hypot(Double(orb.springTargetDisplacement.x), Double(orb.springTargetDisplacement.y))
            let normalizedDisplacement = min(1.0, displacementMagnitude / max(orb.maxDisplacement, 0.001))
            let isBubbleTarget = (bubbleTargetId == orb.id)
            let displacementGain = isBubbleTarget ? 0.3 : 0.12
            let glowIntensity = isBubbleTarget ? 0.85 : 0.25
            let bubbleGlowScale = 1.0 + Double(orb.bubbleInfluence) * glowIntensity
            let attractionScale = (1.0 + normalizedDisplacement * displacementGain) * bubbleGlowScale
            
            // Apply smooth hover effect only to the hovered orb
            let isHovered = (hoveredOrbId == orb.id)
            let hoverBase = isHovered ? currentHoverScale : 1.0
            let hoverScale = hoverBase * attractionScale
            let finalSize = animatedSize * hoverScale
            
            // Only draw if orb is visible and has some scale
            if orb.isVisible && orb.animationScale > 0 {
                drawModernOrb(
                    context: context,
                    orb: orb,
                    x: x,
                    y: y,
                    size: finalSize,
                    scale: orb.scale * orb.animationScale * hoverScale,
                    animationPhase: orb.animationPhase,
                    orbIndex: index,
                    isHovered: isHovered,
                    magneticStrength: attractionScale
                )
            }
        }
        
        // Draw dragged orb at cursor position if dragging or returning
        if (isDragging || isReturning), let orb = draggedOrb {
            let baseSize = baseOrbSize * orb.scale
            let animatedSize = baseSize * orb.animationScale
            let scaleFactor = isDragging ? 1.2 : (1.2 - (returnProgress * 0.2)) // Scale back to normal during return
            let finalSize = animatedSize * scaleFactor

            // Apply shake offset during drag
            let drawX = Double(dragCurrentLocation.x + dragShakeOffset.x)
            let drawY = Double(dragCurrentLocation.y + dragShakeOffset.y)

            drawModernOrb(
                context: context,
                orb: orb,
                x: drawX,
                y: drawY,
                size: finalSize,
                scale: orb.scale * orb.animationScale * scaleFactor,
                animationPhase: orb.animationPhase,
                orbIndex: 999,
                isHovered: false,
                magneticStrength: 1.0
            )
        }
        
        // Draw tooltip for hovered orb
        if let hoveredOrb = hoveredOrbForTooltip, tooltipAnimationPhase > 0 {
            drawTooltip(context: context, for: hoveredOrb)
        }
    }
    
    private func drawTooltip(context: CGContext, for orb: ProjectOrb) {
        let currentPoint = currentPosition(for: orb)
        let x = Double(currentPoint.x)
        let y = Double(currentPoint.y)
        let size = baseOrbSize * orb.scale * orb.animationScale
        
        // Position tooltip below the orb
        let tooltipY = y - size/2 - 25
        let tooltipWidth: CGFloat = 120
        let tooltipHeight: CGFloat = 24
        let tooltipX = x - tooltipWidth/2
        
        // Create tooltip rectangle with rounded corners
        let tooltipRect = NSRect(x: tooltipX, y: tooltipY, width: tooltipWidth, height: tooltipHeight)
        let tooltipPath = NSBezierPath(roundedRect: tooltipRect, xRadius: 8, yRadius: 8)
        
        // Apply fade animation
        let alpha = tooltipAnimationPhase * 0.9 // Slightly transparent even at full opacity
        
        // Draw subtle black background with slight transparency
        context.saveGState()
        context.setFillColor(NSColor.black.withAlphaComponent(alpha * 0.8).cgColor)
        tooltipPath.fill()
        
        // Draw subtle border
        context.setStrokeColor(NSColor.white.withAlphaComponent(alpha * 0.3).cgColor)
        context.setLineWidth(0.5)
        tooltipPath.stroke()
        context.restoreGState()
        
        // Draw project name text
        let textRect = tooltipRect.insetBy(dx: 8, dy: 4)
        let font = NSFont(name: "SF Pro Text", size: 12 * textScale) ?? NSFont.systemFont(ofSize: 12 * textScale)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white.withAlphaComponent(alpha),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]
        
        orb.name.draw(in: textRect, withAttributes: textAttributes)
    }
    
    private func drawModernOrb(context: CGContext, orb: ProjectOrb, x: Double, y: Double, size: Double, scale: Double, animationPhase: Double, orbIndex: Int, isHovered: Bool, magneticStrength: Double) {
        let color = orb.color
        let taskCount = orb.taskCount
        // Each orb now has its own independent animation phase with additional variance
        let orbPhase = animationPhase
        let orbIndexFloat = Double(orbIndex)
        
        // Create different animation frequencies for each orb
        let slowPhase = orbPhase * 0.3 + orbIndexFloat * 1.2
        let fastPhase = orbPhase * 1.8 + orbIndexFloat * 0.7
        let mediumPhase = orbPhase * 0.8 + orbIndexFloat * 2.1
        let orbRect = CGRect(x: x - size/2, y: y - size/2, width: size, height: size)
        
        // 1. Outer liquid glass glow - soft, diffused, enhanced on hover
        context.saveGState()
        let hoverContribution = isHovered ? currentHoverScale : 1.0
        let combinedGlowMultiplier = max(1.0, hoverContribution * magneticStrength)
        let glowSize = size * 1.8 * combinedGlowMultiplier
        // Enhanced glow intensity on hover
        let baseGlowIntensity = isHovered ? 0.3 + (hoverContribution - 1.0) * 0.2 : 0.25
        let glowIntensity = baseGlowIntensity * magneticStrength
        if let glowGradient = GradientCache.shared.gradient(
            colors: [
                color.withAlphaComponent(1.0),
                color.withAlphaComponent(0.3),
                NSColor.clear
            ],
            locations: [0.0, 0.6, 1.0]
        ) {
            context.setAlpha(glowIntensity)
            context.drawRadialGradient(
                glowGradient,
                startCenter: CGPoint(x: x, y: y),
                startRadius: 0,
                endCenter: CGPoint(x: x, y: y),
                endRadius: glowSize/2,
                options: []
            )
        }
        context.restoreGState()
        
        // 1.5. Additional soft white glow on hover
        if isHovered {
            context.saveGState()
            let whiteGlowSize = size * 1.6 * (1.0 + (hoverContribution - 1.0) * 0.2) * max(1.0, magneticStrength)
            let whiteGlowIntensity = (0.7 + (hoverContribution - 1.0) * 0.4) * magneticStrength
            
            if let whiteGlowGradient = GradientCache.shared.gradient(
                colors: [
                    NSColor.white.withAlphaComponent(1.0),
                    NSColor.white.withAlphaComponent(0.6),
                    NSColor.white.withAlphaComponent(0.2),
                    NSColor.clear
                ],
                locations: [0.0, 0.4, 0.8, 1.0]
            ) {
                context.setAlpha(whiteGlowIntensity)
                context.drawRadialGradient(
                    whiteGlowGradient,
                    startCenter: CGPoint(x: x, y: y),
                    startRadius: 0,
                    endCenter: CGPoint(x: x, y: y),
                    endRadius: whiteGlowSize/2,
                    options: []
                )
            }
            context.restoreGState()
        }
        
        // 2. Main liquid glass orb with glass morphism effect
        context.saveGState()
        context.addEllipse(in: orbRect)
        context.clip()
        
        // Glass background with subtle color variation
        if let glassGradient = GradientCache.shared.gradient(
            colors: [
                color.withAlphaComponent(0.25),
                color.withAlphaComponent(0.15),
                color.withAlphaComponent(0.1)
            ],
            locations: [0.0, 0.5, 1.0]
        ) {
            context.drawLinearGradient(
                glassGradient,
                start: CGPoint(x: orbRect.minX, y: orbRect.minY),
                end: CGPoint(x: orbRect.maxX, y: orbRect.maxY),
                options: []
            )
        }
        context.restoreGState()
        
        // 3. Liquid glass highlight - flowing and dynamic
        let highlightSize = size * 0.6
        let highlightRect = CGRect(x: x - highlightSize/2, y: y - highlightSize/2, width: highlightSize, height: highlightSize)
        
        context.saveGState()
        context.addEllipse(in: highlightRect)
        context.clip()
        
        // Enhanced flowing highlight position with hover responsiveness and varied animation
        let hoverFlowMultiplier = isHovered ? 1.0 + (currentHoverScale - 1.0) * 0.5 : 1.0
        let flowX = cos(slowPhase) * size * 0.1 * hoverFlowMultiplier
        let flowY = sin(mediumPhase) * size * 0.1 * hoverFlowMultiplier
        
        // Enhanced highlight intensity on hover
        let highlightIntensity = isHovered ? 0.8 + (currentHoverScale - 1.0) * 0.2 : 0.8
        if let highlightGradient = GradientCache.shared.gradient(
            colors: [
                NSColor.white.withAlphaComponent(1.0),
                NSColor.white.withAlphaComponent(0.5),
                NSColor.white.withAlphaComponent(0.125),
                NSColor.clear
            ],
            locations: [0.0, 0.3, 0.7, 1.0]
        ) {
            context.setAlpha(highlightIntensity)
            context.drawRadialGradient(
                highlightGradient,
                startCenter: CGPoint(x: highlightRect.midX - size * 0.15 + flowX, y: highlightRect.midY - size * 0.15 + flowY),
                startRadius: 0,
                endCenter: CGPoint(x: highlightRect.midX + flowX, y: highlightRect.midY + flowY),
                endRadius: highlightSize/2,
                options: []
            )
        }
        context.restoreGState()
        
        // 4. Liquid glass border - subtle and flowing
            context.saveGState()
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1.5)
        context.addEllipse(in: orbRect.insetBy(dx: 0.75, dy: 0.75))
            context.strokePath()
            context.restoreGState()
        
        // 5. Internal liquid flow - subtle moving particles with varied animation
        for i in 0..<3 {
            let particlePhase = fastPhase + Double(i) * 1.5
            let particleRadius = size * 0.2 + sin(particlePhase * 0.5) * size * 0.05
            let particleX = x + cos(particlePhase * 0.4) * particleRadius
            let particleY = y + sin(particlePhase * 0.3) * particleRadius
            let particleSize = 2.0 + sin(particlePhase * 0.8) * 1.0
            let particleAlpha = 0.4 + sin(particlePhase * 0.6) * 0.2
            
            context.saveGState()
            context.setFillColor(NSColor.white.withAlphaComponent(particleAlpha).cgColor)
            context.addEllipse(in: CGRect(x: particleX - particleSize/2, y: particleY - particleSize/2, width: particleSize, height: particleSize))
            context.fillPath()
            context.restoreGState()
        }
        
        // 6. Task count badge with responsive flourish
        if taskCount > 0 {
            let baseBadgeSize = 18.0 * scale
            let pulse = max(0.0, min(1.0, orb.badgePulse))
            let direction = orb.badgePulseDirection >= 0 ? 1.0 : -0.85
            let easedPulse = pow(pulse, 0.55)
            let badgeScale = max(0.6, 1.0 + 0.4 * easedPulse * direction)
            let badgeSize = baseBadgeSize * badgeScale
            let badgeCenter = CGPoint(x: x + size/3, y: y - size/3)
            let badgeRect = CGRect(
                x: badgeCenter.x - badgeSize/2,
                y: badgeCenter.y - badgeSize/2,
                width: badgeSize,
                height: badgeSize
            )

            if pulse > 0.02 {
                let rippleScale = 1.9 + 0.55 * sin(orb.badgeRipplePhase * 2.3)
                let rippleSize = baseBadgeSize * rippleScale
                let rippleRect = CGRect(
                    x: badgeCenter.x - rippleSize/2,
                    y: badgeCenter.y - rippleSize/2,
                    width: rippleSize,
                    height: rippleSize
                )
                context.saveGState()
                context.setShadow(offset: .zero, blur: 26, color: color.withAlphaComponent(0.28 * pulse + 0.08).cgColor)
                context.setStrokeColor(color.withAlphaComponent(0.42 * pulse + 0.2).cgColor)
                context.setLineWidth(1.8)
                context.addEllipse(in: rippleRect)
                context.strokePath()
                context.restoreGState()
            }

            // Glass morphism badge background
            context.saveGState()
            context.addEllipse(in: badgeRect)
            context.clip()
            
            if let badgeGradient = GradientCache.shared.gradient(
                colors: [
                    NSColor.black.withAlphaComponent(0.72 - 0.15 * pulse),
                    color.withAlphaComponent(0.42 * pulse + 0.25),
                    NSColor.black.withAlphaComponent(0.28)
                ],
                locations: [0.0, 0.55, 1.0]
            ) {
                context.drawLinearGradient(
                    badgeGradient,
                    start: CGPoint(x: badgeRect.minX, y: badgeRect.minY),
                    end: CGPoint(x: badgeRect.maxX, y: badgeRect.maxY),
                    options: []
                )
            }
            context.restoreGState()
            
            // Badge border with pulse-driven brightness
            context.saveGState()
            let borderAlpha = 0.3 + 0.45 * pulse
            context.setStrokeColor(NSColor.white.withAlphaComponent(borderAlpha).cgColor)
            context.setLineWidth(0.8)
            context.addEllipse(in: badgeRect.insetBy(dx: 0.2, dy: 0.2))
            context.strokePath()
            context.restoreGState()
            
            // Badge text with subtle glow
            let text = "\(taskCount)" as NSString
            // Badge counter gets slightly larger boost in Large mode (1.45x vs 1.3x for other text)
            let badgeTextScale = TextSizePreference.current == .large ? 1.45 : textScale
            let fontSize = (10 * scale * badgeTextScale) + CGFloat(easedPulse) * 0.9
            let font = NSFont(name: "SF Pro Display", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize, weight: .heavy)
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.white.withAlphaComponent(0.98),
                .strokeColor: color.withAlphaComponent(0.24 * pulse + 0.18),
                .strokeWidth: -0.7,
                .shadow: {
                    let shadow = NSShadow()
                    shadow.shadowColor = NSColor.white.withAlphaComponent(0.55 * pulse)
                    shadow.shadowBlurRadius = 6 * pulse + 1
                    return shadow
                }()
            ]
            let textSize = text.size(withAttributes: textAttributes)
            let textRect = CGRect(
                x: badgeRect.midX - textSize.width/2,
                y: badgeRect.midY - textSize.height/2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: textAttributes)
        }
    }
}
