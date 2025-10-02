import Cocoa
import SwiftUI
import QuartzCore

// MARK: - Task Data Model
    class Task: ObservableObject, Identifiable {
        let id = UUID()
        @Published var title: String
    @Published var isCompleted: Bool = false
        
    init(title: String) {
            self.title = title
        }
    }

    // MARK: - Project Orb Data Model
    class ProjectOrb: ObservableObject, Identifiable {
        let id = UUID()
        let name: String
        let color: NSColor
        @Published var taskCount: Int = 0
        @Published var isVisible: Bool = false
        @Published var animationScale: Double = 0.0 // For growth animation
        @Published var tasks: [Task] = []
        
        // Position around semi-circle rim
        @Published var angle: Double = 0.0 // In radians
        @Published var radius: Double = 0.0 // Distance from center
        @Published var scale: Double = 1.0 // Scale factor for sizing
        
        // Individual animation phase for unique movement patterns
        var animationPhase: Double = 0.0
        
        // Individual animation speed multiplier for each orb
        var animationSpeed: Double = 1.0
        
        // Physics properties for pendulum/spring behavior
        var physicsDisplacement: CGPoint = CGPoint.zero // Current displacement from base position
        var physicsVelocity: CGPoint = CGPoint.zero // Current velocity of movement
        var physicsAcceleration: CGPoint = CGPoint.zero // Current acceleration
        var isPhysicsActive: Bool = false // Whether physics are currently affecting this orb
        var physicsDamping: Double = 0.85 // How quickly the orb returns to rest (0.0-1.0) - higher for smoother movement
        var physicsStiffness: Double = 0.8 // How strongly the orb resists displacement (0.0-1.0) - gentler for smoother attraction
        var physicsMass: Double = 0.1 // Mass affects acceleration (ultra-light for instant response)
        var maxDisplacement: Double = 18.0 // Maximum distance orb can swing from base position
    
    init(name: String, color: NSColor) {
        self.name = name
        self.color = color
    }
    
    func addTask() {
        let task = Task(title: "New Task \(taskCount + 1)")
        tasks.append(task)
        taskCount = tasks.count
    }
    
    func removeTask() {
        if !tasks.isEmpty {
            tasks.removeLast()
            taskCount = tasks.count
        }
    }
    
    // MARK: - Physics Methods
    
    /// Apply an impulse force to the orb (like a gentle tap)
    func applyImpulse(_ force: CGPoint) {
        physicsVelocity.x += force.x / physicsMass
        physicsVelocity.y += force.y / physicsMass
        isPhysicsActive = true
    }
    
    /// Update physics simulation for one frame
    func updatePhysics(deltaTime: Double) {
        guard isPhysicsActive else { return }
        
        // Calculate spring force (trying to return to original position)
        let displacementMagnitude = sqrt(physicsDisplacement.x * physicsDisplacement.x + physicsDisplacement.y * physicsDisplacement.y)
        let springForceStrength = max(displacementMagnitude * physicsStiffness, 2.0) // Gentler minimum force for smoother recoil
        
        let springForce = CGPoint(
            x: -physicsDisplacement.x * springForceStrength / max(displacementMagnitude, 0.1),
            y: -physicsDisplacement.y * springForceStrength / max(displacementMagnitude, 0.1)
        )
        
        // Calculate acceleration from spring force
        physicsAcceleration = CGPoint(
            x: springForce.x / physicsMass,
            y: springForce.y / physicsMass
        )
        
        // Update velocity with acceleration and damping
        physicsVelocity.x = (physicsVelocity.x + physicsAcceleration.x * deltaTime) * physicsDamping
        physicsVelocity.y = (physicsVelocity.y + physicsAcceleration.y * deltaTime) * physicsDamping
        
        // Update displacement with velocity
        physicsDisplacement.x += physicsVelocity.x * deltaTime
        physicsDisplacement.y += physicsVelocity.y * deltaTime
        
        // Debug print every 30 frames (0.5 seconds at 60fps)
        if Int.random(in: 0...1799) < 1 { // Very infrequent debug
            print("🔮 Physics Debug - Orb \(name): displacement=(\(String(format: "%.1f", physicsDisplacement.x)), \(String(format: "%.1f", physicsDisplacement.y))), velocity=(\(String(format: "%.1f", physicsVelocity.x)), \(String(format: "%.1f", physicsVelocity.y))), springForce=(\(String(format: "%.1f", springForce.x)), \(String(format: "%.1f", springForce.y)))")
        }
        
        // Completely soft constraint zone - no hard stops, only gradual resistance
        let softZoneStart = maxDisplacement * 0.4 // Start slowing down at 40% of max distance (8 points out of 20)
        if displacementMagnitude > softZoneStart {
            let softZoneRatio = min((displacementMagnitude - softZoneStart) / (maxDisplacement - softZoneStart), 1.0) // Clamp to 1.0
            
            // Use a smoother curve (ease-out) for more natural deceleration
            let smoothRatio = 1.0 - pow(1.0 - softZoneRatio, 4) // Quartic ease-out curve for even smoother deceleration
            
            // Apply very gentle resistance that increases smoothly - no hard stops
            let resistanceStrength = smoothRatio * 0.5 // Gentle resistance that gradually increases
            let resistanceForce = CGPoint(
                x: -physicsVelocity.x * resistanceStrength,
                y: -physicsVelocity.y * resistanceStrength
            )
            
            // Apply resistance to velocity (gradual deceleration)
            physicsVelocity.x += resistanceForce.x * deltaTime
            physicsVelocity.y += resistanceForce.y * deltaTime
            
            // NO HARD CONSTRAINT - let the resistance naturally limit the orb's movement
            // The orb will naturally slow down and settle without any jarring stops
        }
        
        // Check if orb has come to rest (very small velocity and displacement)
        let velocityMagnitude = sqrt(physicsVelocity.x * physicsVelocity.x + physicsVelocity.y * physicsVelocity.y)
        
        if velocityMagnitude < 0.1 && displacementMagnitude < 0.1 {
            // Orb has come to rest
            physicsDisplacement = CGPoint.zero
            physicsVelocity = CGPoint.zero
            physicsAcceleration = CGPoint.zero
            isPhysicsActive = false
            print("🔮 Orb \(name) has come to rest")
        }
    }
}

// MARK: - Color Palette System
struct OrbColorPalette {
    static let colors: [NSColor] = [
        NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0), // Blue
        NSColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0), // Red
        NSColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0), // Green
        NSColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1.0), // Orange
        NSColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 1.0), // Purple
        NSColor(red: 0.2, green: 0.8, blue: 0.8, alpha: 1.0), // Cyan
        NSColor(red: 0.8, green: 0.2, blue: 0.8, alpha: 1.0), // Magenta
        NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0), // Gray
    ]
    
    static func getColor(for index: Int) -> NSColor {
        return colors[index % colors.count]
    }
    
    static func getColor(for name: String) -> NSColor {
        // Use a more stable hash that won't change between runs
        let data = name.data(using: .utf8) ?? Data()
        let hash = data.withUnsafeBytes { bytes in
            return bytes.bindMemory(to: UInt8.self).reduce(0) { $0 &+ UInt($1) }
        }
        let index = Int(hash) % colors.count
        return colors[index]
    }
    
    static func getUniqueColor(for orbIndex: Int) -> NSColor {
        // Cycle through colors to ensure each orb gets a unique color
        return colors[orbIndex % colors.count]
    }
}

    // MARK: - Orb Manager
    class OrbManager: ObservableObject {
        @Published var orbs: [ProjectOrb] = []
        @Published var isVisible: Bool = false
        @Published var visibleOrbCount: Int = 0 // Track how many orbs are currently visible
    
        // Semi-circle dimensions for positioning - match actual circle
        private let semiCircleRadius: Double = 102.5
        private let semiCircleCenterX: Double = 163.5
        private let semiCircleCenterY: Double = 79.0
    
    // Orb sizing
    private let baseOrbSize: Double = 40.0
    private let minOrbSize: Double = 20.0
    private let maxOrbs: Int = 6
    
    init() {
        // Add some test orbs for development
        addTestOrbs()
    }
    
        // MARK: - Orb Management
        func createOrb(name: String) -> ProjectOrb {
            let color = OrbColorPalette.getUniqueColor(for: orbs.count)
            let orb = ProjectOrb(name: name, color: color)
            
            // Give each orb a unique starting animation phase for independent movement
            orb.animationPhase = Double.random(in: 0...12.56) // Random phase between 0 and 4π for more spread
            
            // Give each orb a unique animation speed (0.3x to 2.0x normal speed)
            orb.animationSpeed = Double.random(in: 0.3...2.0)
            
            // Add orb to the collection
            orbs.append(orb)
            
            // If orbs are currently visible, animate the repositioning
            if isVisible {
                animateOrbRepositioning(newOrb: orb)
            } else {
                // If not visible, just update positions normally
                updateOrbPositions()
            }
            
            print("🎯 Created orb '\(name)' - total orbs: \(orbs.count)")
            print("🎯 Orb details: name=\(orb.name), color=\(orb.color), visible=\(orb.isVisible)")
            return orb
        }
        
        private func animateOrbRepositioning(newOrb: ProjectOrb) {
            // Store current positions for existing orbs (excluding the new one)
            var oldPositions: [UUID: (angle: Double, radius: Double)] = [:]
            for orb in orbs {
                if orb.id != newOrb.id {
                    oldPositions[orb.id] = (angle: orb.angle, radius: orb.radius)
                }
            }
            
            // Calculate new positions WITHOUT applying them to orbs yet
            let newPositions = calculateNewOrbPositions()
            
            // Store the target positions for the new orb
            let newOrbTargetAngle = newPositions[newOrb.id]?.angle ?? 0.0
            let newOrbTargetRadius = newPositions[newOrb.id]?.radius ?? semiCircleRadius
            
            // Reset new orb to invisible and zero scale
            newOrb.isVisible = false
            newOrb.animationScale = 0.0
            
            // Animate existing orbs to new positions
            let animationDuration = 0.8
            let startTime = CACurrentMediaTime()
            
            let timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in
                let elapsed = CACurrentMediaTime() - startTime
                let progress = min(elapsed / animationDuration, 1.0)
                
                // Use ease-out curve for smooth movement
                let easedProgress = 1.0 - pow(1.0 - progress, 2.0)
                
                // Animate existing orbs (excluding the new one)
                for orb in self.orbs {
                    if orb.id != newOrb.id, 
                       let oldPos = oldPositions[orb.id],
                       let newPos = newPositions[orb.id] {
                        // Interpolate between old and new positions
                        orb.angle = oldPos.angle + (newPos.angle - oldPos.angle) * easedProgress
                        orb.radius = oldPos.radius + (newPos.radius - oldPos.radius) * easedProgress
                        orb.scale = newPos.scale // Update scale immediately
                    }
                }
                
                if progress >= 1.0 {
                    timer.invalidate()
                    
                    // Start the new orb's growth animation after repositioning is complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        newOrb.isVisible = true
                        newOrb.animationScale = 0.0
                        // Set new orb to its target position
                        newOrb.angle = newOrbTargetAngle
                        newOrb.radius = newOrbTargetRadius
                        newOrb.scale = newPositions[newOrb.id]?.scale ?? 1.0
                        self.animateOrbGrowth(orb: newOrb, duration: 0.6)
                    }
                }
            }
        }
        
        private func calculateNewOrbPositions() -> [UUID: (angle: Double, radius: Double, scale: Double)] {
            guard !orbs.isEmpty else { return [:] }
            
            let orbCount = orbs.count
            // Position orbs only in the bottom 120 degrees of the circle
            let startAngle = 3.67 // Start at 210 degrees (bottom-left)
            let endAngle = 5.76 // End at 330 degrees (bottom-right)
            let angleStep = (endAngle - startAngle) / Double(max(1, orbCount - 1))
            
            // Calculate scale based on number of orbs
            let scale = calculateOrbScale(for: orbCount)
            
            var positions: [UUID: (angle: Double, radius: Double, scale: Double)] = [:]
            
            for (index, orb) in orbs.enumerated() {
                let angle = startAngle + angleStep * Double(index)
                positions[orb.id] = (angle: angle, radius: semiCircleRadius, scale: scale)
            }
            
            return positions
        }
    
    func removeOrb(_ orb: ProjectOrb) {
        orbs.removeAll { $0.id == orb.id }
        updateOrbPositions()
    }
    
    func addTaskToOrb(_ orb: ProjectOrb) {
        orb.addTask()
    }
    
    func removeTaskFromOrb(_ orb: ProjectOrb) {
        orb.removeTask()
    }
    
        // MARK: - Positioning and Scaling
        private func updateOrbPositions() {
            guard !orbs.isEmpty else { return }
            
            let orbCount = orbs.count
            // Position orbs only in the bottom 120 degrees of the circle
            // Bottom 120 degrees means from 210° to 330° (or 3.67 to 5.76 radians)
            let startAngle = 3.67 // Start at 210 degrees (bottom-left)
            let endAngle = 5.76 // End at 330 degrees (bottom-right)
            let angleStep = (endAngle - startAngle) / Double(max(1, orbCount - 1)) // Distribute across bottom 120 degrees
        
        // Calculate scale based on number of orbs
        let scale = calculateOrbScale(for: orbCount)
        
        for (index, orb) in orbs.enumerated() {
            let angle = startAngle + angleStep * Double(index)
            let x = semiCircleCenterX + semiCircleRadius * cos(angle)
            let y = semiCircleCenterY + semiCircleRadius * sin(angle)
            
            orb.angle = angle
            orb.radius = semiCircleRadius
            orb.scale = scale
            orb.isVisible = true
        }
    }
    
    private func calculateOrbScale(for count: Int) -> Double {
        guard count > 0 else { return 1.0 }
        
        // Scale down as more orbs are added
        let maxScale = 1.0
        let minScale = minOrbSize / baseOrbSize
        
        if count <= 3 {
            return maxScale
        } else if count <= maxOrbs {
            let scaleFactor = 1.0 - (Double(count - 3) / Double(maxOrbs - 3)) * (maxScale - minScale)
            return max(minScale, scaleFactor)
        } else {
            return minScale
        }
    }
    
    // MARK: - Test Data
    private func addTestOrbs() {
        let testOrbs = [
            "Marathon Prep",
            "Marketing Strategy",
            "Home Renovation"
        ]
        
        for name in testOrbs {
            let orb = createOrb(name: name)
            // Add some test tasks
            for _ in 0..<Int.random(in: 1...5) {
                orb.addTask()
            }
        }
    }
    
        // MARK: - Visibility Control
        func showOrbs() {
            print("🎯 showOrbs() called - starting staggered orb appearance")
            isVisible = true
            visibleOrbCount = 0
            
            // Check if orbs are already visible and animated (not just reset to invisible)
            let orbsAlreadyVisible = orbs.allSatisfy { $0.isVisible && $0.animationScale > 0.5 }
            print("🎯 Orbs already visible and animated: \(orbsAlreadyVisible)")
            
            if !orbsAlreadyVisible {
                // Reset all orbs to invisible and zero scale
            for orb in orbs {
                    orb.isVisible = false
                orb.animationScale = 0.0
            }
            
            // Show orbs one by one with a delay and growth animation
            for (index, orb) in orbs.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.3) {
                    orb.isVisible = true
                    self.visibleOrbCount = index + 1
                    print("🎯 Orb \(index) appeared - visible count: \(self.visibleOrbCount)")
                    
                    // Animate growth from 0 to 1
                    self.animateOrbGrowth(orb: orb, duration: 0.6)
                }
                }
            } else {
                print("🎯 Orbs already visible and animated, ensuring full scale")
                // Ensure all orbs are fully scaled and visible
                for orb in orbs {
                    orb.isVisible = true
                    orb.animationScale = 1.0
                }
                visibleOrbCount = orbs.count
            }
        }
        
        private func animateOrbGrowth(orb: ProjectOrb, duration: Double) {
            let startTime = CACurrentMediaTime()
            let timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in
                let elapsed = CACurrentMediaTime() - startTime
                let progress = min(elapsed / duration, 1.0)
                
                // Use ease-out curve for smooth growth
                let easedProgress = 1.0 - pow(1.0 - progress, 3.0)
                orb.animationScale = easedProgress
                
                if progress >= 1.0 {
                    timer.invalidate()
                    orb.animationScale = 1.0
                }
            }
        }
        
        func hideOrbs() {
            isVisible = false
            visibleOrbCount = 0
            for orb in orbs {
                orb.isVisible = false
            }
        }
}

