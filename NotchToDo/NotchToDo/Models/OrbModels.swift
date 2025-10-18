import Cocoa

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
        var physicsDamping: Double = 0.92 // Higher damping for softer settles
        var physicsStiffness: Double = 0.68 // Slightly gentler spring for floaty feel
        var physicsMass: Double = 0.14 // A touch heavier for smoother inertia
        var maxDisplacement: Double = 22.0 // Allow a little more travel for wobble
        var springTargetDisplacement: CGPoint = .zero // Desired displacement driven by mouse attraction
        var hoverVerticalOffset: CGFloat = 0.0 // Subtle bobbing offset applied on top of physics
        private let hoverPhaseOffset: Double
        private let hoverSpeedMultiplier: Double
        private let hoverAmplitude: CGFloat
        var badgePulse: Double = 0.0
        var badgePulseDirection: Double = 1.0
        var badgeRipplePhase: Double = 0.0
        private var lastRecordedTaskCount: Int = 0
        var bubbleInfluence: CGFloat = 0.0
    
    init(name: String, color: NSColor) {
        self.name = name
        self.color = color
        self.hoverPhaseOffset = Double.random(in: 0...(Double.pi * 2.0))
        self.hoverSpeedMultiplier = Double.random(in: 0.32...0.55)
        self.hoverAmplitude = CGFloat.random(in: 1.5...3.0)
    }
    
    func addTask() {
        addTask(title: "New Task \(tasks.count + 1)")
    }
    
    func addTask(title: String) {
        let task = Task(title: title)
        tasks.append(task)
        taskCount = tasks.count
        registerTaskCountChange(newValue: taskCount)
        DebugLog.log("Added task to \(name): taskCount now \(taskCount), tasks.count = \(tasks.count)", category: .tasks)
        DebugLog.log("Tasks in \(name): \(tasks.map { $0.title })", category: .tasks)
    }
    
    func removeTask() {
        if !tasks.isEmpty {
            tasks.removeLast()
            taskCount = tasks.count
            registerTaskCountChange(newValue: taskCount)
        }
    }
    
    func syncTaskCount() {
        let oldCount = taskCount
        taskCount = tasks.count
        if oldCount != taskCount {
            registerTaskCountChange(newValue: taskCount)
            DebugLog.log("Synced task count for \(name): \(oldCount) -> \(taskCount) (tasks.count = \(tasks.count))", category: .tasks)
        }
    }
    
    private func registerTaskCountChange(newValue: Int) {
        let delta = newValue - lastRecordedTaskCount
        guard delta != 0 else { return }
        badgePulse = min(1.2, badgePulse + 1.0)
        badgePulseDirection = delta >= 0 ? 1.0 : -1.0
        badgeRipplePhase = 0.0
        lastRecordedTaskCount = newValue
    }
    
    // MARK: - Physics Methods
    
    /// Apply an impulse force to the orb (like a gentle tap)
    func applyImpulse(_ force: CGPoint) {
        physicsVelocity.x += force.x / physicsMass
        physicsVelocity.y += force.y / physicsMass
        isPhysicsActive = true
    }

    func setSpringTarget(_ target: CGPoint, immediate: Bool = false) {
        var clamped = target
        let magnitude = sqrt(clamped.x * clamped.x + clamped.y * clamped.y)
        if magnitude > maxDisplacement {
            let scale = maxDisplacement / magnitude
            clamped.x *= scale
            clamped.y *= scale
        }

        springTargetDisplacement = clamped
        if immediate {
            physicsDisplacement = clamped
            physicsVelocity = .zero
            physicsAcceleration = .zero
        }
        isPhysicsActive = true
    }
    
    /// Update physics simulation for one frame
    func updatePhysics(deltaTime: Double) {
        let target = springTargetDisplacement
        let dx = physicsDisplacement.x - target.x
        let dy = physicsDisplacement.y - target.y
        let distanceToTarget = sqrt(dx * dx + dy * dy)
        
        if !isPhysicsActive && distanceToTarget < 0.01 {
            return
        }
        
        isPhysicsActive = true

        let springForceStrength = max(distanceToTarget * physicsStiffness, 2.0)
        let normalizedX = distanceToTarget > 0.0001 ? dx / distanceToTarget : 0.0
        let normalizedY = distanceToTarget > 0.0001 ? dy / distanceToTarget : 0.0
        
        let springForce = CGPoint(
            x: -normalizedX * springForceStrength,
            y: -normalizedY * springForceStrength
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

        // Apply gentle resistance when moving far from center, regardless of target
        let totalDisplacementMagnitude = sqrt(physicsDisplacement.x * physicsDisplacement.x + physicsDisplacement.y * physicsDisplacement.y)
        
        // Debug print every 30 frames (0.5 seconds at 60fps)
        if Int.random(in: 0...1799) < 1 { // Very infrequent debug
            DebugLog.log("Physics Debug - Orb \(name): displacement=(\(String(format: "%.1f", physicsDisplacement.x)), \(String(format: "%.1f", physicsDisplacement.y))), velocity=(\(String(format: "%.1f", physicsVelocity.x)), \(String(format: "%.1f", physicsVelocity.y))), springForce=(\(String(format: "%.1f", springForce.x)), \(String(format: "%.1f", springForce.y)))", category: .physics)
        }
        
        // Completely soft constraint zone - no hard stops, only gradual resistance
        let softZoneStart = maxDisplacement * 0.4 // Start slowing down at 40% of max distance (8 points out of 20)
        if totalDisplacementMagnitude > softZoneStart {
            let softZoneRatio = min((totalDisplacementMagnitude - softZoneStart) / (maxDisplacement - softZoneStart), 1.0) // Clamp to 1.0
            
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
        
        if velocityMagnitude < 0.1 && distanceToTarget < 0.1 {
            // Orb has come to rest
            physicsDisplacement = springTargetDisplacement
            physicsVelocity = CGPoint.zero
            physicsAcceleration = CGPoint.zero
            if springTargetDisplacement == .zero {
                isPhysicsActive = false
            }
            DebugLog.log("Orb \(name) has come to rest", category: .physics)
        }
    }
    
    func updateHover(deltaTime: CFTimeInterval) {
        // Calculate a smooth sinusoidal offset with per-orb variance
        let phase = animationPhase * hoverSpeedMultiplier + hoverPhaseOffset
        let dynamicAmplitude = hoverAmplitude + bubbleInfluence * 1.6
        let targetOffset = CGFloat(sin(phase)) * dynamicAmplitude
        let smoothing = min(1.0, deltaTime * 2.8)
        let offsetDifference = targetOffset - hoverVerticalOffset
        hoverVerticalOffset += offsetDifference * CGFloat(smoothing)
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

extension NSColor {
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
            
            DebugLog.log("Created orb \(name) - total orbs: \(orbs.count)", category: .overlay)
            DebugLog.log("Orb details: name=\(orb.name), color=\(orb.color), visible=\(orb.isVisible)", category: .overlay)
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
        func showOrbs(completion: (() -> Void)? = nil) {
            DebugLog.log("showOrbs() called - starting staggered orb appearance", category: .overlay)
            isVisible = true
            
            guard !orbs.isEmpty else {
                visibleOrbCount = 0
                completion?()
                return
            }
            
            let alreadyVisible = orbs.filter { $0.isVisible }
            let hiddenEntries = orbs.enumerated().filter { !$0.element.isVisible }
            
            visibleOrbCount = alreadyVisible.count
            DebugLog.log("Currently visible orbs: \(visibleOrbCount), hidden orbs: \(hiddenEntries.count)", category: .overlay)
            
            // If everything is already visible (e.g. reposition after adding a project), just ensure full scale and bail.
            guard !hiddenEntries.isEmpty else {
                for orb in orbs {
                    orb.isVisible = true
                    orb.animationScale = max(orb.animationScale, 1.0)
                }
                completion?()
                return
            }
            
            // Prepare hidden orbs for intro animation without disturbing the visible ones.
            for (_, orb) in hiddenEntries {
                orb.isVisible = false
                orb.animationScale = 0.0
            }
            
            for (revealIndex, entry) in hiddenEntries.enumerated() {
                let (absoluteIndex, orb) = entry
                let delay = Double(revealIndex) * 0.3
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    orb.isVisible = true
                    self.visibleOrbCount += 1
                    DebugLog.log("Orb \(absoluteIndex) appeared - visible count: \(self.visibleOrbCount)", category: .overlay)
                    self.animateOrbGrowth(orb: orb, duration: 0.6)
                    
                    if revealIndex == hiddenEntries.count - 1 {
                        let settleDelay = 0.6
                        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay) {
                            completion?()
                        }
                    }
                }
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
