import Cocoa
import SwiftUI
import QuartzCore

// MARK: - Task Data Model
    class Task: ObservableObject, Identifiable {
        let id = UUID()
        @Published var title: String
        @Published var isCompleted: Bool = false
        @Published var details: String = ""
        @Published var deadline: Date?
        @Published var priority: Int = 1 // 1-5 scale (1 = low, 5 = high)
        
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
        let task = Task(title: "New Task \(tasks.count + 1)")
        tasks.append(task)
        taskCount = tasks.count
        print("🎯 Added task to \(name): taskCount now \(taskCount), tasks.count = \(tasks.count)")
        print("🎯 Tasks in \(name): \(tasks.map { $0.title })")
    }
    
    func removeTask() {
        if !tasks.isEmpty {
            tasks.removeLast()
            taskCount = tasks.count
        }
    }
    
    func syncTaskCount() {
        let oldCount = taskCount
        taskCount = tasks.count
        if oldCount != taskCount {
            print("🎯 Synced task count for \(name): \(oldCount) -> \(taskCount) (tasks.count = \(tasks.count))")
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

private extension NSColor {
    func highlighted() -> NSColor {
        return blended(withFraction: 0.35, of: .white) ?? self
    }
    
    func shadowed() -> NSColor {
        return blended(withFraction: 0.35, of: .black) ?? self
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
            
            Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in
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
            Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in
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

class NotchOverlayController: ObservableObject, TaskDetailViewDelegate {
    private var overlayWindow: NSWindow?
    private var overlayView: NotchOverlayView?
    private var notchIndicatorWindow: NSWindow?
    private var semiCircleWindow: NSWindow?
    private var semiCircleView: SemiCircleWithOrbsView? // Added
    internal var currentOpenOrb: ProjectOrb? // Track which orb's card is currently open
    private var taskCardWindows: [UUID: NSWindow] = [:] // Track multiple task cards by orb ID
    private var taskDetailWindows: [UUID: NSWindow] = [:] // Track task detail windows by task ID
    private var isVisible = false
    var isSemiCircleVisible = false // Added
    private var orbManager = OrbManager()
    
        // Auto-fade timer system
    private var fadeTimer: Timer?
    private let fadeDelay: TimeInterval = 10.0
    private var isFaded: Bool = false
    private var orbRattleTimer: Timer?
    
    // Task drag visualization
    var draggedTaskWindow: NSWindow?
    var draggedTaskView: TaskDragView?
    
    // Card size preferences (stores custom sizes per orb)
    internal var customCardSizes: [UUID: CGSize] = [:]
    
    @Published var isVerticallyExpanding = false
    
    init() {
        setupOverlayWindow()
        setupNotchIndicator()
        setupSemiCircle()
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
        print("🎯 showTaskCard() called for orb: \(orb.name)")
        
        // Check if this orb already has a task card open
        if taskCardWindows[orb.id] != nil {
            print("🎯 Toggling off existing task card for orb: \(orb.name)")
            hideTaskCard(for: orb)
            return
        }
        
        print("🎯 Creating new task card for orb: \(orb.name)")
        print("🎯 Orb has \(orb.tasks.count) tasks")
        
        // Calculate dynamic height, or use custom size if set
        let cardWidth: CGFloat = customCardSizes[orb.id]?.width ?? 300
        let cardHeight: CGFloat = customCardSizes[orb.id]?.height ?? calculateCardHeight(for: orb.tasks.count)
        
        // Create a new task card window for this orb
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: cardWidth, height: cardHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = true
        window.level = .screenSaver
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovable = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Create task card view
        let taskCardView = TaskCardView()
        taskCardView.setController(self)
        taskCardView.updateTasks(orb.tasks, projectName: orb.name, orbColor: orb.color)
        
        // Ensure the view has the correct frame
        taskCardView.frame = NSRect(x: 0, y: 0, width: 300, height: 400)
        window.contentView = taskCardView
        
        print("🎯 Task card view frame: \(taskCardView.frame)")
        print("🎯 Window frame: \(window.frame)")
        
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
        
        // Final frame
        let finalFrame = NSRect(x: finalX, y: finalY, width: windowWidth, height: windowHeight)
        
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
        
        print("🎯 Task card animating in at position: \(finalFrame)")
        print("🎯 Total open task cards: \(taskCardWindows.count)")
    }
    
    func hideTaskCard() {
        // Hide all task cards
        for (_, window) in taskCardWindows {
            window.orderOut(nil)
        }
        taskCardWindows.removeAll()
        currentOpenOrb = nil
        print("🎯 All task cards hidden")
    }
    
    func hideTaskCard(for orb: ProjectOrb) {
        if let window = taskCardWindows[orb.id] {
            // Calculate orb center for exit animation
            guard let screen = NSScreen.main,
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
                
                // Update currentOpenOrb if this was the current one
                if self.currentOpenOrb?.id == orb.id {
                    self.currentOpenOrb = self.taskCardWindows.isEmpty ? nil : self.orbManager.orbs.first { self.taskCardWindows[$0.id] != nil }
                }
                
                print("🎯 Task card animated out for orb: \(orb.name)")
                print("🎯 Remaining open task cards: \(self.taskCardWindows.count)")
            })
        }
    }
    
    func taskCardPinStateChanged(isPinned: Bool) {
        print("📌 Task card pin state changed: \(isPinned ? "pinned" : "unpinned")")
        
        if isPinned {
            // If task card is pinned, don't fade it
            print("📌 Task card is pinned - will not fade")
        } else {
            // If task card is unpinned, reset the fade timer
            print("📌 Task card is unpinned - resetting fade timer")
            resetFadeTimer()
        }
    }
    
    func closeTaskCard(for taskCardView: TaskCardView) {
        // Find the orb ID for this task card view
        for (orbId, window) in taskCardWindows {
            if window.contentView === taskCardView {
                print("❌ Closing task card for orb ID: \(orbId)")
                hideTaskCard(for: orbManager.orbs.first { $0.id == orbId } ?? orbManager.orbs[0])
                return
            }
        }
        print("❌ Could not find orb for task card view")
    }
    
    func showTaskDetail(for task: Task, orbColor: NSColor) {
        print("🎯 Opening task detail for task: '\(task.title)' (ID: \(task.id))")
        
        // Close existing task detail window for this task if open
        if taskDetailWindows[task.id] != nil {
            print("🎯 Closing existing window for task ID: \(task.id)")
            closeTaskDetail(for: task.id)
        }
        
        // Create new task detail window with modern styling
        let window = TaskDetailWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 560),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        print("🎯 Created TaskDetailWindow: \(window)")
        
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
        print("🎯 Created TaskDetailView: \(taskDetailView)")
        
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
        
        print("🎯 Task detail window opened and stored for task: '\(task.title)'")
    }

    func closeTaskDetail(for taskId: UUID) {
        print("🎯 Close requested for task ID: \(taskId)")
        
        guard let window = taskDetailWindows.removeValue(forKey: taskId) else {
            print("⚠️ Close requested but no window found for task ID: \(taskId)")
            return
        }
        
        if let detailView = window.contentView as? TaskDetailView {
            detailView.prepareForClose()
        }
        
        window.makeFirstResponder(nil)
        window.orderOut(nil)
        window.contentView = nil
        window.delegate = nil
        
        print("🎯 Task detail window closed for task ID: \(taskId)")
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
            print("🎯 No valid drop target - task stays in original position")
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
            print("❌ Could not find source or target orb for task transfer")
            return
        }
        
        // Transfer task between orbs
        if let taskIndex = source.tasks.firstIndex(where: { $0.id == task.id }) {
            let transferredTask = source.tasks.remove(at: taskIndex)
            target.tasks.append(transferredTask)
            
            // Update both task cards
            sourceCard.updateTasks(source.tasks, projectName: source.name, orbColor: source.color)
            targetCard.updateTasks(target.tasks, projectName: target.name, orbColor: target.color)
            
            // Update orb task counters
            source.syncTaskCount()
            target.syncTaskCount()
            
            // Recalculate scroll for both task cards
            sourceCard.calculateMaxScrollOffset()
            targetCard.calculateMaxScrollOffset()
            
            // Trigger orb display update to refresh task counters
            semiCircleView?.needsDisplay = true
            
            print("🎯 Transferred task '\(task.title)' from '\(source.name)' to '\(target.name)'")
            print("🎯 Updated task counts - \(source.name): \(source.taskCount), \(target.name): \(target.taskCount)")
        }
    }
    
    // MARK: - Celebration System
    
    func triggerOrbCelebration() {
        print("🎉 Triggering orb celebration rattle!")
        
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
                print("🎉 Orb rattling complete!")
            }
        }
        
        // Store timer reference to prevent deallocation
        orbRattleTimer = rattleTimer
    }
    
    private func triggerSemiCircleCelebration() {
        // This could trigger a brief glow effect on the semi-circle itself
        // For now, just log that we're celebrating
        print("🎉 Semi-circle celebration triggered!")
    }
    
    deinit {
        // Clean up all timers
        fadeTimer?.invalidate()
        orbRattleTimer?.invalidate()
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
        
        // Fade out task cards that are not pinned
        for (orbId, window) in taskCardWindows {
            if window.isVisible {
                if let taskCardView = window.contentView as? TaskCardView, taskCardView.getPinnedState() {
                    print("📌 Task card for orb \(orbId) is pinned - skipping fade")
                } else {
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
            
            // Hide task cards that are not pinned
            var pinnedCards: [UUID: NSWindow] = [:]
            for (orbId, window) in self.taskCardWindows {
                if window.isVisible {
                    if let taskCardView = window.contentView as? TaskCardView, taskCardView.getPinnedState() {
                        print("📌 Task card for orb \(orbId) is pinned - keeping visible")
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
        
        // Show task cards if any were open (using new dynamic system)
        for (orbId, window) in taskCardWindows {
            if window.isVisible {
                if let taskCardView = window.contentView as? TaskCardView, taskCardView.getPinnedState() {
                    print("🔄 Showing pinned task card for orb \(orbId)")
                    window.alphaValue = 1.0
                    window.makeKeyAndOrderFront(nil)
                    
                    // Ensure the window can receive mouse events
                    window.acceptsMouseMovedEvents = true
                    window.ignoresMouseEvents = false
                }
            }
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
        let initialTaskCount = Int.random(in: 1...4)
        print("🎯 Creating orb '\(name)' with \(initialTaskCount) initial tasks")
        for _ in 0..<initialTaskCount {
            newOrb.addTask()
        }
        print("🎯 Final orb '\(name)' has taskCount: \(newOrb.taskCount), tasks.count: \(newOrb.tasks.count)")
        
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
        
        print("🎯 Created project '\(name)' with \(initialTaskCount) tasks")
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
        
        if isSemiCircleVisible {
            positionSemiCircle(window)
            window.alphaValue = 1.0
            window.orderFront(nil)
            if orbManager.visibleOrbCount == 0 {
                orbManager.showOrbs()
            }
            resetFadeTimerWithoutShowing()
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
        
        guard orbManager.isVisible else { 
            print("🎯 Orbs not visible, skipping draw")
            return 
        }
        
        let centerX = bounds.midX
        let centerY = bounds.maxY - 10 // Match the circle center
        let radius = min(bounds.width, bounds.height) / 2 + 18.5 // Match the circle radius
        
        
        for (index, orb) in orbManager.orbs.enumerated() {
            
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

// MARK: - Task Row Helpers
private struct TaskRowGeometry {
    let index: Int
    let rowRect: NSRect
    let checkboxRect: NSRect
    let dragRect: NSRect
}

private struct TaskRowChip {
    let text: String
    let foreground: NSColor
    let background: NSColor
    let border: NSColor?
}

private func glassBaseFill(for orbColor: NSColor) -> NSColor {
    let neutral = NSColor(calibratedWhite: 1.0, alpha: 0.02)
    let accent = orbColor.withAlphaComponent(0.07)
    return neutral.blended(withFraction: 0.18, of: accent) ?? neutral
}

private func glassGradientStops(for orbColor: NSColor) -> [CGColor] {
    let accent = orbColor.withAlphaComponent(0.08)
    let top = NSColor.white.withAlphaComponent(0.08).blended(withFraction: 0.1, of: accent) ?? NSColor.white.withAlphaComponent(0.08)
    let mid = NSColor.white.withAlphaComponent(0.06).blended(withFraction: 0.08, of: accent) ?? NSColor.white.withAlphaComponent(0.06)
    let bottom = NSColor.white.withAlphaComponent(0.04).blended(withFraction: 0.12, of: accent) ?? NSColor.white.withAlphaComponent(0.04)
    return [top.cgColor, mid.cgColor, bottom.cgColor]
}

private enum TaskRowMetrics {
    static let rowHeight: CGFloat = 72
    static let rowSpacing: CGFloat = 16
    static let listInset: CGFloat = 28
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
    static let headerHeight: CGFloat = 64
    static let headerDividerSpacing: CGFloat = 10
    static let cardInset: CGFloat = 24
    static let dragGripHeight: CGFloat = 18
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
    var pillForeground: NSColor = NSColor.white.withAlphaComponent(0.95)
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
        pillForeground = NSColor.systemGreen.withAlphaComponent(0.9)
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
        pillBackground = orbColor.withAlphaComponent(0.16)
        pillForeground = orbColor.withAlphaComponent(0.85)
    } else if !task.isCompleted {
        pillText = "\(priorityLabelText) Priority"
        pillBackground = priorityColor.withAlphaComponent(0.18)
        pillForeground = priorityColor.withAlphaComponent(0.9)
    } else {
        pillText = deadlineText
    }
    
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

// MARK: - Task Card View
class TaskCardView: NSView {
    private var tasks: [Task] = []
    private var projectName: String = ""
    private var orbColor: NSColor = .systemBlue
    private var animationPhase: Double = 0.0
    private weak var controller: NotchOverlayController?
    private let glassEffectView = PassthroughVisualEffectView()
    
    // Pin functionality
    private var isPinned = false
    private var pinButtonRect = NSRect.zero
    private var isHoveringPin = false
    
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
    
    private var dragGripRect: NSRect {
        let cardRect = bounds.insetBy(dx: TaskRowMetrics.cardInset, dy: TaskRowMetrics.cardInset)
        let gripHeight = min(TaskRowMetrics.dragGripHeight, max(0, cardRect.height))
        return NSRect(
            x: cardRect.minX,
            y: cardRect.maxY - gripHeight,
            width: cardRect.width,
            height: gripHeight
        )
    }
    
    // Celebration animation properties
    private var celebrationPhase: CGFloat = 0.0
    private var isCelebrating = false
    private var celebrationTimer: Timer?
    private var animationTimer: Timer?
    
    // Task completion animation
    private var completionAnimations: [UUID: (progress: CGFloat, scale: CGFloat, opacity: CGFloat)] = [:]
    private var completionAnimationTimers: [UUID: Timer] = [:]
    
    // Resize functionality
    private var isResizing = false
    private var resizeStartLocation = NSPoint.zero
    private var resizeStartSize = NSSize.zero
    private var resizeHandleRect = NSRect.zero
    private var isHoveringResizeHandle = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = 28
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.22).cgColor
        layer?.shadowOpacity = 1.0
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        layer?.shadowRadius = 12
        startAnimation()
        setupDragTracking()
        configureGlassEffect()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = 28
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.22).cgColor
        layer?.shadowOpacity = 1.0
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        layer?.shadowRadius = 12
        startAnimation()
        setupDragTracking()
        configureGlassEffect()
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
    }
    
    private func togglePin() {
        isPinned.toggle()
        needsDisplay = true
        
        // Notify controller about pin state change
        controller?.taskCardPinStateChanged(isPinned: isPinned)
    }
    
    private func closeTaskCard() {
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
            completionAnimationTimers[task.id]?.invalidate()
            completionAnimationTimers.removeValue(forKey: task.id)
        }
        
        // Recalculate scroll in case task visibility changed
        calculateMaxScrollOffset()
        needsDisplay = true
        
        print("🎯 Task '\(task.title)' marked as \(task.isCompleted ? "completed" : "incomplete")")
    }
    
    private func startTaskCompletionAnimation(for task: Task) {
        // Initialize animation state
        completionAnimations[task.id] = (progress: 0.0, scale: 1.0, opacity: 1.0)
        
        let animationDuration: TimeInterval = 0.3
        let frameRate: TimeInterval = 1.0 / 60.0
        let totalFrames = Int(animationDuration / frameRate)
        var currentFrame = 0
        
        // Invalidate existing timer if any
        completionAnimationTimers[task.id]?.invalidate()
        
        let timer = Timer.scheduledTimer(withTimeInterval: frameRate, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentFrame += 1
            let progress = CGFloat(currentFrame) / CGFloat(totalFrames)
            
            // Calculate animated values
            var strikethroughProgress = min(progress, 1.0)
            
            // Scale pulse: 1.0 → 1.05 (halfway) → 1.0
            let scaleProgress = progress * 2.0
            var scale: CGFloat
            if scaleProgress <= 1.0 {
                scale = 1.0 + (0.05 * scaleProgress) // 1.0 to 1.05
            } else {
                scale = 1.05 - (0.05 * (scaleProgress - 1.0)) // 1.05 to 1.0
            }
            
            // Fade to 50% opacity
            let opacity = 1.0 - (0.5 * progress)
            
            self.completionAnimations[task.id] = (
                progress: strikethroughProgress,
                scale: scale,
                opacity: opacity
            )
            
            self.needsDisplay = true
            
            if currentFrame >= totalFrames {
                timer.invalidate()
                self.completionAnimationTimers.removeValue(forKey: task.id)
                // Final state
                self.completionAnimations[task.id] = (progress: 1.0, scale: 1.0, opacity: 0.5)
            }
        }
        
        completionAnimationTimers[task.id] = timer
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
        
        // Start celebration animation timer
        celebrationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.celebrationPhase += 0.1
            
            // End celebration after 3 seconds (180 frames at 60fps)
            if self.celebrationPhase >= 18.0 {
                self.endCelebrationAnimation()
                timer.invalidate()
            }
            
            self.needsDisplay = true
        }
        
        print("🎉 Starting celebration animation!")
    }
    
    private func endCelebrationAnimation() {
        isCelebrating = false
        celebrationPhase = 0.0
        celebrationTimer?.invalidate()
        celebrationTimer = nil
        
        print("🎉 Celebration animation ended!")
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
        
        print("🎯 Started dragging task: \(tasks[taskIndex].title)")
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
        dragWindow.level = .screenSaver
        dragWindow.ignoresMouseEvents = true
        dragWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        // Create drag view
        let dragView = TaskDragView(task: task, orbColor: orbColor)
        dragView.frame = NSRect(x: 0, y: 0, width: baseWidth * scaleFactor, height: baseHeight * scaleFactor)
        dragWindow.contentView = dragView
        
        // Add rotation jitter (-3° to +3°)
        let rotationAngle = CGFloat.random(in: -3...3)
        if let contentView = dragWindow.contentView {
            contentView.wantsLayer = true
            contentView.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            contentView.layer?.position = CGPoint(x: contentView.bounds.midX, y: contentView.bounds.midY)
            contentView.layer?.transform = CATransform3DMakeRotation(rotationAngle * .pi / 180, 0, 0, 1)
            
            // Add stronger shadow
            contentView.shadow = NSShadow()
            contentView.layer?.shadowColor = NSColor.black.cgColor
            contentView.layer?.shadowOpacity = 0.5
            contentView.layer?.shadowOffset = CGSize(width: 0, height: -4)
            contentView.layer?.shadowRadius = 20
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
        
        // Start pulsing animation
        startDragPulseAnimation()
    }
    
    private func startDragPulseAnimation() {
        guard let dragWindow = controller?.draggedTaskWindow else { return }
        
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 1.08
        animation.toValue = 1.12
        animation.duration = 0.6
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        dragWindow.contentView?.layer?.add(animation, forKey: "dragPulse")
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
        let windowOrigin = NSPoint(
            x: mouseLocation.x - windowFrame.width / 2,
            y: mouseLocation.y - windowFrame.height / 2
        )
        
        // Smoothly move the window to follow the mouse
        dragWindow.setFrameOrigin(windowOrigin)
    }
    
    private func endTaskDrag() {
        guard isDraggingTask else { return }
        
        print("🎯 Ending task drag")
        
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
            return
        }
        
        let taskCount = CGFloat(tasks.count)
        if taskCount <= 0 {
            maxScrollOffset = 0
            taskScrollOffset = 0
            return
        }
        
        let contentHeight = taskCount * TaskRowMetrics.rowHeight + max(0, taskCount - 1) * TaskRowMetrics.rowSpacing
        maxScrollOffset = max(0, contentHeight - resolvedHeight)
        taskScrollOffset = max(0, min(taskScrollOffset, maxScrollOffset))
    }
    
    private func defaultListHeight() -> CGFloat {
        let cardRect = bounds.insetBy(dx: TaskRowMetrics.cardInset, dy: TaskRowMetrics.cardInset)
        let headerBottom = cardRect.maxY - TaskRowMetrics.headerHeight
        return max(0, headerBottom - (cardRect.minY + TaskRowMetrics.listInset) - TaskRowMetrics.headerDividerSpacing)
    }
    
    deinit {
        celebrationTimer?.invalidate()
        animationTimer?.invalidate()
    }
    
    private func startAnimation() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.animationPhase += 0.02
            self.needsDisplay = true
        }
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
        if dragGripRect.contains(locationInView) {
            guard let window = window else { return }
            isDraggingCard = true
            dragStartScreenLocation = NSEvent.mouseLocation
            initialWindowOrigin = window.frame.origin
            NSCursor.closedHand.set()
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
        
        // Change cursor when hovering over drag grip
        let locationInView = convert(event.locationInWindow, from: nil)
        if dragGripRect.contains(locationInView) && !closeButtonRect.contains(locationInView) && !pinButtonRect.contains(locationInView) {
            NSCursor.openHand.set()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        isHoveringCard = false
        isHoveringClose = false
        isHoveringPin = false
        needsDisplay = true
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
        isHoveringClose = closeButtonRect.contains(locationInView)
        isHoveringPin = pinButtonRect.contains(locationInView)
        if wasHoveringClose != isHoveringClose || wasHoveringPin != isHoveringPin {
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
            
            if dragGripRect.contains(locationInView) && !closeButtonRect.contains(locationInView) && !pinButtonRect.contains(locationInView) {
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
        
        // Apply bounds: 0 (top task at original position) to maxScrollOffset (bottom task visible)
        let clampedOffset = max(0, min(newOffset, maxScrollOffset))
        
        // Only update if the offset actually changed
        if clampedOffset != taskScrollOffset {
            taskScrollOffset = clampedOffset
            needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Clear to transparent
        context.clear(dirtyRect)
        
        let cardRect = bounds.insetBy(dx: TaskRowMetrics.cardInset, dy: TaskRowMetrics.cardInset)
        
        drawGlassBackground(in: context, cardRect: cardRect)
        drawDragGrip(in: context, cardRect: cardRect)
        
        if isShowingDropIndicator {
            drawDropTargetHalo(in: context, cardRect: cardRect)
        }
        
        if isCelebrating {
            drawCelebrationRimGlow(in: context, cardRect: cardRect)
        }
        
        drawProjectHeader(in: context, cardRect: cardRect)
        drawTaskList(in: context, cardRect: cardRect)
        drawResizeHandle(in: context, cardRect: cardRect)
    }
    
    private func drawGlassBackground(in context: CGContext, cardRect: CGRect) {
        let fillColor = glassBaseFill(for: orbColor)
        let gradientStops = glassGradientStops(for: orbColor)
        let clipPath = NSBezierPath(roundedRect: cardRect, xRadius: 28, yRadius: 28)
        
        context.saveGState()
        clipPath.addClip()
        
        // Base fill keeps the palette pale with a subtle orb tint, matching row glass styling
        context.setFillColor(fillColor.cgColor)
        clipPath.fill()
        
        // Apply a linear gradient to tease out the liquid depth (mirrors task row treatment)
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: gradientStops as CFArray,
            locations: [0.0, 0.55, 1.0]
        ) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: cardRect.midX, y: cardRect.maxY),
                end: CGPoint(x: cardRect.midX, y: cardRect.minY),
                options: []
            )
        }
        context.restoreGState()
        
        // Subtle interior shadow keeps the same pillowy depth used on individual rows
        context.saveGState()
        let shadowPath = NSBezierPath(roundedRect: cardRect, xRadius: 28, yRadius: 28)
        context.setFillColor(fillColor.withAlphaComponent(0.4).cgColor)
        context.setShadow(offset: CGSize(width: 0, height: -2), blur: 4.5, color: NSColor.black.withAlphaComponent(0.04).cgColor)
        shadowPath.fill()
        context.restoreGState()
    }
    
    private func drawDragGrip(in context: CGContext, cardRect: CGRect) {
        let gripHeight = min(TaskRowMetrics.dragGripHeight, cardRect.height)
        guard gripHeight > 0 else { return }
        
        let horizontalInset: CGFloat = 12
        let topY = cardRect.maxY - 1
        let bottomY = topY - gripHeight
        let gripRect = CGRect(
            x: cardRect.minX + horizontalInset,
            y: bottomY,
            width: cardRect.width - horizontalInset * 2,
            height: gripHeight
        )
        let gripRadius = min(18, gripRect.height / 2)
        
        context.saveGState()
        let clipPath = NSBezierPath(roundedRect: cardRect, xRadius: 28, yRadius: 28)
        clipPath.addClip()
        context.clip(to: gripRect)

        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor.white.withAlphaComponent(0.32).cgColor,
                orbColor.withAlphaComponent(0.18).cgColor,
                NSColor.white.withAlphaComponent(0.1).cgColor
            ] as CFArray,
            locations: [0.0, 0.55, 1.0]
        ) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: gripRect.midX, y: gripRect.maxY),
                end: CGPoint(x: gripRect.midX, y: gripRect.minY),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }
        context.restoreGState()

        context.saveGState()
        let insetGrip = NSBezierPath(roundedRect: gripRect.insetBy(dx: 0.5, dy: 0), xRadius: gripRadius, yRadius: gripRadius)
        NSColor.white.withAlphaComponent(0.28).setStroke()
        insetGrip.lineWidth = 1.0
        insetGrip.stroke()
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
    
    private func drawProjectHeader(in context: CGContext, cardRect: NSRect) {
        // Simplified header - just title and stats without background box
        let headerTop = cardRect.maxY - 24
        let titleRect = CGRect(x: cardRect.minX + 24, y: headerTop - 20, width: cardRect.width - 48, height: 20)
        
        // Project title
        let titleFont = NSFont.systemFont(ofSize: 18, weight: .semibold)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.92)
        ]
        projectName.draw(in: titleRect, withAttributes: titleAttributes)

        // Stats below title with orb color accent
        let completedCount = tasks.filter { $0.isCompleted }.count
        let detailString = "\(tasks.count) task" + (tasks.count == 1 ? "" : "s") + " · \(completedCount) done"
        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.82)
        ]
        let detailRect = CGRect(x: cardRect.minX + 24, y: headerTop - 46, width: cardRect.width - 48, height: 16)
        detailString.draw(in: detailRect, withAttributes: detailAttributes)
        
        // Subtle separator line
        context.saveGState()
        let separatorY = headerTop - 56
        context.move(to: CGPoint(x: cardRect.minX + 24, y: separatorY))
        context.addLine(to: CGPoint(x: cardRect.maxX - 24, y: separatorY))
        context.setStrokeColor(orbColor.withAlphaComponent(0.25).cgColor)
        context.setLineWidth(1.0)
        context.strokePath()
        context.restoreGState()

        drawCloseButton(in: context, headerRect: cardRect)
        drawPinButton(in: context, headerRect: cardRect)
    }
    
    private func drawHeaderStats(in context: CGContext, headerRect: CGRect) {
        let totalTasks = tasks.count
        let completedTasks = tasks.filter { $0.isCompleted }.count
        let openTasks = totalTasks - completedTasks
        
        let stats = [
            ("Open", openTasks, NSColor.white.withAlphaComponent(0.85)),
            ("Done", completedTasks, NSColor.white.withAlphaComponent(0.65))
        ]
        
        let chipHeight: CGFloat = 20
        let chipPadding: CGFloat = 10
        var nextX = headerRect.midX - CGFloat(stats.count) * 65.0 / 2.0
        let chipY = headerRect.minY + 8
        
        for (label, value, textColor) in stats {
            let chipRect = CGRect(x: nextX, y: chipY, width: 65, height: chipHeight)
            let chipPath = NSBezierPath(roundedRect: chipRect, xRadius: chipHeight / 2, yRadius: chipHeight / 2)
            
            context.saveGState()
            context.setFillColor(NSColor.white.withAlphaComponent(0.18).cgColor)
            chipPath.fill()
            context.restoreGState()
            
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            
            let attributed = NSMutableAttributedString(
                string: "\(label) \(value)",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: textColor,
                    .paragraphStyle: paragraph
                ]
            )
            attributed.draw(in: chipRect.insetBy(dx: chipPadding/2, dy: 2))
            
            nextX += chipRect.width + 10
        }
    }
    
    private func drawCloseButton(in context: CGContext, headerRect: CGRect) {
        // Only draw when hovering over card
        guard isHoveringCard else {
            // Still set the rect for hit testing
            let buttonSize: CGFloat = 24
            let buttonMargin: CGFloat = 8
            closeButtonRect = CGRect(
                x: headerRect.maxX - buttonSize - buttonMargin,
                y: headerRect.minY + (headerRect.height - buttonSize) / 2,
                width: buttonSize,
                height: buttonSize
            )
            return
        }
        
        // Close button size and position (right side now)
        let buttonSize: CGFloat = 24
        let buttonMargin: CGFloat = 8
        closeButtonRect = CGRect(
            x: headerRect.maxX - buttonSize - buttonMargin,
            y: headerRect.minY + (headerRect.height - buttonSize) / 2,
            width: buttonSize,
            height: buttonSize
        )
        
        // Apply hover scale
        let scale: CGFloat = isHoveringClose ? 1.1 : 1.0
        let opacity: CGFloat = isHoveringClose ? 0.3 : 0.18
        
        context.saveGState()
        if scale != 1.0 {
            context.translateBy(x: closeButtonRect.midX, y: closeButtonRect.midY)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -closeButtonRect.midX, y: -closeButtonRect.midY)
        }
        
        // Circular background
        let buttonPath = NSBezierPath(ovalIn: closeButtonRect)
        context.setFillColor(NSColor.white.withAlphaComponent(opacity).cgColor)
        buttonPath.fill()
        context.restoreGState()
        
        // Draw X icon
        context.saveGState()
        if scale != 1.0 {
            context.translateBy(x: closeButtonRect.midX, y: closeButtonRect.midY)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -closeButtonRect.midX, y: -closeButtonRect.midY)
        }
        drawCloseIcon(in: context, rect: closeButtonRect)
        context.restoreGState()
    }
    
    private func drawCloseIcon(in context: CGContext, rect: CGRect) {
        let iconSize: CGFloat = 12
        let iconRect = CGRect(
            x: rect.midX - iconSize/2,
            y: rect.midY - iconSize/2,
            width: iconSize,
            height: iconSize
        )
        
            context.saveGState()
        context.setLineWidth(1.4)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.75).cgColor)
        
        // Draw X
        context.move(to: CGPoint(x: iconRect.minX + 2, y: iconRect.minY + 2))
        context.addLine(to: CGPoint(x: iconRect.maxX - 2, y: iconRect.maxY - 2))
        context.move(to: CGPoint(x: iconRect.maxX - 2, y: iconRect.minY + 2))
        context.addLine(to: CGPoint(x: iconRect.minX + 2, y: iconRect.maxY - 2))
        context.strokePath()
        
        context.restoreGState()
    }
    
    private func drawPinButton(in context: CGContext, headerRect: CGRect) {
        // Pin button on left side
        let buttonSize: CGFloat = 24
        let buttonMargin: CGFloat = 8
        pinButtonRect = CGRect(
            x: headerRect.minX + buttonMargin,
            y: headerRect.minY + (headerRect.height - buttonSize) / 2,
            width: buttonSize,
            height: buttonSize
        )
        
        // Only draw when hovering over card or when pinned
        guard isHoveringCard || isPinned else {
            return
        }
        
        // Apply hover scale
        let scale: CGFloat = isHoveringPin ? 1.1 : 1.0
        var opacity: CGFloat = isHoveringPin ? 0.3 : 0.18
        if isPinned {
            opacity = isHoveringPin ? 0.75 : 0.65
        }
        
        context.saveGState()
        if scale != 1.0 {
            context.translateBy(x: pinButtonRect.midX, y: pinButtonRect.midY)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -pinButtonRect.midX, y: -pinButtonRect.midY)
        }
        
        // Circular background
        let buttonPath = NSBezierPath(ovalIn: pinButtonRect)
        let fillColor = isPinned ? orbColor.withAlphaComponent(opacity) : NSColor.white.withAlphaComponent(opacity)
        context.setFillColor(fillColor.cgColor)
        buttonPath.fill()
        context.restoreGState()
        
        // Draw pin icon
        context.saveGState()
        if scale != 1.0 {
            context.translateBy(x: pinButtonRect.midX, y: pinButtonRect.midY)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -pinButtonRect.midX, y: -pinButtonRect.midY)
        }
        drawPinIcon(in: context, rect: pinButtonRect, isPinned: isPinned)
        context.restoreGState()
    }
    
    private func drawPinIcon(in context: CGContext, rect: CGRect, isPinned: Bool) {
        let iconSize: CGFloat = 12
        let iconRect = CGRect(
            x: rect.midX - iconSize/2,
            y: rect.midY - iconSize/2,
            width: iconSize,
            height: iconSize
        )
        
        context.saveGState()
        context.setLineWidth(1.4)
        
        if isPinned {
            context.setFillColor(NSColor.white.withAlphaComponent(0.95).cgColor)
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.95).cgColor)

            let pinHeadRect = CGRect(x: iconRect.midX - 3, y: iconRect.maxY - 6, width: 6, height: 6)
            context.addEllipse(in: pinHeadRect)
            context.fillPath()

            context.move(to: CGPoint(x: iconRect.midX, y: iconRect.minY + 2))
            context.addLine(to: CGPoint(x: iconRect.midX, y: iconRect.maxY - 3))
            context.strokePath()
        } else {
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.75).cgColor)

            let pinHeadRect = CGRect(x: iconRect.midX - 3, y: iconRect.maxY - 6, width: 6, height: 6)
            context.addEllipse(in: pinHeadRect)
            context.strokePath()

            context.move(to: CGPoint(x: iconRect.midX, y: iconRect.minY + 2))
            context.addLine(to: CGPoint(x: iconRect.midX, y: iconRect.maxY - 3))
            context.strokePath()
        }

        context.restoreGState()
    }
    
    private func drawTaskList(in context: CGContext, cardRect: NSRect) {
        let headerBottom = cardRect.maxY - TaskRowMetrics.headerHeight
        let listRect = NSRect(
            x: cardRect.minX + TaskRowMetrics.listInset,
            y: cardRect.minY + TaskRowMetrics.listInset,
            width: cardRect.width - TaskRowMetrics.listInset * 2,
            height: headerBottom - (cardRect.minY + TaskRowMetrics.listInset) - TaskRowMetrics.headerDividerSpacing
        )
        
        calculateMaxScrollOffset(forListHeight: listRect.height)
        rowGeometries.removeAll()

        if tasks.isEmpty {
            drawEmptyTaskState(in: context, rect: listRect)
            return
        }
        
        if maxScrollOffset > 0 {
            drawScrollBar(in: context, trackRect: listRect)
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
        let scrollBarWidth: CGFloat = 7
        let scrollBarX = trackRect.maxX - scrollBarWidth - 4
        let scrollBarY = trackRect.minY
        let scrollBarHeight = trackRect.height
        let thumbHeight = max(24, scrollBarHeight * (trackRect.height / (trackRect.height + maxScrollOffset)))
        let thumbOffset = (scrollBarHeight - thumbHeight) * (maxScrollOffset == 0 ? 0 : taskScrollOffset / maxScrollOffset)
        let thumbRect = NSRect(x: scrollBarX, y: scrollBarY + thumbOffset, width: scrollBarWidth, height: thumbHeight)

        scrollBarRect = NSRect(x: scrollBarX, y: scrollBarY, width: scrollBarWidth, height: scrollBarHeight)

        context.saveGState()
        let trackPath = NSBezierPath(roundedRect: scrollBarRect.insetBy(dx: 2, dy: 8), xRadius: scrollBarWidth/2, yRadius: scrollBarWidth/2)
        NSColor.white.withAlphaComponent(0.12).setFill()
        trackPath.fill()
        context.restoreGState()

        context.saveGState()
        let thumbPath = NSBezierPath(roundedRect: thumbRect.insetBy(dx: 0.5, dy: 2), xRadius: scrollBarWidth/2, yRadius: scrollBarWidth/2)
        if let thumbGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                orbColor.withAlphaComponent(isHoveringScrollBar ? 0.75 : 0.55).cgColor,
                orbColor.highlighted().withAlphaComponent(isHoveringScrollBar ? 0.65 : 0.45).cgColor
            ] as CFArray,
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
        context.setFillColor(NSColor.white.withAlphaComponent(0.12).cgColor)
        quietBackground.fill()
        context.restoreGState()

        let heading = "No tasks yet"
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let headingAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.7),
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
            .foregroundColor: NSColor.white.withAlphaComponent(0.5),
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
        // Apply completion animation if active
        var animatedOpacity: CGFloat = 1.0
        var animatedScale: CGFloat = 1.0
        if let animation = completionAnimations[task.id] {
            animatedOpacity = animation.opacity
            animatedScale = animation.scale
        } else if task.isCompleted {
            animatedOpacity = 0.5 // Final completed state
        }
        
        // Apply scale transformation
        context.saveGState()
        if animatedScale != 1.0 {
            let centerX = rect.midX
            let centerY = rect.midY
            context.translateBy(x: centerX, y: centerY)
            context.scaleBy(x: animatedScale, y: animatedScale)
            context.translateBy(x: -centerX, y: -centerY)
        }
        
        let rowPath = NSBezierPath(roundedRect: rect, xRadius: 16, yRadius: 16)
        context.saveGState()
        
        // Frosted glass background for task rows
        let glassAlpha = (task.isCompleted ? 0.22 : 0.52) * animatedOpacity
        let glassColor = NSColor(calibratedWhite: 0.96, alpha: glassAlpha).blended(withFraction: 0.12, of: orbColor)
        context.setFillColor((glassColor ?? NSColor(calibratedWhite: 0.98, alpha: glassAlpha)).cgColor)
        rowPath.fill()
        
        // Add subtle inner shadow for depth
        context.setShadow(offset: CGSize(width: 0, height: 1), blur: 2, color: NSColor.black.withAlphaComponent(0.08).cgColor)
        rowPath.fill()
        
        context.restoreGState()
        
        context.saveGState()
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.18 * animatedOpacity).cgColor)
        context.setLineWidth(1.0)
        rowPath.stroke()
        context.restoreGState()

        // Minimal drag indicator dot
        let indicatorSize: CGFloat = 6
        let indicatorRect = CGRect(
            x: rect.minX + TaskRowMetrics.accentInset,
            y: rect.midY - indicatorSize / 2,
            width: indicatorSize,
            height: indicatorSize
        )
        context.saveGState()
        context.setFillColor(orbColor.withAlphaComponent(task.isCompleted ? 0.35 : 0.6).cgColor)
        context.fillEllipse(in: indicatorRect)
        context.restoreGState()

        drawRoundedCheckbox(in: context, rect: checkboxRect, isCompleted: task.isCompleted)

        let contentX = indicatorRect.maxX + TaskRowMetrics.contentSpacing
        let contentWidth = max(0, checkboxRect.minX - contentX - TaskRowMetrics.contentSpacing)
        let contentTop = rect.maxY - TaskRowMetrics.rowVerticalPadding

        let titleRect = CGRect(x: contentX, y: contentTop - 24, width: contentWidth, height: 24)
        let titleFont = NSFont.systemFont(ofSize: 15, weight: task.isCompleted ? .regular : .semibold)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let titleColor = task.isCompleted ? NSColor(calibratedWhite: 0.45, alpha: 0.90 * animatedOpacity) : NSColor(calibratedWhite: 0.12, alpha: 0.98 * animatedOpacity)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: titleColor,
            .paragraphStyle: paragraph
        ]
        task.title.draw(in: titleRect, withAttributes: titleAttributes)
        
        // Draw animated strikethrough if task is completed or completing
        if task.isCompleted, let animation = completionAnimations[task.id] {
            // Animated strikethrough
            let strikethroughY = titleRect.midY
            let strikethroughWidth = titleRect.width * animation.progress
            context.saveGState()
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.28 * animatedOpacity).cgColor)
            context.setLineWidth(1.5)
            context.move(to: CGPoint(x: titleRect.minX, y: strikethroughY))
            context.addLine(to: CGPoint(x: titleRect.minX + strikethroughWidth, y: strikethroughY))
            context.strokePath()
            context.restoreGState()
        } else if task.isCompleted {
            // Static strikethrough for fully completed tasks
            let strikethroughY = titleRect.midY
            context.saveGState()
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.28 * animatedOpacity).cgColor)
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

        var snippetBottom = rect.minY + TaskRowMetrics.rowVerticalPadding
        if !snippet.isEmpty {
            let snippetRect = CGRect(
                x: contentX,
                y: max(rect.minY + TaskRowMetrics.rowVerticalPadding, titleRect.minY - 18),
                width: contentWidth,
                height: 16
            )
            let snippetAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor(calibratedWhite: 0.32, alpha: 0.9),
                .paragraphStyle: paragraph
            ]
            snippet.draw(in: snippetRect, withAttributes: snippetAttributes)
            snippetBottom = snippetRect.maxY
        }

        var chipsBaselineY = max(rect.minY + TaskRowMetrics.rowVerticalPadding, snippetBottom + 4)
        let maxBaseline = titleRect.minY - TaskRowMetrics.chipHeight - 2
        chipsBaselineY = min(chipsBaselineY, maxBaseline)
        let chips = makeTaskRowChips(for: task, orbColor: orbColor)
        _ = drawTaskChips(chips, startingAt: contentX, baselineY: chipsBaselineY, context: context)
        
        // Restore graphics state (for scale transformation)
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