extension NSScreen {
    var hasTopNotchDesign: Bool {
        guard #available(macOS 12, *) else { return false }
        return safeAreaInsets.top != 0
    }
}

class NotchOverlayController: ObservableObject {
    private var overlayWindow: NSWindow?
    private var overlayView: NotchOverlayView?
    private var notchIndicatorWindow: NSWindow?
    private var semiCircleWindow: NSWindow?
    private var semiCircleView: SemiCircleWithOrbsView? // Added
    private var taskCardWindow: NSWindow? // Added for task card
    private var currentOpenOrb: ProjectOrb? // Track which orb's card is currently open
    private var isVisible = false
    var isSemiCircleVisible = false // Added
    private var orbManager = OrbManager()
    
        // Auto-fade timer system
        private var fadeTimer: Timer?
        private let fadeDelay: TimeInterval = 10.0
        private var isFaded: Bool = false

    
    @Published var isVerticallyExpanding = false
    
    init() {
        setupOverlayWindow()
        setupNotchIndicator()
        setupSemiCircle()
        setupTaskCard()
        setupNotificationObservers()
    }
    
    private func setupOverlayWindow() {
        // Create borderless window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 250, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = false
        window.level = .screenSaver
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovable = false
        
            // Create SwiftUI view
            self.overlayView = NotchOverlayView(controller: self)
            let hostingView = NSHostingView(rootView: self.overlayView!)
        window.contentView = hostingView
        
        self.overlayWindow = window
    }
    