// MARK: - Task Detail View
protocol TaskDetailViewDelegate: AnyObject {
    func closeTaskDetail(for taskId: UUID)
}

class TaskDetailView: NSView {
    private var task: Task
    private var orbColor: NSColor
    private weak var delegate: TaskDetailViewDelegate?
    
    private let backdropView = NSVisualEffectView()
    private let contentStack = NSStackView()
    private let chromeLayer = CAGradientLayer()
    private let headerGradientLayer = CAGradientLayer()
    private let dragStripView = TaskDetailDragStripView()
    
    private let headerBar = NSView()
    private let orbBadge = NSView()
    private let titleField = NSTextField()
    private let headerSubtitleLabel = NSTextField(labelWithString: "")
    private let closeButton = NSButton()
    
    private let metaRow = NSStackView()
    private let statusButton = NSButton()
    private let dueButton = NSButton()
    private let clearDueButton = NSButton()
    private let priorityControl = NSSegmentedControl(labels: ["Low", "Med", "High"], trackingMode: .selectOne, target: nil, action: nil)
    
    private let notesLabel = NSTextField(labelWithString: "Notes")
    private let notesScrollView = NSScrollView()
    private let notesTextView = NotesTextView()
    private let notesPlaceholder = NSTextField(labelWithString: "Add any details, decisions, or next steps…")
    