        private func setupNotchIndicator() {
            // Create notch indicator window
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 100, height: 50),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            window.isOpaque = false
            window.backgroundColor = NSColor.clear
            window.hasShadow = false
            window.level = .screenSaver
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]
            window.isMovable = false
            window.acceptsMouseMovedEvents = true
            
            // Ensure no black elements show through
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
            
            // Create notch indicator view with actual notch info
            let notchView = NotchIndicatorView()
            if let screen = NSScreen.main {
                notchView.notchInfo = getNotchInfo(for: screen)
            }
            window.contentView = notchView
            
            self.notchIndicatorWindow = window
            positionNotchIndicator(window)
            // Don't show immediately - only when wake word is detected
        }
    
    private func positionNotchIndicator(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.frame
        let notchInfo = getNotchInfo(for: screen)
        
        // Try different centering approaches
        // Approach 1: Use screen center directly
        let x1 = screenFrame.midX - notchInfo.width / 2
        let y1 = screenFrame.maxY - notchInfo.height
        
        // Approach 2: Try with a small offset
        let x2 = screenFrame.midX - notchInfo.width / 2 + 10
        let y2 = screenFrame.maxY - notchInfo.height
        
        // Approach 3: Try with negative offset
        let x3 = screenFrame.midX - notchInfo.width / 2 - 10
        let y3 = screenFrame.maxY - notchInfo.height
        
        // Use approach 1 with 20px left offset, then shift right by 0.5px to compensate for 1px width reduction from left
        let x = x1 - 20 + 0.5
        let y = y1
        
        print("🔍 Centering Options:")
        print("   Approach 1 (center): X=\(x1), Y=\(y1)")
        print("   Approach 2 (+10px): X=\(x2), Y=\(y2)")
        print("   Approach 3 (-10px): X=\(x3), Y=\(y3)")
        
        print("🔍 Window Positioning:")
        print("   Calculated X: \(x)")
        print("   Calculated Y: \(y)")
        print("   Notch center X: \(notchInfo.centerX)")
        print("   Notch width: \(notchInfo.width)")
        print("   Screen max Y: \(screenFrame.maxY)")
        
        // Set the window to match notch dimensions
        let windowRect = NSRect(x: x, y: y, width: notchInfo.width + 20, height: notchInfo.height + 20)
        window.setFrame(windowRect, display: true)
        
        print("   Final window rect: \(windowRect)")
    }
    
    func toggleOverlay() {
        if isVisible {
            hideOverlay()
        } else {
            showOverlay()
        }
    }
    
    func showOverlay() {
        guard let window = overlayWindow, !isVisible else { return }
        
        // Position window at notch location
        positionWindowAtNotch(window)
        
        // Calculate frames for two-stage animation
        let finalFrame = window.frame
        let notchHeight: CGFloat = 52 // Match actual notch height
        
        // Stage 1: Start as narrow strip at notch height
        let stage1Frame = NSRect(
            x: finalFrame.midX - 10,
            y: finalFrame.maxY - notchHeight,
            width: 20,
            height: notchHeight
        )
        
        // Stage 2: Full width at notch height
        let stage2Frame = NSRect(
            x: finalFrame.minX,
            y: finalFrame.maxY - notchHeight,
            width: finalFrame.width,
            height: notchHeight
        )
        
        // Set initial narrow strip
        window.setFrame(stage1Frame, display: false)
        window.makeKeyAndOrderFront(nil)
        isVisible = true
        
        // Stage 1: Extend width-wise
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0) // Smooth ease-out
            window.animator().setFrame(stage2Frame, display: true)
        } completionHandler: {
            // Shorter pause between animations
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                // Start vertical expansion with green gradient
                print("Starting vertical expansion with green gradient")
                print("overlayView is nil: \(self.overlayView == nil)")
                
                // Stage 2: Extend lengthwise
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0) // Smooth ease-out
                    window.animator().setFrame(finalFrame, display: true)
                } completionHandler: {
                    // Animation complete - keep gradient visible
                }
                
                // Trigger gradient with a tiny delay to start right when vertical expansion begins
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    print("Setting isVerticallyExpanding to true in controller")
                    self.isVerticallyExpanding = true
                    print("Controller isVerticallyExpanding is now: \(self.isVerticallyExpanding)")
                }
            }
        }
    }
    
    func hideOverlay() {
        guard let window = overlayWindow, isVisible else { return }

        window.orderOut(nil)
        isVisible = false
        
        // Reset gradient state for next time
        isVerticallyExpanding = false
        print("Reset isVerticallyExpanding to false for next opening")
    }
    
    func setState(_ state: ListenState) {
        overlayView?.setState(state)
    }
    
    func addTask(_ task: String) {
        overlayView?.addTask(task)
    }
    
    func activateNotchTrace() {
        // Show notch indicator and start trace
        if let window = notchIndicatorWindow {
            window.makeKeyAndOrderFront(nil)
            
            // Reset and restart the trace animation
            if let notchView = window.contentView as? NotchIndicatorView {
                notchView.resetAndStartTrace()
            }
            
            // After trace completes, show semi-circle with less gap
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.showSemiCircle()
                
                // Semi-circle stays visible for development - no timeout
            }
        }
    }
    
    func hideSemiCircle() {
        guard let window = semiCircleWindow else { return }
        
        // Mark as not visible
        isSemiCircleVisible = false
        
        // Hide orbs first
        orbManager.hideOrbs()
        
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
    
    func showTaskCard(for orb: ProjectOrb) {
        print("🎯 showTaskCard() called for orb: \(orb.name)")
        print("🎯 taskCardWindow exists: \(taskCardWindow != nil)")
        print("🎯 currentOpenOrb: \(currentOpenOrb?.name ?? "none")")
        
        guard let window = taskCardWindow else { 
            print("🚨 ERROR: taskCardWindow is nil!")
            return 
        }
        
        // Check if clicking the same orb that's already open - toggle off
        if let currentOrb = currentOpenOrb, currentOrb.id == orb.id {
            print("🎯 Toggling off task card for orb: \(orb.name)")
            hideTaskCard()
            return
        }
        
        print("🎯 Showing task card for orb: \(orb.name)")
        print("🎯 Orb has \(orb.tasks.count) tasks")
        
        // Update the task card view with orb's tasks
        if let taskCardView = window.contentView as? TaskCardView {
            print("🎯 Updating task card view with tasks")
            taskCardView.updateTasks(orb.tasks, projectName: orb.name, orbColor: orb.color)
        } else {
            print("🚨 ERROR: taskCardView is not TaskCardView!")
        }
        
        // Position the card below the semi-circle
        guard let screen = NSScreen.main,
              let semiCircleWindow = semiCircleWindow else { return }
        
        let screenFrame = screen.frame
        let semiCircleFrame = semiCircleWindow.frame
        
        // Position card below the semi-circle with some gap
        let cardWidth = window.frame.width
        let cardHeight = window.frame.height
        let gap: CGFloat = 20
        
        let x = semiCircleFrame.midX - cardWidth / 2
        let y = semiCircleFrame.minY - cardHeight - gap
        
        // Ensure the card stays on screen
        let finalX = max(10, min(x, screenFrame.width - cardWidth - 10))
        let finalY = max(10, min(y, screenFrame.height - cardHeight - 10))
        
        window.setFrameOrigin(NSPoint(x: finalX, y: finalY))
        
        // Show the window and track the current orb
        window.makeKeyAndOrderFront(nil)
        currentOpenOrb = orb
        print("🎯 Task card shown at position: \(window.frame) below semi-circle at: \(semiCircleFrame)")
    }
    
    func hideTaskCard() {
        guard let window = taskCardWindow else { return }
        window.orderOut(nil)
        currentOpenOrb = nil
        print("🎯 Task card hidden")
    }
    
    // MARK: - Auto-Fade System
    
    func resetFadeTimer() {
        // Cancel existing timer
        fadeTimer?.invalidate()
        fadeTimer = nil
        
        print("🔄 resetFadeTimer() called - isFaded: \(isFaded)")
        
        // If we were faded, show everything again
        if isFaded {
            print("🔄 Elements were faded, calling showAllElements()")
            showAllElements()
        }
        
        // Start new timer
        fadeTimer = Timer.scheduledTimer(withTimeInterval: fadeDelay, repeats: false) { [weak self] _ in
            self?.fadeAllElements()
        }
        
        print("🎯 Fade timer reset - will fade in \(fadeDelay) seconds")
    }
    
    func resetFadeTimerWithoutShowing() {
        // Cancel existing timer
        fadeTimer?.invalidate()
        fadeTimer = nil
        
        print("🔄 resetFadeTimerWithoutShowing() called - isFaded: \(isFaded)")
        
        // Reset faded state since elements are being shown normally
        isFaded = false
        print("🔄 Reset isFaded to false")
        
        // Don't show elements - just reset the timer
        // This is used when elements are already being shown normally
        
        // Start new timer
        fadeTimer = Timer.scheduledTimer(withTimeInterval: fadeDelay, repeats: false) { [weak self] _ in
            self?.fadeAllElements()
        }
        
        print("🎯 Fade timer reset (without showing) - will fade in \(fadeDelay) seconds")
    }
    
    private func fadeAllElements() {
        guard !isFaded else { return }
        
        isFaded = true
        print("🎯 Auto-fading all elements after \(fadeDelay) seconds of inactivity")
        
        // Fade out semi-circle
        if let semiCircleWindow = semiCircleWindow {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                semiCircleWindow.animator().alphaValue = 0.0
            }
        }
        
        // Fade out task card if open
        if let taskCardWindow = taskCardWindow, taskCardWindow.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                taskCardWindow.animator().alphaValue = 0.0
            }
        }
        
        // Hide elements after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.semiCircleWindow?.orderOut(nil)
            self.taskCardWindow?.orderOut(nil)
            self.currentOpenOrb = nil
            self.isSemiCircleVisible = false
        }
    }
    
    private func showAllElements() {
        guard isFaded else { 
            print("🔄 showAllElements() called but isFaded is false, returning")
            return 
        }
        
        isFaded = false
        print("🎯 Showing all elements due to user interaction - isFaded was true")
        
        // Re-establish notification observers to ensure they're still active
        reestablishNotificationObservers()
        
        // Check if view hierarchy needs rebuilding
        if semiCircleView == nil || semiCircleView?.controller == nil {
            print("🔄 View hierarchy appears corrupted, rebuilding...")
            rebuildViewHierarchy()
        }
        
        // Show semi-circle
        if let semiCircleWindow = semiCircleWindow {
            print("🔄 Showing semi-circle window")
            semiCircleWindow.alphaValue = 1.0
            
            // Ensure the window can become key before making it key
            semiCircleWindow.level = .screenSaver
            semiCircleWindow.acceptsMouseMovedEvents = true
            semiCircleWindow.ignoresMouseEvents = false
            
            // Make it visible first, then try to make it key
            semiCircleWindow.orderFront(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if semiCircleWindow.canBecomeKey {
                    semiCircleWindow.makeKey()
                } else {
                    print("🔄 Window cannot become key, but will still receive mouse events")
                }
            }
            
            isSemiCircleVisible = true
        }
        
        // Show task card if it was open
        if let taskCardWindow = taskCardWindow, currentOpenOrb != nil {
            print("🔄 Showing task card window")
            taskCardWindow.alphaValue = 1.0
            taskCardWindow.makeKeyAndOrderFront(nil)
            
            // Ensure the window can receive mouse events
            taskCardWindow.acceptsMouseMovedEvents = true
            taskCardWindow.ignoresMouseEvents = false
        }
        
        // Re-setup mouse tracking after showing elements with a longer delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Ensure the semi-circle view has a valid controller reference
            if let semiCircleView = self.semiCircleView {
                semiCircleView.controller = self
                print("🔄 Controller reference re-established for semi-circle view")
            }
            
            self.semiCircleView?.setupMouseTracking()
            print("🖱️ Mouse tracking re-setup after showing all elements")
            
            // Force a redraw to ensure everything is properly rendered
            self.semiCircleView?.needsDisplay = true
            
            // Test if the view is responsive
            self.testViewResponsiveness()
        }
    }
    
    func createNewProject(name: String) {
        print("🎯 Creating new project: \(name)")
        print("🎯 Current orb count before: \(orbManager.orbs.count)")
        
        // Check if we've reached the maximum number of orbs
        if orbManager.orbs.count >= 6 {
            print("🎯 Maximum number of orbs (6) reached. Cannot create new project.")
            showMaximumOrbsNotification()
            return
        }
        
        // Create a new orb for this project
        let newOrb = orbManager.createOrb(name: name)
        
        // Add some random tasks to make it look realistic
        let taskCount = Int.random(in: 1...4)
        for _ in 0..<taskCount {
            newOrb.addTask()
        }
        
        print("🎯 Current orb count after: \(orbManager.orbs.count)")
        print("🎯 Semi-circle visible: \(isSemiCircleVisible)")
        print("🎯 Semi-circle window visible: \(semiCircleWindow?.isVisible ?? false)")
        
        // Show the semi-circle with orbs if it's not already visible
        if semiCircleWindow?.isVisible != true {
            print("🎯 Showing semi-circle for first time")
            showSemiCircle()
        } else {
            // If semi-circle is already visible, just trigger a redraw
            // The createOrb method will handle the repositioning animation
            print("🎯 Semi-circle already visible, orbs will reposition automatically")
            semiCircleView?.needsDisplay = true
            
            // Force a more explicit redraw
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.semiCircleView?.needsDisplay = true
            }
        }
        
        print("🎯 Created project '\(name)' with \(taskCount) tasks")
    }
    
    private func showMaximumOrbsNotification() {
        // Create a notification to show the user they've reached the maximum
        let notification = NSUserNotification()
        notification.title = "Maximum Project Orbs Reached"
        notification.informativeText = "You can only have 6 project orbs at a time. Remove an existing project to create a new one."
        notification.soundName = NSUserNotificationDefaultSoundName
        
        // Deliver the notification
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    private func setupSemiCircle() {
        print("🎯 setupSemiCircle() called")
        
        // Create semi-circle window - smaller size
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 327, height: 168), // 10 pixels bigger
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = false
        window.level = .screenSaver
        window.ignoresMouseEvents = false // Fixed: Allow mouse events
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovable = false
        window.acceptsMouseMovedEvents = true // Fixed: Accept mouse moved events
        
        // Ensure the window can become key
        window.hidesOnDeactivate = false
        
        print("🎯 Semi-circle window created with frame: \(window.frame)")
        print("🎯 Window level: \(window.level.rawValue)")
        print("🎯 Window ignoresMouseEvents: \(window.ignoresMouseEvents)")
        print("🎯 Window acceptsMouseMovedEvents: \(window.acceptsMouseMovedEvents)")
        
        // Ensure no black elements show through
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Create semi-circle view with orbs
        let semiCircleView = SemiCircleWithOrbsView(orbManager: orbManager, controller: self)
        window.contentView = semiCircleView
        
        print("🎯 Semi-circle view created and set as content view")
        
        self.semiCircleWindow = window
        self.semiCircleView = semiCircleView // Store reference
        positionSemiCircle(window)
        
        // Set up mouse tracking immediately after view is created
        DispatchQueue.main.async {
            semiCircleView.setupMouseTracking()
            print("🖱️ Mouse tracking setup attempted in setupSemiCircle")
        }
        
        print("🎯 Semi-circle setup complete - window stored: \(self.semiCircleWindow != nil)")
    }
    
    private func setupTaskCard() {
        print("🎯 setupTaskCard() called")
        
        // Create task card window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = true
        window.level = .screenSaver  // Higher than semi-circle's .screenSaver level
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovable = true  // Enable dragging for task cards
        
        // Create basic task card view
        let taskCardView = TaskCardView()
        taskCardView.setController(self)
        window.contentView = taskCardView
        
        self.taskCardWindow = window
        print("🎯 Task card setup complete - window stored: \(self.taskCardWindow != nil)")
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
        print("🎯 Notification observers setup complete")
    }
    
    private func reestablishNotificationObservers() {
        print("🔄 Re-establishing notification observers")
        setupNotificationObservers()
        
        // Test that the notification system is working
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("🔄 Testing notification system...")
            // This is just a test to verify the observer is working
            NotificationCenter.default.post(name: NSNotification.Name("TestNotification"), object: nil)
        }
    }
    
    private func rebuildViewHierarchy() {
        print("🔄 Rebuilding view hierarchy due to potential corruption")
        
        // Recreate the semi-circle view if it's corrupted
        if let semiCircleWindow = semiCircleWindow {
            let newSemiCircleView = SemiCircleWithOrbsView(orbManager: orbManager, controller: self)
            semiCircleWindow.contentView = newSemiCircleView
            self.semiCircleView = newSemiCircleView
            
            // Re-setup mouse tracking
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                newSemiCircleView.setupMouseTracking()
                print("🖱️ Mouse tracking re-setup after view hierarchy rebuild")
            }
        }
    }
    
    @objc private func handleTestNotification(_ notification: Notification) {
        print("🔄 Test notification received - notification system is working")
    }
    
    private func testViewResponsiveness() {
        guard let semiCircleView = semiCircleView else {
            print("🔄 ERROR: Semi-circle view is nil during responsiveness test")
            return
        }
        
        print("🔄 Testing view responsiveness...")
        print("🔄 View bounds: \(semiCircleView.bounds)")
        print("🔄 View window: \(semiCircleView.window != nil)")
        print("🔄 View acceptsFirstMouse: \(semiCircleView.acceptsFirstMouse(for: nil))")
        print("🔄 View acceptsFirstResponder: \(semiCircleView.acceptsFirstResponder)")
        print("🔄 View isHidden: \(semiCircleView.isHidden)")
        print("🔄 View alphaValue: \(semiCircleView.alphaValue)")
        
        // Test if we can post a test notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🔄 Posting test notification to verify responsiveness...")
            NotificationCenter.default.post(name: NSNotification.Name("TestNotification"), object: nil)
        }
    }
    
    @objc private func handleOrbClicked(_ notification: Notification) {
        print("🎯 handleOrbClicked called")
        print("🎯 Notification object: \(notification.object)")
        print("🎯 Notification name: \(notification.name)")
        
        guard let orb = notification.object as? ProjectOrb else {
            print("🚨 ERROR: Invalid orb object in notification")
            return
        }
        
        print("🎯 Received orb click notification for: \(orb.name)")
        print("🎯 Current open orb: \(currentOpenOrb?.name ?? "none")")
        
        // Reset auto-fade timer on orb interaction
        print("🎯 Calling resetFadeTimer()")
        resetFadeTimer()
        
        print("🎯 Calling showTaskCard()")
        showTaskCard(for: orb)
        print("🎯 showTaskCard() completed")
    }
    
    private func positionSemiCircle(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.frame
        let notchInfo = getNotchInfo(for: screen)
        
        // Position semi-circle to overlap the notch in the menu bar area
        let x = screenFrame.midX - window.frame.width / 2
        let y = screenFrame.maxY - window.frame.height + 10 // Position to overlap notch in menu bar
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    private func showSemiCircle() {
        guard let window = semiCircleWindow else { 
            print("🚨 ERROR: semiCircleWindow is nil!")
            return 
        }
        
        print("🎯 showSemiCircle() called - window exists: \(window != nil)")
        print("🎯 Window frame: \(window.frame)")
        print("🎯 Window level: \(window.level.rawValue)")
        print("🎯 Window isVisible: \(window.isVisible)")
        
        // Ensure window is positioned correctly before animation
        positionSemiCircle(window)
        
        // Start with semi-circle hidden and scaled down from center top
        let finalFrame = window.frame
        let centerTopX = finalFrame.midX
        let centerTopY = finalFrame.maxY
        
        // Start with tiny frame at center top
        let startFrame = NSRect(x: centerTopX - 5, y: centerTopY - 5, width: 10, height: 10)
        window.setFrame(startFrame, display: false)
        window.alphaValue = 0.0
        
        // Ensure proper window level and mouse event handling
        window.level = .screenSaver
        window.acceptsMouseMovedEvents = true
        window.ignoresMouseEvents = false
        
        // Make it visible first, then try to make it key
        window.orderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if window.canBecomeKey {
                window.makeKey()
            } else {
                print("🔄 Window cannot become key in showSemiCircle, but will still receive mouse events")
            }
        }
        
        print("🎯 Window made key and ordered front")
        print("🎯 Window isVisible after makeKeyAndOrderFront: \(window.isVisible)")
        
        // Mark as visible
        isSemiCircleVisible = true
        
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
                print("🔄 About to show orbs - isFaded: \(self.isFaded)")
                self.orbManager.showOrbs()
                print("🔄 Orbs shown")
                // Force redraw of the semi-circle view
                self.semiCircleView?.needsDisplay = true
                
                // Set up mouse tracking after everything is visible
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.semiCircleView?.setupMouseTracking()
                    print("🖱️ Mouse tracking setup attempted after semi-circle show")
                    
                    // Start auto-fade timer after everything is fully loaded
                    self.resetFadeTimerWithoutShowing()
                }
            }
        }
    }
    
    
    private func positionWindowAtNotch(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.frame
        let windowSize = window.frame.size
        
        // Get notch information
        let notchInfo = getNotchInfo(for: screen)
        print("🔍 Notch Detection:")
        print("   Screen frame: \(screenFrame)")
        print("   Notch width: \(notchInfo.width)px")
        print("   Notch height: \(notchInfo.height)px")
        print("   Notch center X: \(notchInfo.centerX)px")
        print("   Safe area top: \(notchInfo.safeAreaTop)px")

        // Position at top center of screen, extending above the screen frame
        let x = screenFrame.midX - windowSize.width / 2
        let y = screenFrame.maxY - windowSize.height + 20 // Extend 20px above screen

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    private func getNotchInfo(for screen: NSScreen) -> (width: CGFloat, height: CGFloat, centerX: CGFloat, safeAreaTop: CGFloat) {
        let screenFrame = screen.frame
        let safeAreaInsets = screen.safeAreaInsets
        let safeAreaTop = safeAreaInsets.top
        
        // Check if this screen actually has a notch
        if !screen.hasTopNotchDesign {
            print("🔍 No notch detected on this screen")
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
        print("   Screen center point: \(screenCenter)")
        
        print("🔍 Screen Frame Info:")
        print("   Screen frame: \(screenFrame)")
        print("   Visible frame: \(screen.visibleFrame)")
        print("   Screen midX: \(screenFrame.midX)")
        print("   Visible midX: \(screen.visibleFrame.midX)")
        
        print("🔍 Proper Notch Detection:")
        print("   Screen frame: \(screenFrame)")
        print("   Safe area insets: \(safeAreaInsets)")
        print("   Has notch: \(screen.hasTopNotchDesign)")
        print("   Notch width: \(notchWidth)px")
        print("   Notch height: \(notchHeight)px")
        print("   Notch center X: \(centerX)px")
        
        return (
            width: notchWidth,
            height: notchHeight,
            centerX: centerX,
            safeAreaTop: safeAreaTop
        )
    }
    
}

// MARK: - Notch Indicator View
class NotchIndicatorView: NSView {
    var notchInfo: (width: CGFloat, height: CGFloat, centerX: CGFloat, safeAreaTop: CGFloat) = (272, 25, 0, 0)
    private var animationTimer: Timer?
    private var pulsePhase: CGFloat = 0.0
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        startPulsingAnimation()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        startPulsingAnimation()
    }
    
    deinit {
        animationTimer?.invalidate()
    }
    
    func resetAndStartTrace() {
        // Reset animation phase and restart
        pulsePhase = 0.0
        startPulsingAnimation()
    }
    
        private func startPulsingAnimation() {
            // Stop any existing animation first
            animationTimer?.invalidate()
            animationTimer = nil
            
            animationTimer = Timer.scheduledTimer(withTimeInterval: 0.018, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.pulsePhase += 0.38  // Slightly faster
                
                // Stop animation when it reaches the end (1.0) - NO RESTART
                if self.pulsePhase * 0.05 >= 1.0 {
                    self.animationTimer?.invalidate()
                    self.animationTimer = nil
                    // Animation complete - trace stays at the end
                }
                
                self.needsDisplay = true
            }
        }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Clear background to transparent
        context.clear(dirtyRect)
        
        // Set up the notch rectangle using actual detected dimensions
        // Center the notch in the view with some padding
        let padding: CGFloat = 20
        let notchRect = NSRect(
            x: padding, 
            y: (bounds.height - notchInfo.height) / 2, 
            width: notchInfo.width, 
            height: notchInfo.height
        )
        let cornerRadius: CGFloat = 12
        
        print("🎨 Drawing notch indicator:")
        print("   View bounds: \(bounds)")
        print("   Notch rect: \(notchRect)")
        print("   Notch info: \(notchInfo)")
        
        // Create the notch path
        let path = NSBezierPath(roundedRect: notchRect, xRadius: cornerRadius, yRadius: cornerRadius)
        
        // Draw the notch rectangle with manual dimensions FIRST (background)
        context.saveGState()
        context.setFillColor(NSColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.0).cgColor) // 100% transparent yellow
        let cgPathFill = convertNSBezierPathToCGPath(path)
        context.addPath(cgPathFill)
        context.fillPath()
        context.restoreGState()
        
        // Draw shining white trace around the notch perimeter SECOND (on top)
        drawShiningTrace(context: context, notchRect: notchRect, cornerRadius: cornerRadius)
    }
    
    private func drawShiningTrace(context: CGContext, notchRect: NSRect, cornerRadius: CGFloat) {
        // Calculate perimeter for tracing around the yellow box edge
        let perimeter = 2 * (notchRect.width + notchRect.height) - 8 * cornerRadius + 2 * .pi * cornerRadius
        let traceLength: CGFloat = 20  // Shorter line
        let animationSpeed: CGFloat = 0.05  // Middle ground speed
        let traceProgress = min(pulsePhase * animationSpeed, 1.0)  // Stop at 1.0, no loop
        
        // Calculate current position along the perimeter
        let currentPosition = traceProgress * perimeter
        
        // Create trace path that follows the edge
        let tracePath = createPerimeterTrace(notchRect: notchRect, cornerRadius: cornerRadius, 
                                           startPosition: currentPosition, traceLength: traceLength)
        
        // Draw the shining white trace with enhanced glow
        context.saveGState()
        
        // INTENSE NEON EFFECT - Multiple layers for authentic neon look
        let cgTracePath = convertNSBezierPathToCGPath(tracePath)
        
        // Outer atmospheric glow - massive and soft
        context.setShadow(offset: CGSize(width: 0, height: 0), blur: 80, color: NSColor(red: 0.0, green: 0.6, blue: 1.0, alpha: 0.3).cgColor)
        context.setStrokeColor(NSColor(red: 0.0, green: 0.6, blue: 1.0, alpha: 0.8).cgColor)
        context.setLineWidth(6.0)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addPath(cgTracePath)
        context.strokePath()
        
        // Mid-range neon glow - electric blue
        context.setShadow(offset: CGSize(width: 0, height: 0), blur: 50, color: NSColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.6).cgColor)
        context.setStrokeColor(NSColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 1.0).cgColor)
        context.setLineWidth(3.5)
        context.addPath(cgTracePath)
        context.strokePath()
        
        // Inner bright glow - intense cyan
        context.setShadow(offset: CGSize(width: 0, height: 0), blur: 25, color: NSColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.8).cgColor)
        context.setStrokeColor(NSColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 1.0).cgColor)
        context.setLineWidth(2.0)
        context.addPath(cgTracePath)
        context.strokePath()
        
        // Core electric line - brightest white-cyan
        context.setShadow(offset: CGSize(width: 0, height: 0), blur: 8, color: NSColor(red: 0.2, green: 1.0, blue: 1.0, alpha: 0.9).cgColor)
        context.setStrokeColor(NSColor(red: 0.2, green: 1.0, blue: 1.0, alpha: 1.0).cgColor)
        context.setLineWidth(1.0)
        context.addPath(cgTracePath)
        context.strokePath()
        
        // Ultra-bright core - pure electric white
        context.setShadow(offset: CGSize(width: 0, height: 0), blur: 0, color: nil)
        context.setStrokeColor(NSColor(red: 0.4, green: 1.0, blue: 1.0, alpha: 1.0).cgColor)
        context.setLineWidth(0.5)
        context.addPath(cgTracePath)
        context.strokePath()
        
        context.restoreGState()
        
        print("🎨 Drawing trace at progress: \(traceProgress), position: \(currentPosition)")
    }
    
    private func createPerimeterTrace(notchRect: NSRect, cornerRadius: CGFloat, startPosition: CGFloat, traceLength: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        
        // Define the perimeter segments (clockwise from top-left)
        let segments = [
            (start: NSPoint(x: notchRect.minX + cornerRadius, y: notchRect.maxY), 
             end: NSPoint(x: notchRect.maxX - cornerRadius, y: notchRect.maxY), 
             length: notchRect.width - 2 * cornerRadius), // Top edge
            (start: NSPoint(x: notchRect.maxX - cornerRadius, y: notchRect.maxY), 
             end: NSPoint(x: notchRect.maxX, y: notchRect.maxY - cornerRadius), 
             length: .pi * cornerRadius / 2), // Top-right corner
            (start: NSPoint(x: notchRect.maxX, y: notchRect.maxY - cornerRadius), 
             end: NSPoint(x: notchRect.maxX, y: notchRect.minY + cornerRadius), 
             length: notchRect.height - 2 * cornerRadius), // Right edge
            (start: NSPoint(x: notchRect.maxX, y: notchRect.minY + cornerRadius), 
             end: NSPoint(x: notchRect.maxX - cornerRadius, y: notchRect.minY), 
             length: .pi * cornerRadius / 2), // Bottom-right corner
            (start: NSPoint(x: notchRect.maxX - cornerRadius, y: notchRect.minY), 
             end: NSPoint(x: notchRect.minX + cornerRadius, y: notchRect.minY), 
             length: notchRect.width - 2 * cornerRadius), // Bottom edge
            (start: NSPoint(x: notchRect.minX + cornerRadius, y: notchRect.minY), 
             end: NSPoint(x: notchRect.minX, y: notchRect.minY + cornerRadius), 
             length: .pi * cornerRadius / 2), // Bottom-left corner
            (start: NSPoint(x: notchRect.minX, y: notchRect.minY + cornerRadius), 
             end: NSPoint(x: notchRect.minX, y: notchRect.maxY - cornerRadius), 
             length: notchRect.height - 2 * cornerRadius), // Left edge
            (start: NSPoint(x: notchRect.minX, y: notchRect.maxY - cornerRadius), 
             end: NSPoint(x: notchRect.minX + cornerRadius, y: notchRect.maxY), 
             length: .pi * cornerRadius / 2) // Top-left corner
        ]
        
        // Find which segment we're starting in
        var currentPos: CGFloat = 0
        var segmentIndex = 0
        var segmentProgress: CGFloat = 0
        
        for (index, segment) in segments.enumerated() {
            if currentPos + segment.length >= startPosition {
                segmentIndex = index
                segmentProgress = startPosition - currentPos
                break
            }
            currentPos += segment.length
        }
        
        // Start the trace
        let startPoint = getPointOnSegment(segments[segmentIndex], progress: segmentProgress)
        path.move(to: startPoint)
        
        // Draw the trace along the perimeter
        var remainingLength = traceLength
        var currentSegmentIndex = segmentIndex
        var currentSegmentProgress = segmentProgress
        
        while remainingLength > 0 && currentSegmentIndex < segments.count {
            let segment = segments[currentSegmentIndex]
            let segmentRemaining = segment.length - currentSegmentProgress
            let traceInThisSegment = min(remainingLength, segmentRemaining)
            
            let endProgress = currentSegmentProgress + traceInThisSegment
            let endPoint = getPointOnSegment(segment, progress: endProgress)
            
            path.line(to: endPoint)
            
            remainingLength -= traceInThisSegment
            currentSegmentIndex = (currentSegmentIndex + 1) % segments.count
            currentSegmentProgress = 0
        }
        
        return path
    }
    
    private func getPointOnSegment(_ segment: (start: NSPoint, end: NSPoint, length: CGFloat), progress: CGFloat) -> NSPoint {
        let t = progress / segment.length
        return NSPoint(
            x: segment.start.x + (segment.end.x - segment.start.x) * t,
            y: segment.start.y + (segment.end.y - segment.start.y) * t
        )
    }
    
    private func createTracePath(notchRect: NSRect, cornerRadius: CGFloat, startPosition: CGFloat, traceLength: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        
        // Calculate the perimeter segments
        let topWidth = notchRect.width - 2 * cornerRadius
        let sideHeight = notchRect.height - 2 * cornerRadius
        let cornerCircumference = .pi * cornerRadius
        
        // Define the perimeter segments
        let segments = [
            (length: topWidth, isCorner: false, isHorizontal: true),
            (length: cornerCircumference, isCorner: true, isHorizontal: false),
            (length: sideHeight, isCorner: false, isHorizontal: false),
            (length: cornerCircumference, isCorner: true, isHorizontal: false),
            (length: topWidth, isCorner: false, isHorizontal: true),
            (length: cornerCircumference, isCorner: true, isHorizontal: false),
            (length: sideHeight, isCorner: false, isHorizontal: false),
            (length: cornerCircumference, isCorner: true, isHorizontal: false)
        ]
        
        var currentPos: CGFloat = 0
        var segmentIndex = 0
        var segmentProgress: CGFloat = 0
        
        // Find which segment we're in
        for (index, segment) in segments.enumerated() {
            if currentPos + segment.length >= startPosition {
                segmentIndex = index
                segmentProgress = startPosition - currentPos
                break
            }
            currentPos += segment.length
        }
        
        // Start the trace
        let startPoint = getPointOnPerimeter(notchRect: notchRect, cornerRadius: cornerRadius, 
                                           segmentIndex: segmentIndex, progress: segmentProgress)
        path.move(to: startPoint)
        
        // Draw the trace
        var remainingLength = traceLength
        var currentSegmentIndex = segmentIndex
        var currentSegmentProgress = segmentProgress
        
        while remainingLength > 0 && currentSegmentIndex < segments.count {
            let segment = segments[currentSegmentIndex]
            let segmentRemaining = segment.length - currentSegmentProgress
            let traceInThisSegment = min(remainingLength, segmentRemaining)
            
            let endProgress = currentSegmentProgress + traceInThisSegment
            let endPoint = getPointOnPerimeter(notchRect: notchRect, cornerRadius: cornerRadius,
                                             segmentIndex: currentSegmentIndex, progress: endProgress)
            
            path.line(to: endPoint)
            
            remainingLength -= traceInThisSegment
            currentSegmentIndex += 1
            currentSegmentProgress = 0
        }
        
        return path
    }
    
    private func getPointOnPerimeter(notchRect: NSRect, cornerRadius: CGFloat, segmentIndex: Int, progress: CGFloat) -> NSPoint {
        let segments = [
            (length: notchRect.width - 2 * cornerRadius, isCorner: false, isHorizontal: true),
            (length: .pi * cornerRadius, isCorner: true, isHorizontal: false),
            (length: notchRect.height - 2 * cornerRadius, isCorner: false, isHorizontal: false),
            (length: .pi * cornerRadius, isCorner: true, isHorizontal: false),
            (length: notchRect.width - 2 * cornerRadius, isCorner: false, isHorizontal: true),
            (length: .pi * cornerRadius, isCorner: true, isHorizontal: false),
            (length: notchRect.height - 2 * cornerRadius, isCorner: false, isHorizontal: false),
            (length: .pi * cornerRadius, isCorner: true, isHorizontal: false)
        ]
        
        let segment = segments[segmentIndex]
        let normalizedProgress = progress / segment.length
        
        switch segmentIndex {
        case 0: // Top edge (left to right)
            return NSPoint(x: notchRect.minX + cornerRadius + progress, y: notchRect.maxY)
        case 1: // Top-right corner
            let angle = normalizedProgress * .pi / 2
            return NSPoint(x: notchRect.maxX - cornerRadius + cornerRadius * cos(angle), 
                          y: notchRect.maxY - cornerRadius + cornerRadius * sin(angle))
        case 2: // Right edge (top to bottom)
            return NSPoint(x: notchRect.maxX, y: notchRect.maxY - cornerRadius - progress)
        case 3: // Bottom-right corner
            let angle = .pi / 2 + normalizedProgress * .pi / 2
            return NSPoint(x: notchRect.maxX - cornerRadius + cornerRadius * cos(angle),
                          y: notchRect.minY + cornerRadius + cornerRadius * sin(angle))
        case 4: // Bottom edge (right to left)
            return NSPoint(x: notchRect.maxX - cornerRadius - progress, y: notchRect.minY)
        case 5: // Bottom-left corner
            let angle = .pi + normalizedProgress * .pi / 2
            return NSPoint(x: notchRect.minX + cornerRadius + cornerRadius * cos(angle),
                          y: notchRect.minY + cornerRadius + cornerRadius * sin(angle))
        case 6: // Left edge (bottom to top)
            return NSPoint(x: notchRect.minX, y: notchRect.minY + cornerRadius + progress)
        case 7: // Top-left corner
            let angle = 3 * .pi / 2 + normalizedProgress * .pi / 2
            return NSPoint(x: notchRect.minX + cornerRadius + cornerRadius * cos(angle),
                          y: notchRect.maxY - cornerRadius + cornerRadius * sin(angle))
        default:
            return NSPoint(x: notchRect.midX, y: notchRect.midY)
        }
    }
}

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
    class SemiCircleWithOrbsView: NSView {
        private let orbManager: OrbManager
        internal weak var controller: NotchOverlayController?
        private var animationTimer: Timer?
        private var animationPhase: Double = 0.0
        private var hoveredOrbId: UUID? = nil
        private var mouseTrackingArea: NSTrackingArea?
        
        // Drag and drop functionality
        private var isDragging: Bool = false
        private var draggedOrb: ProjectOrb? = nil
        private var dragStartLocation: NSPoint = NSPoint.zero
        private var dragCurrentLocation: NSPoint = NSPoint.zero
        
    // Smooth hover animation properties
    private var currentHoverScale: Double = 1.0
    private var targetHoverScale: Double = 1.0
    private var hoverAnimationTimer: Timer?
    
    // Hover tooltip properties
    private var hoveredOrbForTooltip: ProjectOrb? = nil
    private var tooltipAnimationPhase: Double = 0.0
        
        init(orbManager: OrbManager, controller: NotchOverlayController) {
            self.orbManager = orbManager
            self.controller = controller
            super.init(frame: NSRect.zero)
            startAnimation()
            
            // Enable mouse events
            self.wantsLayer = true
        }
    
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            animationTimer?.invalidate()
        }
        
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil {
                print("🖱️ View moved to window, setting up mouse tracking")
                DispatchQueue.main.async {
                    self.setupMouseTracking()
                }
            }
        }
        
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            print("🖱️ acceptsFirstMouse called")
            return true
        }
        
        override var acceptsFirstResponder: Bool {
            print("🖱️ acceptsFirstResponder called")
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
            print("🖱️ Mouse tracking area set up with bounds: \(bounds)")
            print("🖱️ Tracking area options: activeInActiveApp, mouseEnteredAndExited, mouseMoved, inVisibleRect")
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
            print("🖱️ Tracking areas updated with bounds: \(bounds)")
        }
        
        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            print("🖱️ Frame size changed to: \(newSize)")
            // Set up mouse tracking when frame is properly sized
            if newSize.width > 0 && newSize.height > 0 {
                DispatchQueue.main.async {
                    self.setupMouseTracking()
                }
            }
        }
        
        override func mouseMoved(with event: NSEvent) {
            let mouseLocation = convert(event.locationInWindow, from: nil)
            print("🖱️ Mouse moved to: \(mouseLocation) in bounds: \(bounds)")
            checkOrbHover(at: mouseLocation)
        }
        
        override func mouseEntered(with event: NSEvent) {
            print("🖱️ Mouse ENTERED the semi-circle view!")
        }
        
        override func mouseExited(with event: NSEvent) {
            print("🖱️ Mouse EXITED the semi-circle view!")
            // Mouse left the view, clear hover
            if hoveredOrbId != nil {
                hoveredOrbId = nil
                needsDisplay = true
            }
        }
        
        override func mouseDown(with event: NSEvent) {
            let mouseLocation = convert(event.locationInWindow, from: nil)
            print("🖱️ Mouse DOWN at: \(mouseLocation)")
            
            // Check if we clicked on an orb
            if let clickedOrb = findOrbAt(location: mouseLocation) {
                print("🖱️ Clicked on orb: \(clickedOrb.name)")
                startDragOperation(orb: clickedOrb, at: mouseLocation)
            }
        }
        
        override func mouseUp(with event: NSEvent) {
            let mouseLocation = convert(event.locationInWindow, from: nil)
            print("🖱️ Mouse UP at: \(mouseLocation)")
            
            if isDragging {
                endDragOperation(at: mouseLocation)
            }
        }
        
        override func mouseDragged(with event: NSEvent) {
            let mouseLocation = convert(event.locationInWindow, from: nil)
            
            if isDragging {
                updateDragOperation(to: mouseLocation)
            }
        }
        
        
        private func getClickedOrb(at location: NSPoint) -> ProjectOrb? {
            let centerX = bounds.midX
            let centerY = bounds.maxY - 10
            let radius = min(bounds.width, bounds.height) / 2 + 18.5
            
            print("🖱️ Checking for clicked orb at location: \(location)")
            print("🖱️ Center: (\(centerX), \(centerY)), Radius: \(radius)")
            print("🖱️ Total orbs: \(orbManager.orbs.count)")
            
            for (index, orb) in orbManager.orbs.enumerated() {
                print("🖱️ Orb \(index): \(orb.name), visible: \(orb.isVisible), animationScale: \(orb.animationScale)")
                
                // Only check if orb is visible - remove animationScale check for now
                guard orb.isVisible else { 
                    print("🖱️ Orb \(index) not visible, skipping")
                    continue 
                }
                
                let angle = orb.angle
                let baseX = centerX + radius * cos(angle)
                let baseY = centerY + radius * sin(angle)
                
                // Add physics displacement to get the actual current position
                let orbX = baseX + orb.physicsDisplacement.x
                let orbY = baseY + orb.physicsDisplacement.y
                // Use a minimum scale if animationScale is 0
                let effectiveScale = max(orb.animationScale, 0.1)
                let orbRadius = 15.0 * orb.scale * effectiveScale
                
                let distance = sqrt(pow(location.x - orbX, 2) + pow(location.y - orbY, 2))
                
                print("🖱️ Orb \(index) at (\(orbX), \(orbY)), radius: \(orbRadius), distance: \(distance)")
                
                if distance <= orbRadius {
                    print("🖱️ Found clicked orb at index \(index): \(orb.name)")
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
            print("🚀 Starting drag operation for orb: \(orb.name)")
            isDragging = true
            draggedOrb = orb
            dragStartLocation = location
            dragCurrentLocation = location
            
            // Reset auto-fade timer on drag start
            controller?.resetFadeTimer()
            
            needsDisplay = true
        }
        
        private func updateDragOperation(to location: NSPoint) {
            dragCurrentLocation = location
            needsDisplay = true
        }
        
        private func endDragOperation(at location: NSPoint) {
            print("🚀 Ending drag operation at: \(location)")
            
            // Check if orb was dragged far enough from original position
            let dragDistance = sqrt(pow(location.x - dragStartLocation.x, 2) + pow(location.y - dragStartLocation.y, 2))
            let threshold: CGFloat = 30.0 // Minimum drag distance to trigger drop
            
            if dragDistance > threshold {
                print("🚀 Orb dragged far enough, opening task list")
                // Open task list for the dragged orb
                if let orb = draggedOrb {
                    NotificationCenter.default.post(name: NSNotification.Name("OrbClicked"), object: orb)
                }
            } else {
                print("🚀 Orb not dragged far enough, treating as click")
                // Treat as regular click
                if let orb = draggedOrb {
                    NotificationCenter.default.post(name: NSNotification.Name("OrbClicked"), object: orb)
                }
            }
            
            // Reset drag state
            isDragging = false
            draggedOrb = nil
            dragStartLocation = NSPoint.zero
            dragCurrentLocation = NSPoint.zero
            
            needsDisplay = true
        }
        
        private func checkOrbHover(at location: NSPoint) {
            let centerX = bounds.midX
            let centerY = bounds.maxY - 10
            let radius = min(bounds.width, bounds.height) / 2 + 18.5
            
            // Check hover state for all orbs and apply physics interactions
            
            var newHoveredOrbId: UUID? = nil
            var newHoveredOrb: ProjectOrb? = nil
            
            for (index, orb) in orbManager.orbs.enumerated() {
                guard orb.isVisible && orb.animationScale > 0 else { 
                    continue 
                }
                
                // Calculate base position (without physics displacement) for accurate hit testing
                let baseX = centerX + radius * cos(orb.angle)
                let baseY = centerY + radius * sin(orb.angle)
                
                // Current position with physics displacement
                let currentX = baseX + orb.physicsDisplacement.x
                let currentY = baseY + orb.physicsDisplacement.y
                
                let size = 40.0 * orb.scale * orb.animationScale
                
                // Check if mouse is within orb bounds (using current position with physics)
                let orbRect = NSRect(x: currentX - size/2.0 - 10.0, y: currentY - size/2.0 - 10.0, width: size + 20.0, height: size + 20.0)
                
                if orbRect.contains(location) {
                    newHoveredOrbId = orb.id
                    newHoveredOrb = orb
                    break
                }
                
                // Apply physics interaction based on mouse proximity (using base position)
                applyPhysicsInteraction(to: orb, at: location, baseX: baseX, baseY: baseY)
            }
            
            // Update hover state if it changed
            if newHoveredOrbId != hoveredOrbId {
                hoveredOrbId = newHoveredOrbId
                hoveredOrbForTooltip = newHoveredOrb
                
                // Start smooth hover animation
                targetHoverScale = (newHoveredOrbId != nil) ? 1.15 : 1.0
                startHoverAnimation()
                
                // Start tooltip animation
                if newHoveredOrb != nil {
                    startTooltipAnimation()
                } else {
                    // Fade out tooltip when no orb is hovered
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
                let forceStrength: CGFloat = proximityStrength * 4.0 // Gentler force for smoother, slower attraction
                
        // Apply attraction force (orb moves toward mouse)
        let forceX = normalizedX * forceStrength
        let forceY = normalizedY * forceStrength
                
                // Apply the impulse to the orb
                orb.applyImpulse(CGPoint(x: forceX, y: forceY))
                
                print("🔮 Magnetic attraction applied to orb \(orb.name): distance=\(String(format: "%.1f", distance)), force=(\(String(format: "%.1f", forceX)), \(String(format: "%.1f", forceY)))")
            }
        }
        
        private func startAnimation() {
            animationTimer?.invalidate()
            animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                let deltaTime = 1.0/60.0 // 60 FPS
                
                // Update each orb's individual animation phase with its own speed
                for orb in self.orbManager.orbs {
                    orb.animationPhase += 0.05 * orb.animationSpeed
                    
                    // Update physics simulation
                    orb.updatePhysics(deltaTime: deltaTime)
                }
                
                self.needsDisplay = true
            }
        }
        
        private func startHoverAnimation() {
            hoverAnimationTimer?.invalidate()
            hoverAnimationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                // Smooth interpolation with easing
                let difference = self.targetHoverScale - self.currentHoverScale
                if abs(difference) < 0.001 {
                    self.currentHoverScale = self.targetHoverScale
                    self.hoverAnimationTimer?.invalidate()
                    self.hoverAnimationTimer = nil
                } else {
                    // Use ease-out cubic for smooth deceleration
                    let easingFactor = 0.15
                    self.currentHoverScale += difference * easingFactor
                }
                
                self.needsDisplay = true
            }
        }
        
        private func startTooltipAnimation() {
            // Animate tooltip fade in
            tooltipAnimationPhase = 0.0
            let tooltipTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] timer in
                guard let self = self else { 
                    timer.invalidate()
                    return 
                }
                
                self.tooltipAnimationPhase += 0.05
                if self.tooltipAnimationPhase >= 1.0 {
                    self.tooltipAnimationPhase = 1.0
                    timer.invalidate()
                }
                
                self.needsDisplay = true
            }
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
        print("🎯 Drawing orbs - isVisible: \(orbManager.isVisible), orbCount: \(orbManager.orbs.count)")
        
        guard orbManager.isVisible else { 
            print("🎯 Orbs not visible, skipping draw")
            return 
        }
        
        let centerX = bounds.midX
        let centerY = bounds.maxY - 10 // Match the circle center
        let radius = min(bounds.width, bounds.height) / 2 + 18.5 // Match the circle radius
        
        print("🎯 Drawing at center: (\(centerX), \(centerY)), radius: \(radius)")
        
        for (index, orb) in orbManager.orbs.enumerated() {
            print("🎯 Orb \(index): visible=\(orb.isVisible), angle=\(orb.angle), scale=\(orb.scale), animationScale=\(orb.animationScale)")
            
            // Skip drawing the dragged orb in its original position
            if isDragging && draggedOrb?.id == orb.id {
                continue
            }
            
            // Calculate base position on the semi-circle
            let baseX = centerX + radius * cos(orb.angle)
            let baseY = centerY + radius * sin(orb.angle)
            
            // Apply physics displacement to create pendulum/spring movement
            let x = baseX + orb.physicsDisplacement.x
            let y = baseY + orb.physicsDisplacement.y
            let baseSize = 40.0 * orb.scale
            let animatedSize = baseSize * orb.animationScale // Apply growth animation
            
            // Apply smooth hover effect only to the hovered orb
            let isHovered = (hoveredOrbId == orb.id)
            let hoverScale = isHovered ? currentHoverScale : 1.0
            let finalSize = animatedSize * hoverScale
            
            // Draw orb with smooth hover effects
            
            // Only draw if orb is visible and has some scale
            if orb.isVisible && orb.animationScale > 0 {
                // Create modern, dynamic orb with multiple layers
                drawModernOrb(context: context, x: x, y: y, size: finalSize, color: orb.color, taskCount: orb.taskCount, scale: orb.scale * orb.animationScale * hoverScale, animationPhase: orb.animationPhase, orbIndex: index, isHovered: isHovered)
            }
        }
        
        // Draw dragged orb at cursor position if dragging
        if isDragging, let orb = draggedOrb {
            let baseSize = 40.0 * orb.scale
            let animatedSize = baseSize * orb.animationScale
            let finalSize = animatedSize * 1.2 // Slightly larger when dragging
            
            drawModernOrb(context: context, x: Double(dragCurrentLocation.x), y: Double(dragCurrentLocation.y), size: finalSize, color: orb.color, taskCount: orb.taskCount, scale: orb.scale * orb.animationScale * 1.2, animationPhase: orb.animationPhase, orbIndex: 999, isHovered: false)
        }
        
        // Draw tooltip for hovered orb
        if let hoveredOrb = hoveredOrbForTooltip, tooltipAnimationPhase > 0 {
            drawTooltip(context: context, for: hoveredOrb, at: centerX, centerY: centerY, radius: radius)
        }
    }
    
    private func drawTooltip(context: CGContext, for orb: ProjectOrb, at centerX: Double, centerY: Double, radius: Double) {
        // Calculate orb position
        let x = centerX + radius * cos(orb.angle)
        let y = centerY + radius * sin(orb.angle)
        let size = 40.0 * orb.scale * orb.animationScale
        
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
        let font = NSFont(name: "SF Pro Text", size: 12) ?? NSFont.systemFont(ofSize: 12)
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
    
    private func drawModernOrb(context: CGContext, x: Double, y: Double, size: Double, color: NSColor, taskCount: Int, scale: Double, animationPhase: Double, orbIndex: Int, isHovered: Bool) {
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
        let hoverGlowMultiplier = isHovered ? 1.0 + (currentHoverScale - 1.0) * 0.5 : 1.0 // Subtle glow increase
        let glowSize = size * 1.8 * hoverGlowMultiplier
        let glowRect = CGRect(x: x - glowSize/2, y: y - glowSize/2, width: glowSize, height: glowSize)
        
        // Enhanced glow intensity on hover
        let glowIntensity = isHovered ? 0.3 + (currentHoverScale - 1.0) * 0.2 : 0.3
        let glowGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: [
                                        color.withAlphaComponent(glowIntensity).cgColor,
                                        color.withAlphaComponent(glowIntensity * 0.3).cgColor,
                                        NSColor.clear.cgColor
                                ] as CFArray,
                                locations: [0.0, 0.6, 1.0])!
        
        context.drawRadialGradient(glowGradient,
                                 startCenter: CGPoint(x: x, y: y),
                                 startRadius: 0,
                                 endCenter: CGPoint(x: x, y: y),
                                 endRadius: glowSize/2,
                                 options: [])
        context.restoreGState()
        
        // 1.5. Additional soft white glow on hover
        if isHovered {
        context.saveGState()
            let whiteGlowSize = size * 1.6 * (1.0 + (currentHoverScale - 1.0) * 0.2) // Smaller, more focused glow
            let whiteGlowIntensity = 0.7 + (currentHoverScale - 1.0) * 0.4 // Much more intense on hover
            
            let whiteGlowGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: [
                                                NSColor.white.withAlphaComponent(whiteGlowIntensity).cgColor,
                                                NSColor.white.withAlphaComponent(whiteGlowIntensity * 0.6).cgColor,
                                                NSColor.white.withAlphaComponent(whiteGlowIntensity * 0.2).cgColor,
                                                NSColor.clear.cgColor
                                        ] as CFArray,
                                        locations: [0.0, 0.4, 0.8, 1.0])!
            
            context.drawRadialGradient(whiteGlowGradient,
                                     startCenter: CGPoint(x: x, y: y),
                                     startRadius: 0,
                                     endCenter: CGPoint(x: x, y: y),
                                     endRadius: whiteGlowSize/2,
                                     options: [])
        context.restoreGState()
        }
        
        // 2. Main liquid glass orb with glass morphism effect
        context.saveGState()
        context.addEllipse(in: orbRect)
        context.clip()
        
        // Glass background with subtle color variation
        let glassGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: [
                                        color.withAlphaComponent(0.25).cgColor,
                                        color.withAlphaComponent(0.15).cgColor,
                                        color.withAlphaComponent(0.1).cgColor
                                     ] as CFArray,
                                     locations: [0.0, 0.5, 1.0])!
        
        context.drawLinearGradient(glassGradient,
                                 start: CGPoint(x: orbRect.minX, y: orbRect.minY),
                                 end: CGPoint(x: orbRect.maxX, y: orbRect.maxY),
                                 options: [])
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
        let highlightGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: [
                                            NSColor.white.withAlphaComponent(highlightIntensity).cgColor,
                                            NSColor.white.withAlphaComponent(highlightIntensity * 0.5).cgColor,
                                            NSColor.white.withAlphaComponent(highlightIntensity * 0.125).cgColor,
                                            NSColor.clear.cgColor
                                         ] as CFArray,
                                         locations: [0.0, 0.3, 0.7, 1.0])!
        
        context.drawRadialGradient(highlightGradient,
                                 startCenter: CGPoint(x: highlightRect.midX - size * 0.15 + flowX, y: highlightRect.midY - size * 0.15 + flowY),
                                 startRadius: 0,
                                 endCenter: CGPoint(x: highlightRect.midX + flowX, y: highlightRect.midY + flowY),
                                 endRadius: highlightSize/2,
                                 options: [])
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
        
        // 6. Task count badge with liquid glass styling
        if taskCount > 0 {
            let badgeSize = 18.0 * scale
            let badgeRect = CGRect(x: x + size/3, y: y - size/3, width: badgeSize, height: badgeSize)
            
            // Glass morphism badge background
            context.saveGState()
            context.addEllipse(in: badgeRect)
            context.clip()
            
            let badgeGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: [
                                            NSColor.black.withAlphaComponent(0.8).cgColor,
                                            NSColor.black.withAlphaComponent(0.6).cgColor,
                                            NSColor.black.withAlphaComponent(0.4).cgColor
                                         ] as CFArray,
                                         locations: [0.0, 0.5, 1.0])!
            
            context.drawLinearGradient(badgeGradient,
                                     start: CGPoint(x: badgeRect.minX, y: badgeRect.minY),
                                     end: CGPoint(x: badgeRect.maxX, y: badgeRect.maxY),
                                     options: [])
            context.restoreGState()
            
            // Badge border
            context.saveGState()
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.3).cgColor)
            context.setLineWidth(0.5)
            context.addEllipse(in: badgeRect.insetBy(dx: 0.25, dy: 0.25))
            context.strokePath()
            context.restoreGState()
            
            // Badge text
            let text = "\(taskCount)" as NSString
            let font = NSFont(name: "SF Pro Display", size: 10 * scale) ?? NSFont.systemFont(ofSize: 10 * scale, weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.white,
                .strokeColor: NSColor.black.withAlphaComponent(0.3),
                .strokeWidth: -0.5
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(x: badgeRect.midX - textSize.width/2, 
                                y: badgeRect.midY - textSize.height/2, 
                                width: textSize.width, 
                                height: textSize.height)
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
}