    private let actionRow = NSStackView()
    private let copyTitleButton = NSButton()
    private let copyNotesButton = NSButton()
    
    private let metadataLabel = NSTextField(labelWithString: "")
    
    private lazy var datePopover: NSPopover = createDatePopover()
    private let datePicker = NSDatePicker()
    
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    private lazy var dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter
    }()
    
    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    private let priorityValues = [1, 3, 5]
    private let priorityLabels = ["Low", "Medium", "High"]
    
    private var isClosing = false
    
    init(task: Task, orbColor: NSColor) {
        self.task = task
        self.orbColor = orbColor
        super.init(frame: NSRect(x: 0, y: 0, width: 440, height: 560))
        translatesAutoresizingMaskIntoConstraints = false
        setupView()
        updateUI()
    }
    
    func setDelegate(_ delegate: TaskDetailViewDelegate?) {
        self.delegate = delegate
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        datePopover.close()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 24
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.2).cgColor
        layer?.shadowOpacity = 1.0
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        layer?.shadowRadius = 12
        
        configureBackdrop()
        configureDragStrip()
        configureContentStack()
        configureHeader()
        configureMetaRow()
        configureNotesSection()
        configureActionRow()
        configureMetadataLabel()
        chromeLayer.type = .axial
        chromeLayer.opacity = 0.45
        chromeLayer.cornerRadius = 24
        chromeLayer.masksToBounds = true
        backdropView.layer?.insertSublayer(chromeLayer, at: 0)
        
        updateChromePalette()
        updateDragStripAppearance()
    }
    
    override func layout() {
        super.layout()
        chromeLayer.frame = backdropView.bounds
        headerGradientLayer.frame = headerBar.bounds
    }
    
    private func configureBackdrop() {
        backdropView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.state = .active
        backdropView.blendingMode = .withinWindow
        backdropView.material = .hudWindow
        backdropView.wantsLayer = true
        backdropView.layer?.cornerRadius = 24
        backdropView.layer?.masksToBounds = true
        addSubview(backdropView)
        
        NSLayoutConstraint.activate([
            backdropView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backdropView.topAnchor.constraint(equalTo: topAnchor),
            backdropView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func configureDragStrip() {
        dragStripView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dragStripView)
        
        NSLayoutConstraint.activate([
            dragStripView.topAnchor.constraint(equalTo: topAnchor),
            dragStripView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dragStripView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dragStripView.heightAnchor.constraint(equalToConstant: TaskRowMetrics.dragGripHeight)
        ])
    }
    
    private func configureContentStack() {
        contentStack.orientation = .vertical
        contentStack.spacing = 32
        contentStack.alignment = .leading
        contentStack.edgeInsets = NSEdgeInsets(top: 44, left: 44, bottom: 40, right: 44)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        backdropView.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: backdropView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: backdropView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: backdropView.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: backdropView.bottomAnchor)
        ])
    }
    
    private func configureHeader() {
        headerBar.translatesAutoresizingMaskIntoConstraints = false
        headerBar.wantsLayer = true
        headerBar.layer?.cornerRadius = 22
        headerBar.layer?.masksToBounds = true
        headerGradientLayer.cornerRadius = 22
        headerGradientLayer.masksToBounds = true
        headerGradientLayer.opacity = 0.6
        headerGradientLayer.startPoint = CGPoint(x: 0.0, y: 1.0)
        headerGradientLayer.endPoint = CGPoint(x: 1.0, y: 0.0)
        headerGradientLayer.colors = [
            NSColor.white.withAlphaComponent(0.36).cgColor,
            orbColor.withAlphaComponent(0.18).cgColor
        ]
        headerGradientLayer.locations = [0.0, 1.0]
        headerBar.layer?.insertSublayer(headerGradientLayer, at: 0)
        headerBar.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        headerBar.layer?.borderWidth = 0.8
        
        orbBadge.wantsLayer = true
        orbBadge.layer?.cornerRadius = 7
        orbBadge.layer?.backgroundColor = orbColor.cgColor
        orbBadge.layer?.shadowColor = orbColor.withAlphaComponent(0.6).cgColor
        orbBadge.layer?.shadowOpacity = 0.8
        orbBadge.layer?.shadowOffset = .zero
        orbBadge.layer?.shadowRadius = 6
        orbBadge.translatesAutoresizingMaskIntoConstraints = false
        orbBadge.widthAnchor.constraint(equalToConstant: 14).isActive = true
        orbBadge.heightAnchor.constraint(equalToConstant: 14).isActive = true
        
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.isEditable = true
        titleField.isBordered = false
        titleField.drawsBackground = false
        titleField.focusRingType = .none
        titleField.font = NSFont.systemFont(ofSize: 27, weight: .semibold)
        titleField.textColor = NSColor(calibratedWhite: 0.08, alpha: 0.95)
        titleField.alignment = .left
        titleField.lineBreakMode = .byTruncatingTail
        titleField.stringValue = task.title
        titleField.delegate = self
        titleField.target = self
        titleField.action = #selector(handleTitleEditingEnd)
        
        headerSubtitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        headerSubtitleLabel.textColor = NSColor(calibratedWhite: 0.35, alpha: 0.9)
        headerSubtitleLabel.alignment = .left
        headerSubtitleLabel.lineBreakMode = .byTruncatingTail
        headerSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeButton.imagePosition = .imageOnly
        closeButton.contentTintColor = NSColor.white.withAlphaComponent(0.85)
        closeButton.target = self
        closeButton.action = #selector(handleCloseTapped)
        closeButton.wantsLayer = true
        closeButton.layer?.cornerRadius = 16
        closeButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
        closeButton.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        closeButton.layer?.borderWidth = 1.0
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.widthAnchor.constraint(equalToConstant: 32).isActive = true
        closeButton.heightAnchor.constraint(equalTo: closeButton.widthAnchor).isActive = true
        
        let textColumn = NSStackView()
        textColumn.orientation = .vertical
        textColumn.alignment = .leading
        textColumn.spacing = 2
        textColumn.translatesAutoresizingMaskIntoConstraints = false
        textColumn.addArrangedSubview(titleField)
        textColumn.addArrangedSubview(headerSubtitleLabel)
        
        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 16
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.addArrangedSubview(orbBadge)
        headerStack.addArrangedSubview(textColumn)
        headerStack.addArrangedSubview(closeButton)
        textColumn.setContentHuggingPriority(.defaultLow, for: .horizontal)
        closeButton.setContentHuggingPriority(.required, for: .horizontal)
        
        headerBar.addSubview(headerStack)
        NSLayoutConstraint.activate([
            headerStack.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor, constant: -20),
            headerStack.topAnchor.constraint(equalTo: headerBar.topAnchor, constant: 14),
            headerStack.bottomAnchor.constraint(equalTo: headerBar.bottomAnchor, constant: -14)
        ])
        
        contentStack.addArrangedSubview(headerBar)
        headerBar.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor).isActive = true
        headerBar.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor).isActive = true
    }
    
    private func configureMetaRow() {
        metaRow.orientation = .horizontal
        metaRow.alignment = .top
        metaRow.spacing = 24
        metaRow.distribution = .fillEqually
        metaRow.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(metaRow)
        metaRow.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor).isActive = true
        metaRow.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor).isActive = true
        
        statusButton.title = ""
        statusButton.isBordered = false
        statusButton.wantsLayer = true
        statusButton.layer?.cornerRadius = 14
        statusButton.target = self
        statusButton.action = #selector(handleStatusToggle)
        statusButton.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        statusButton.contentTintColor = .white
        statusButton.imagePosition = .imageLeading
        statusButton.translatesAutoresizingMaskIntoConstraints = false
        statusButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        statusButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        statusButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        dueButton.title = "Set due date"
        dueButton.isBordered = false
        dueButton.wantsLayer = true
        dueButton.layer?.cornerRadius = 14
        dueButton.target = self
        dueButton.action = #selector(handleDueTapped)
        dueButton.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        dueButton.contentTintColor = .white
        dueButton.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Set due date")
        dueButton.imagePosition = .imageLeading
        dueButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        dueButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        dueButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        clearDueButton.isBordered = false
        clearDueButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Clear due date")
        clearDueButton.contentTintColor = NSColor.white.withAlphaComponent(0.6)
        clearDueButton.target = self
        clearDueButton.action = #selector(handleClearDue)
        clearDueButton.toolTip = "Clear due date"
        clearDueButton.translatesAutoresizingMaskIntoConstraints = false
        clearDueButton.widthAnchor.constraint(equalToConstant: 20).isActive = true
        clearDueButton.heightAnchor.constraint(equalToConstant: 20).isActive = true
        clearDueButton.setContentHuggingPriority(.required, for: .horizontal)
        
        priorityControl.segmentStyle = .automatic
        priorityControl.target = self
        priorityControl.action = #selector(handlePriorityChanged)
        priorityControl.translatesAutoresizingMaskIntoConstraints = false
        priorityControl.widthAnchor.constraint(equalToConstant: 210).isActive = true
        
        let statusColumn = makeMetaColumn(title: "STATUS", "checkmark.seal.fill", NSColor.systemGreen, content: statusButton)
        let dueHorizontal = NSStackView(views: [dueButton, clearDueButton])
        dueHorizontal.spacing = 6
        dueHorizontal.alignment = .centerY
        let dueColumn = makeMetaColumn(title: "DUE", "calendar.circle.fill", orbColor, content: dueHorizontal)
        let priorityColumn = makeMetaColumn(title: "PRIORITY", "flag.fill", NSColor.systemOrange, content: priorityControl)
        
        metaRow.addArrangedSubview(statusColumn)
        metaRow.addArrangedSubview(dueColumn)
        metaRow.addArrangedSubview(priorityColumn)
    }
    
    private func configureNotesSection() {
        notesLabel.stringValue = "NOTES & CONTEXT"
        notesLabel.font = NSFont.systemFont(ofSize: 12, weight: .heavy)
        notesLabel.textColor = NSColor(calibratedWhite: 0.35, alpha: 0.9)
        notesLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(notesLabel)
        
        notesScrollView.translatesAutoresizingMaskIntoConstraints = false
        notesScrollView.borderType = .noBorder
        notesScrollView.drawsBackground = false
        notesScrollView.hasVerticalScroller = true
        notesScrollView.wantsLayer = true
        notesScrollView.layer?.cornerRadius = 18
        notesScrollView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
        notesScrollView.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        notesScrollView.layer?.borderWidth = 1.0
        notesScrollView.layer?.masksToBounds = true
        notesScrollView.heightAnchor.constraint(equalToConstant: 240).isActive = true
        
        notesTextView.backgroundColor = .clear
        notesTextView.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        notesTextView.textColor = NSColor(calibratedWhite: 0.12, alpha: 1.0)
        notesTextView.insertionPointColor = NSColor(calibratedWhite: 0.2, alpha: 1.0)
        notesTextView.isRichText = false
        notesTextView.isAutomaticQuoteSubstitutionEnabled = false
        notesTextView.isAutomaticSpellingCorrectionEnabled = false
        notesTextView.isAutomaticDataDetectionEnabled = true
        notesTextView.isHorizontallyResizable = false
        notesTextView.isVerticallyResizable = true
        notesTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        notesTextView.delegate = self
        notesTextView.string = task.details
        notesTextView.textContainerInset = NSSize(width: 14, height: 14)
        notesTextView.textContainer?.widthTracksTextView = true
        
        notesScrollView.documentView = notesTextView
        notesPlaceholder.font = NSFont.systemFont(ofSize: 14)
        notesPlaceholder.textColor = NSColor(calibratedWhite: 0.45, alpha: 0.9)
        notesPlaceholder.isBezeled = false
        notesPlaceholder.drawsBackground = false
        notesPlaceholder.isEditable = false
        notesPlaceholder.isSelectable = false
        notesPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        notesPlaceholder.lineBreakMode = .byWordWrapping
        notesPlaceholder.maximumNumberOfLines = 2
        notesTextView.addSubview(notesPlaceholder)
        NSLayoutConstraint.activate([
            notesPlaceholder.leadingAnchor.constraint(equalTo: notesTextView.leadingAnchor, constant: 18),
            notesPlaceholder.topAnchor.constraint(equalTo: notesTextView.topAnchor, constant: 16),
            notesPlaceholder.trailingAnchor.constraint(lessThanOrEqualTo: notesTextView.trailingAnchor, constant: -18)
        ])
        
        contentStack.addArrangedSubview(notesScrollView)
        notesScrollView.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor).isActive = true
        notesScrollView.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor).isActive = true
    }
    
    private func configureActionRow() {
        actionRow.orientation = .horizontal
        actionRow.alignment = .centerY
        actionRow.spacing = 14
        actionRow.translatesAutoresizingMaskIntoConstraints = false
        
        copyTitleButton.title = "Copy Title"
        copyTitleButton.bezelStyle = .inline
        copyTitleButton.isBordered = false
        copyTitleButton.target = self
        copyTitleButton.action = #selector(handleCopyTitle)
        copyTitleButton.contentTintColor = .white
        copyTitleButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy title")
        copyTitleButton.imagePosition = .imageLeading
        copyTitleButton.wantsLayer = true
        copyTitleButton.layer?.cornerRadius = 14
        copyTitleButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
        copyTitleButton.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        copyTitleButton.layer?.borderWidth = 1.0
        copyTitleButton.translatesAutoresizingMaskIntoConstraints = false
        copyTitleButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
        
        copyNotesButton.title = "Copy Notes"
        copyNotesButton.bezelStyle = .inline
        copyNotesButton.isBordered = false
        copyNotesButton.target = self
        copyNotesButton.action = #selector(handleCopyNotes)
        copyNotesButton.contentTintColor = .white
        copyNotesButton.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Copy notes")
        copyNotesButton.imagePosition = .imageLeading
        copyNotesButton.wantsLayer = true
        copyNotesButton.layer?.cornerRadius = 14
        copyNotesButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
        copyNotesButton.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        copyNotesButton.layer?.borderWidth = 1.0
        copyNotesButton.translatesAutoresizingMaskIntoConstraints = false
        copyNotesButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
        
        for button in [copyTitleButton, copyNotesButton] {
            button.layer?.backgroundColor = NSColor.clear.cgColor
            button.layer?.borderWidth = 0
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        }
        
        actionRow.addArrangedSubview(copyTitleButton)
        actionRow.addArrangedSubview(copyNotesButton)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        actionRow.addArrangedSubview(spacer)
        contentStack.addArrangedSubview(actionRow)
        actionRow.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor).isActive = true
        actionRow.trailingAnchor.constraint(lessThanOrEqualTo: contentStack.trailingAnchor).isActive = true
    }
    
    private func configureMetadataLabel() {
        metadataLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        metadataLabel.textColor = NSColor(calibratedWhite: 0.4, alpha: 0.9)
        metadataLabel.lineBreakMode = .byWordWrapping
        metadataLabel.maximumNumberOfLines = 2
        metadataLabel.alignment = .left
        metadataLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(metadataLabel)
        metadataLabel.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor).isActive = true
        metadataLabel.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor).isActive = true
    }
    
    private func makeMetaColumn(title: String, _ symbolName: String, _ tint: NSColor, content: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = NSColor.white.withAlphaComponent(0.55)
        label.alignment = .left

        content.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(content)
        return stack
    }
    
    private func createDatePopover() -> NSPopover {
        let popover = NSPopover()
        popover.behavior = .semitransient
        
        let controller = NSViewController()
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 16
        container.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let quickRow = NSStackView()
        quickRow.orientation = .horizontal
        quickRow.spacing = 12
        quickRow.alignment = .centerY
        quickRow.distribution = .fillEqually
        
        let todayButton = quickDueButton(title: "Today")
        todayButton.target = self
        todayButton.action = #selector(handleSetDueToday)
        
        let tomorrowButton = quickDueButton(title: "Tomorrow")
        tomorrowButton.target = self
        tomorrowButton.action = #selector(handleSetDueTomorrow)
        
        let nextWeekButton = quickDueButton(title: "Next Week")
        nextWeekButton.target = self
        nextWeekButton.action = #selector(handleSetDueNextWeek)
        
        quickRow.addArrangedSubview(todayButton)
        quickRow.addArrangedSubview(tomorrowButton)
        quickRow.addArrangedSubview(nextWeekButton)
        
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.datePickerElements = [.yearMonthDay, .hourMinute]
        datePicker.datePickerStyle = .clockAndCalendar
        datePicker.target = self
        datePicker.action = #selector(handleDatePicked)
        datePicker.font = NSFont.systemFont(ofSize: 13)
        
        let pickerContainer = NSView()
        pickerContainer.translatesAutoresizingMaskIntoConstraints = false
        pickerContainer.addSubview(datePicker)
        NSLayoutConstraint.activate([
            datePicker.leadingAnchor.constraint(equalTo: pickerContainer.leadingAnchor),
            datePicker.trailingAnchor.constraint(equalTo: pickerContainer.trailingAnchor),
            datePicker.topAnchor.constraint(equalTo: pickerContainer.topAnchor),
            datePicker.bottomAnchor.constraint(equalTo: pickerContainer.bottomAnchor)
        ])
        
        container.addArrangedSubview(quickRow)
        container.addArrangedSubview(pickerContainer)
        
        controller.view = NSView()
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(container)
        
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor),
            container.topAnchor.constraint(equalTo: controller.view.topAnchor),
            container.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor)
        ])
        
        controller.view.widthAnchor.constraint(equalToConstant: 300).isActive = true
        controller.view.heightAnchor.constraint(equalToConstant: 240).isActive = true
        
        popover.contentViewController = controller
        return popover
    }
    
    private func quickDueButton(title: String) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .inline
        button.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        button.isBordered = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        button.wantsLayer = true
        button.layer?.cornerRadius = 12
        button.layer?.backgroundColor = orbColor.withAlphaComponent(0.22).cgColor
        button.layer?.borderColor = orbColor.highlighted().withAlphaComponent(0.4).cgColor
        button.layer?.borderWidth = 1.0
        button.contentTintColor = .white
        return button
    }
    
    private func updateUI() {
        updateStatusButton()
        updateDueButton()
        updatePriorityControl()
        updateNotesPlaceholder()
        updateMetadataLabel()
        updateHeaderSubtitle()
        updateChromePalette()
        updateDragStripAppearance()
    }
    
    private func updateHeaderSubtitle() {
        var parts: [String] = []
        parts.append(task.isCompleted ? "Completed" : "Active")
        if let due = task.deadline {
            let relative = relativeFormatter.localizedString(for: due, relativeTo: Date())
            let absolute = dayFormatter.string(from: due)
            parts.append("\(relative.capitalized) • \(absolute)")
        } else {
            parts.append("No due date")
        }
        let priorityIndex = priorityIndex(for: task.priority)
        if priorityIndex >= 0 && priorityIndex < priorityLabels.count {
            parts.append("Priority \(priorityLabels[priorityIndex])")
        }
        headerSubtitleLabel.stringValue = parts.joined(separator: " · ")
    }
    
    private func updateStatusButton() {
        let isDone = task.isCompleted
        statusButton.title = isDone ? "Reopen Task" : "Mark Complete"
        statusButton.image = NSImage(systemSymbolName: isDone ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill", accessibilityDescription: nil)
        let background = isDone ? NSColor.systemGreen.withAlphaComponent(0.35) : NSColor.white.withAlphaComponent(0.18)
        statusButton.layer?.backgroundColor = background.cgColor
        statusButton.layer?.borderColor = NSColor.clear.cgColor
        statusButton.layer?.borderWidth = 0
        statusButton.contentTintColor = isDone ? NSColor.white : NSColor(calibratedWhite: 0.1, alpha: 0.95)
        updateHeaderSubtitle()
    }
    
    private func updateDueButton() {
        if let deadline = task.deadline {
            let relative = relativeFormatter.localizedString(for: deadline, relativeTo: Date())
            let absolute = dayFormatter.string(from: deadline)
            dueButton.title = "Due \(relative) • \(absolute)"
            dueButton.layer?.backgroundColor = orbColor.withAlphaComponent(0.22).cgColor
            dueButton.layer?.borderColor = NSColor.clear.cgColor
            dueButton.layer?.borderWidth = 0
            clearDueButton.isHidden = false
            clearDueButton.contentTintColor = NSColor.white.withAlphaComponent(0.7)
            dueButton.contentTintColor = NSColor.white
        } else {
            dueButton.title = "Set due date"
            dueButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
            dueButton.layer?.borderColor = NSColor.clear.cgColor
            dueButton.layer?.borderWidth = 0
            clearDueButton.isHidden = true
            dueButton.contentTintColor = NSColor(calibratedWhite: 0.1, alpha: 0.95)
        }
        updateHeaderSubtitle()
    }
    
    private func updatePriorityControl() {
        let index = priorityIndex(for: task.priority)
        applyPrioritySelection(index)
        updateHeaderSubtitle()
    }
    
    private func updateNotesPlaceholder() {
        let text = notesTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        notesPlaceholder.isHidden = !text.isEmpty
    }
    
    private func updateMetadataLabel() {
        var parts: [String] = []
        parts.append(task.isCompleted ? "Completed" : "In progress")
        if let due = task.deadline {
            parts.append("Due \(dateFormatter.string(from: due))")
        } else {
            parts.append("No due date")
        }
        let index = priorityControl.selectedSegment
        if index >= 0 && index < priorityLabels.count {
            parts.append("Priority \(priorityLabels[index])")
        }
        metadataLabel.stringValue = parts.joined(separator: "   •   ")
    }

    private func updateChromePalette() {
        let fill = glassBaseFill(for: orbColor)
        chromeLayer.colors = glassGradientStops(for: orbColor)
        chromeLayer.locations = [0.0, 0.55, 1.0]
        chromeLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
        chromeLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
        chromeLayer.backgroundColor = fill.cgColor
        backdropView.layer?.backgroundColor = fill.withAlphaComponent(0.03).cgColor
    }
    
    private func updateDragStripAppearance() {
        dragStripView.updatePrimaryColor(orbColor)
    }
    
    @objc private func handleCloseTapped() {
        guard !isClosing else { return }
        isClosing = true
        delegate?.closeTaskDetail(for: task.id)
    }
    
    @objc private func handleStatusToggle() {
        task.isCompleted.toggle()
        updateStatusButton()
        updateMetadataLabel()
    }
    
    @objc private func handleDueTapped() {
        guard let window = window else { return }
        if datePopover.isShown {
            datePopover.performClose(nil)
            return
        }
        datePicker.dateValue = task.deadline ?? Date()
        datePopover.show(relativeTo: dueButton.bounds, of: dueButton, preferredEdge: .maxY)
        window.makeFirstResponder(datePicker)
    }
    
    @objc private func handleClearDue() {
        task.deadline = nil
        datePopover.performClose(nil)
        updateDueButton()
        updateMetadataLabel()
    }
    
    @objc private func handlePriorityChanged() {
        let index = priorityControl.selectedSegment
        guard index >= 0 && index < priorityValues.count else { return }
        task.priority = priorityValues[index]
        updateMetadataLabel()
        updateHeaderSubtitle()
    }
    
    @objc private func handleDatePicked() {
        task.deadline = datePicker.dateValue
        updateDueButton()
        updateMetadataLabel()
    }
    
    @objc private func handleSetDueToday() {
        setDue(daysFromNow: 0)
    }
    
    @objc private func handleSetDueTomorrow() {
        setDue(daysFromNow: 1)
    }
    
    @objc private func handleSetDueNextWeek() {
        setDue(daysFromNow: 7)
    }
    
    private func setDue(daysFromNow: Int) {
        let calendar = Calendar.current
        let now = Date()
        if let date = calendar.date(byAdding: .day, value: daysFromNow, to: calendar.startOfDay(for: now)) {
            task.deadline = calendar.date(byAdding: .hour, value: 9, to: date)
            datePicker.dateValue = task.deadline ?? now
            updateDueButton()
            updateMetadataLabel()
            datePopover.performClose(nil)
        }
    }
    
    @objc private func handleCopyTitle() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(task.title, forType: .string)
    }
    
    @objc private func handleCopyNotes() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(task.details, forType: .string)
    }
    
    @objc private func handleTitleEditingEnd() {
        task.title = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if task.title.isEmpty {
            task.title = "Untitled Task"
            titleField.stringValue = task.title
        }
        updateMetadataLabel()
    }
    
    private func priorityIndex(for value: Int) -> Int {
        var bestIndex = 0
        var smallestDelta = Int.max
        for (index, candidate) in priorityValues.enumerated() {
            let delta = abs(candidate - value)
            if delta < smallestDelta {
                smallestDelta = delta
                bestIndex = index
            }
        }
        return bestIndex
    }
    
    private func applyPrioritySelection(_ index: Int) {
        for segment in 0..<priorityControl.segmentCount {
            priorityControl.setSelected(segment == index, forSegment: segment)
        }
    }
}