// MARK: - NSBezierPath to CGPath Conversion
extension NotchIndicatorView {
    private func convertNSBezierPathToCGPath(_ nsPath: NSBezierPath) -> CGPath {
        let path = CGMutablePath()
        let elementCount = nsPath.elementCount
        
        for i in 0..<elementCount {
            var points = [NSPoint](repeating: NSPoint.zero, count: 3)
            let element = nsPath.element(at: i, associatedPoints: &points)
            
            switch element {
            case .moveTo:
                path.move(to: CGPoint(x: points[0].x, y: points[0].y))
            case .lineTo:
                path.addLine(to: CGPoint(x: points[0].x, y: points[0].y))
            case .curveTo:
                path.addCurve(
                    to: CGPoint(x: points[2].x, y: points[2].y),
                    control1: CGPoint(x: points[0].x, y: points[0].y),
                    control2: CGPoint(x: points[1].x, y: points[1].y)
                )
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }
        
        return path
    }
}

// MARK: - Task Card View
class TaskCardView: NSView {
    private var tasks: [Task] = []
    private var projectName: String = ""
    private var orbColor: NSColor = .systemBlue
    private var animationPhase: Double = 0.0
    private weak var controller: NotchOverlayController?
    
    // Drag functionality
    private var isDragging = false
    private var dragStartLocation = NSPoint.zero
    private var initialWindowOrigin = NSPoint.zero
    private var lastDragUpdateTime: TimeInterval = 0
    private let dragUpdateInterval: TimeInterval = 1.0/60.0 // 60 FPS
    
    // Hover detection
    private var hoverTimer: Timer?
    private var isMouseOver = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        startAnimation()
        setupDragTracking()
        startHoverDetection()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        startAnimation()
        setupDragTracking()
        startHoverDetection()
    }
    
    func updateTasks(_ tasks: [Task], projectName: String, orbColor: NSColor) {
        self.tasks = tasks
        self.projectName = projectName
        self.orbColor = orbColor
        self.needsDisplay = true
    }
    
    func setController(_ controller: NotchOverlayController?) {
        self.controller = controller
    }
    
    private func startHoverDetection() {
        // Start a timer that checks if mouse is over the task card
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkMouseHover()
        }
    }
    
    private func checkMouseHover() {
        guard let window = self.window else { return }
        
        // Get mouse location in screen coordinates
        let mouseLocation = NSEvent.mouseLocation
        
        // Convert to window coordinates
        let windowFrame = window.frame
        let mouseInWindow = NSPoint(
            x: mouseLocation.x - windowFrame.origin.x,
            y: mouseLocation.y - windowFrame.origin.y
        )
        
        // Check if mouse is within the task card bounds
        let isOver = bounds.contains(mouseInWindow)
        
        if isOver && !isMouseOver {
            // Mouse just entered
            isMouseOver = true
            controller?.resetFadeTimer()
        } else if !isOver && isMouseOver {
            // Mouse just exited
            isMouseOver = false
        } else if isOver {
            // Mouse is still over, keep resetting fade timer
            controller?.resetFadeTimer()
        }
    }
    
    deinit {
        hoverTimer?.invalidate()
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { _ in
            self.animationPhase += 0.02
            self.needsDisplay = true
        }
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
        // Reset fade timer on any mouse interaction
        controller?.resetFadeTimer()
        
        // Check if click is in the drag handle area (top 60 pixels of the card)
        let locationInView = convert(event.locationInWindow, from: nil)
        let dragHandleRect = NSRect(x: 0, y: bounds.height - 60, width: bounds.width, height: 60)
        
        if dragHandleRect.contains(locationInView) {
            isDragging = true
            // Use screen coordinates for smooth dragging
            dragStartLocation = NSEvent.mouseLocation
            initialWindowOrigin = window?.frame.origin ?? NSPoint.zero
            
            // Change cursor to indicate dragging
            NSCursor.closedHand.set()
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let window = window else { return }
        
        // Reset fade timer during dragging
        controller?.resetFadeTimer()
        
        // Throttle updates to 60 FPS for smoother dragging
        let currentTime = CACurrentMediaTime()
        if currentTime - lastDragUpdateTime < dragUpdateInterval {
            return
        }
        lastDragUpdateTime = currentTime
        
        // Use screen coordinates for smooth dragging
        let currentMouseLocation = NSEvent.mouseLocation
        let deltaX = currentMouseLocation.x - dragStartLocation.x
        let deltaY = currentMouseLocation.y - dragStartLocation.y
        
        let newOrigin = NSPoint(
            x: initialWindowOrigin.x + deltaX,
            y: initialWindowOrigin.y + deltaY
        )
        
        // Keep the window on screen
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let windowFrame = window.frame
        
        let constrainedX = max(0, min(newOrigin.x, screenFrame.width - windowFrame.width))
        let constrainedY = max(0, min(newOrigin.y, screenFrame.height - windowFrame.height))
        
        let constrainedOrigin = NSPoint(x: constrainedX, y: constrainedY)
        
        // Use NSAnimationContext to smooth the movement
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.0
            context.allowsImplicitAnimation = false
            window.animator().setFrameOrigin(constrainedOrigin)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        // Reset fade timer on mouse up
        controller?.resetFadeTimer()
        
        if isDragging {
            isDragging = false
            NSCursor.arrow.set()
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        // Reset fade timer on hover
        controller?.resetFadeTimer()
        
        // Change cursor when hovering over drag area
        let locationInView = convert(event.locationInWindow, from: nil)
        let dragHandleRect = NSRect(x: 0, y: bounds.height - 60, width: bounds.width, height: 60)
        
        if dragHandleRect.contains(locationInView) {
            NSCursor.openHand.set()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if !isDragging {
            NSCursor.arrow.set()
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        // Reset fade timer on mouse movement
        controller?.resetFadeTimer()
        
        // Update cursor based on mouse position
        let locationInView = convert(event.locationInWindow, from: nil)
        let dragHandleRect = NSRect(x: 0, y: bounds.height - 60, width: bounds.width, height: 60)
        
        if dragHandleRect.contains(locationInView) {
            if !isDragging {
                NSCursor.openHand.set()
            }
        } else {
            if !isDragging {
                NSCursor.arrow.set()
            }
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let cardRect = bounds.insetBy(dx: 8, dy: 8)
        
        // 1. Outer liquid glass glow
        context.saveGState()
        let glowSize = 20.0
        let glowRect = cardRect.insetBy(dx: -glowSize, dy: -glowSize)
        let glowGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [
                                        NSColor.black.withAlphaComponent(0.25).cgColor,
                                        NSColor.black.withAlphaComponent(0.15).cgColor,
                                        NSColor.clear.cgColor
                                    ] as CFArray,
                                    locations: [0.0, 0.6, 1.0])!
        
        context.drawRadialGradient(glowGradient,
                                 startCenter: CGPoint(x: cardRect.midX, y: cardRect.midY),
                                 startRadius: 0,
                                 endCenter: CGPoint(x: cardRect.midX, y: cardRect.midY),
                                 endRadius: glowRect.width/2,
                                 options: [])
        context.restoreGState()
        
        // 2. Main glass morphism card background
        context.saveGState()
        let roundedRect = NSBezierPath(roundedRect: cardRect, xRadius: 28, yRadius: 28)
        roundedRect.addClip()
        
        // Glass background with high opacity for better blur
        let glassGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [
                                        NSColor.black.withAlphaComponent(0.95).cgColor,
                                        NSColor.black.withAlphaComponent(0.90).cgColor,
                                        NSColor.black.withAlphaComponent(0.85).cgColor
                                      ] as CFArray,
                                      locations: [0.0, 0.5, 1.0])!
        
        context.drawLinearGradient(glassGradient,
                                 start: CGPoint(x: cardRect.minX, y: cardRect.minY),
                                 end: CGPoint(x: cardRect.maxX, y: cardRect.maxY),
                                  options: [])
        context.restoreGState()
        
        // 3. Flowing liquid glass highlight
        context.saveGState()
        let highlightRect = cardRect.insetBy(dx: 4, dy: 4)
        let highlightPath = NSBezierPath(roundedRect: highlightRect, xRadius: 24, yRadius: 24)
        highlightPath.addClip()
        
        // Flowing highlight position
        let flowX = cos(animationPhase * 0.3) * cardRect.width * 0.1
        let flowY = sin(animationPhase * 0.2) * cardRect.height * 0.1
        
        let highlightGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: [
                                            NSColor.white.withAlphaComponent(0.3).cgColor,
                                            NSColor.white.withAlphaComponent(0.1).cgColor,
                                            NSColor.white.withAlphaComponent(0.05).cgColor,
                                            NSColor.clear.cgColor
                                         ] as CFArray,
                                         locations: [0.0, 0.3, 0.7, 1.0])!
        
        context.drawRadialGradient(highlightGradient,
                                 startCenter: CGPoint(x: highlightRect.midX - cardRect.width * 0.2 + flowX, y: highlightRect.midY - cardRect.height * 0.2 + flowY),
                                 startRadius: 0,
                                 endCenter: CGPoint(x: highlightRect.midX + flowX, y: highlightRect.midY + flowY),
                                 endRadius: highlightRect.width/2,
                                 options: [])
        context.restoreGState()
        
        // 4. Project header with glass styling
        drawProjectHeader(in: context, cardRect: cardRect)
        
        // 5. Task list with modern glass styling
        drawTaskList(in: context, cardRect: cardRect)
        
        // 6. Subtle internal liquid particles
        drawLiquidParticles(in: context, cardRect: cardRect)
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
    
    private func drawProjectHeader(in context: CGContext, cardRect: NSRect) {
        let headerRect = CGRect(x: cardRect.minX + 20, y: cardRect.maxY - 70, width: cardRect.width - 40, height: 50)
        
        // Add subtle drag handle indicator in the top area
        let dragHandleRect = CGRect(x: cardRect.minX + 20, y: cardRect.maxY - 15, width: cardRect.width - 40, height: 8)
        context.saveGState()
        context.setFillColor(NSColor.white.withAlphaComponent(0.2).cgColor)
        context.addEllipse(in: dragHandleRect)
        context.fillPath()
        context.restoreGState()
        
        // Modern opaque header background with orb color
        context.saveGState()
        let headerPath = NSBezierPath(roundedRect: headerRect, xRadius: 18, yRadius: 18)
        headerPath.addClip()
        
        // Modern opaque gradient with subtle variation
        let headerGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: [
                                        orbColor.withAlphaComponent(0.85).cgColor,
                                        orbColor.withAlphaComponent(0.75).cgColor,
                                        orbColor.withAlphaComponent(0.65).cgColor
                                       ] as CFArray,
                                      locations: [0.0, 0.5, 1.0])!
        
        context.drawLinearGradient(headerGradient,
                                  start: CGPoint(x: headerRect.minX, y: headerRect.maxY),
                                  end: CGPoint(x: headerRect.minX, y: headerRect.minY),
                                  options: [])
        context.restoreGState()
        
        // Project name with glass text effect - centered both horizontally and vertically
        let titleRect = CGRect(x: headerRect.minX, y: headerRect.minY + (50 - 24) / 2, width: headerRect.width, height: 24)
        
        // Calculate adaptive font size based on text length and available space
        let adaptiveFontSize = calculateAdaptiveFontSize(for: projectName, in: titleRect)
        let titleFont = NSFont(name: "SF Pro Display", size: adaptiveFontSize) ?? NSFont.systemFont(ofSize: adaptiveFontSize, weight: .bold)
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.white,
            .strokeColor: NSColor.black.withAlphaComponent(0.3),
            .strokeWidth: -0.5,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]
        projectName.draw(in: titleRect, withAttributes: titleAttributes)
    }
    
    private func drawTaskList(in context: CGContext, cardRect: NSRect) {
        let taskStartY = cardRect.maxY - 130  // Adjusted for new header position
        let taskHeight: CGFloat = 35        // Slightly taller tasks
        let taskSpacing: CGFloat = 12       // More spacing between tasks
        
        for (index, task) in tasks.enumerated() {
            let taskY = taskStartY - CGFloat(index) * (taskHeight + taskSpacing)
            let taskRect = CGRect(x: cardRect.minX + 20, y: taskY, width: cardRect.width - 40, height: taskHeight)
            
            // Skip tasks that would go below the card bounds
            if taskY < cardRect.minY + 20 {
                break
            }
            
            // Glass morphism task background
            context.saveGState()
            let taskPath = NSBezierPath(roundedRect: taskRect, xRadius: 12, yRadius: 12)
            taskPath.addClip()
            
            let taskGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: [
                                            NSColor.white.withAlphaComponent(0.8).cgColor,
                                            NSColor.white.withAlphaComponent(0.6).cgColor,
                                            NSColor.white.withAlphaComponent(0.4).cgColor
                                        ] as CFArray,
                                        locations: [0.0, 0.5, 1.0])!
            
            context.drawLinearGradient(taskGradient,
                                     start: CGPoint(x: taskRect.minX, y: taskRect.minY),
                                     end: CGPoint(x: taskRect.maxX, y: taskRect.maxY),
                                     options: [])
        context.restoreGState()
        
            // Task border
            context.saveGState()
            context.setStrokeColor(NSColor.black.withAlphaComponent(0.2).cgColor)
            context.setLineWidth(0.5)
            let taskBorderPath = NSBezierPath(roundedRect: taskRect.insetBy(dx: 0.25, dy: 0.25), xRadius: 11, yRadius: 11)
            taskBorderPath.stroke()
            context.restoreGState()
            
            // Modern glass checkbox
            drawGlassCheckbox(in: context, taskRect: taskRect, isCompleted: task.isCompleted, index: index)
            
            // Task title with glass text effect - vertically centered
            let taskTitleRect = CGRect(x: taskRect.minX + 35, y: taskRect.minY + (taskHeight - 22) / 2, width: taskRect.width - 40, height: 22)
            let taskFont = NSFont(name: "SF Pro Text", size: 14) ?? NSFont.systemFont(ofSize: 14, weight: .medium)
            let taskAttributes: [NSAttributedString.Key: Any] = [
                .font: taskFont,
                .foregroundColor: task.isCompleted ? NSColor.black.withAlphaComponent(0.4) : NSColor.black,
                .strokeColor: NSColor.white.withAlphaComponent(0.3),
                .strokeWidth: -0.5
            ]
            task.title.draw(in: taskTitleRect, withAttributes: taskAttributes)
        }
    }
    
    private func drawGlassCheckbox(in context: CGContext, taskRect: NSRect, isCompleted: Bool, index: Int) {
        let checkboxSize: CGFloat = 18
        let checkboxRect = CGRect(x: taskRect.minX + 8, y: taskRect.minY + (taskRect.height - checkboxSize)/2, width: checkboxSize, height: checkboxSize)
        
        // Glass morphism checkbox background
        context.saveGState()
        let checkboxPath = NSBezierPath(roundedRect: checkboxRect, xRadius: 6, yRadius: 6)
        checkboxPath.addClip()
        
        let checkboxGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: [
                                            NSColor.white.withAlphaComponent(0.2).cgColor,
                                            NSColor.white.withAlphaComponent(0.1).cgColor,
                                            NSColor.clear.cgColor
                                        ] as CFArray,
                                        locations: [0.0, 0.5, 1.0])!
        
        context.drawLinearGradient(checkboxGradient,
                                 start: CGPoint(x: checkboxRect.minX, y: checkboxRect.minY),
                                 end: CGPoint(x: checkboxRect.maxX, y: checkboxRect.maxY),
                                  options: [])
        context.restoreGState()
        
        // Checkbox border
        context.saveGState()
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(1.0)
        let checkboxBorderPath = NSBezierPath(roundedRect: checkboxRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 5, yRadius: 5)
        checkboxBorderPath.stroke()
        context.restoreGState()
        
        if isCompleted {
            // Glass checkmark with flowing effect
            context.saveGState()
            context.setStrokeColor(NSColor.systemGreen.withAlphaComponent(0.9).cgColor)
            context.setLineWidth(2.5)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            let checkmarkPath = NSBezierPath()
            checkmarkPath.move(to: CGPoint(x: checkboxRect.minX + 4, y: checkboxRect.midY))
            checkmarkPath.line(to: CGPoint(x: checkboxRect.midX, y: checkboxRect.minY + 4))
            checkmarkPath.line(to: CGPoint(x: checkboxRect.maxX - 4, y: checkboxRect.maxY - 4))
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