extension TaskDetailView {
    fileprivate func prepareForClose() {
        isClosing = true
        datePopover.performClose(nil)
        window?.makeFirstResponder(nil)
        notesTextView.delegate = nil
        titleField.delegate = nil
        titleField.target = nil
        statusButton.target = nil
        dueButton.target = nil
        clearDueButton.target = nil
        priorityControl.target = nil
        copyTitleButton.target = nil
        copyNotesButton.target = nil
        delegate = nil
    }
}

// MARK: - NSTextViewDelegate
extension TaskDetailView: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        guard notification.object as? NSTextView === notesTextView else {
            return
        }
        task.details = notesTextView.string
        updateNotesPlaceholder()
    }
}

// MARK: - NSTextFieldDelegate
extension TaskDetailView: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard obj.object as? NSTextField === titleField else { return }
        updateMetadataLabel()
    }
}

private final class NotesTextView: NSTextView {}

private final class PassthroughVisualEffectView: NSVisualEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private final class TaskDetailDragStripView: NSView {
    private let gradientLayer = CAGradientLayer()
    private let topBorder = CALayer()
    private let bottomBorder = CALayer()
    private var primaryColor: NSColor = .systemBlue
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    private func setupLayers() {
        wantsLayer = true
        layer?.masksToBounds = false
        
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.locations = [0.0, 0.55, 1.0] as [NSNumber]
        layer?.addSublayer(gradientLayer)
        
        topBorder.backgroundColor = NSColor.white.withAlphaComponent(0.35).cgColor
        bottomBorder.backgroundColor = NSColor.black.withAlphaComponent(0.08).cgColor
        layer?.addSublayer(topBorder)
        layer?.addSublayer(bottomBorder)
        
        updateAppearance()
    }
    
    override func layout() {
        super.layout()
        gradientLayer.frame = bounds
        topBorder.frame = CGRect(x: bounds.minX, y: bounds.maxY - 1, width: bounds.width, height: 1)
        bottomBorder.frame = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: 1)
    }
    
    override func mouseDown(with event: NSEvent) {
        NSCursor.closedHand.push()
        window?.performDrag(with: event)
        NSCursor.pop()
    }
    
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }
    
    func updatePrimaryColor(_ color: NSColor) {
        primaryColor = color
        updateAppearance()
    }
    
    private func updateAppearance() {
        gradientLayer.colors = glassGradientStops(for: primaryColor)
        gradientLayer.backgroundColor = glassBaseFill(for: primaryColor).cgColor
    }
}

// MARK: - TaskDetailWindow
class TaskDetailWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}
