import Cocoa
import SwiftUI
import QuartzCore

// MARK: - Project Orb Data Model
class ProjectOrb: ObservableObject, Identifiable {
    let id = UUID()
    let name: String
    let color: NSColor
    @Published var taskCount: Int = 0
    @Published var isVisible: Bool = false
    
    // Position around semi-circle rim
    @Published var angle: Double = 0.0 // In radians
    @Published var radius: Double = 0.0 // Distance from center
    @Published var scale: Double = 1.0 // Scale factor for sizing
    
    init(name: String, color: NSColor) {
        self.name = name
        self.color = color
    }
    
    func addTask() {
        taskCount += 1
    }
    
    func removeTask() {
        taskCount = max(0, taskCount - 1)
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
}

// MARK: - Orb Manager
class OrbManager: ObservableObject {
    @Published var orbs: [ProjectOrb] = []
    @Published var isVisible: Bool = false
    
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
        let color = OrbColorPalette.getColor(for: name)
        let orb = ProjectOrb(name: name, color: color)
        
        // Add orb and update positions without animation (we're not in SwiftUI context)
        orbs.append(orb)
        updateOrbPositions()
        
        print("🎯 Created orb '\(name)' - total orbs: \(orbs.count)")
        print("🎯 Orb details: name=\(orb.name), color=\(orb.color), visible=\(orb.isVisible)")
        return orb
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
        print("🎯 showOrbs() called - setting isVisible to true")
        isVisible = true
        for orb in orbs {
            orb.isVisible = true
        }
    }
    
    func hideOrbs() {
        isVisible = false
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
    private var isVisible = false
    var isSemiCircleVisible = false // Added
    private var orbManager = OrbManager()

    
    @Published var isVerticallyExpanding = false
    
    init() {
        setupOverlayWindow()
        setupNotchIndicator()
        setupSemiCircle()
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
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]
            window.isMovable = false
            
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
            // If semi-circle is already visible, just show the orbs
            print("🎯 Semi-circle already visible, just showing orbs")
            orbManager.showOrbs()
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
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovable = false
        
        // Create semi-circle view with orbs
        let semiCircleView = SemiCircleWithOrbsView(orbManager: orbManager)
        window.contentView = semiCircleView
        
        self.semiCircleWindow = window
        self.semiCircleView = semiCircleView // Store reference
        positionSemiCircle(window)
    }
    
    private func positionSemiCircle(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.frame
        let notchInfo = getNotchInfo(for: screen)
        
        // Position semi-circle further down, showing only bottom portion
        let x = screenFrame.midX - window.frame.width / 2
        let y = screenFrame.maxY - notchInfo.height - window.frame.height + 48 // 4 pixels further down
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    private func showSemiCircle() {
        guard let window = semiCircleWindow else { return }
        
        // Start with semi-circle hidden and scaled down from center top
        let finalFrame = window.frame
        let centerTopX = finalFrame.midX
        let centerTopY = finalFrame.maxY
        
        // Start with tiny frame at center top
        let startFrame = NSRect(x: centerTopX - 5, y: centerTopY - 5, width: 10, height: 10)
        window.setFrame(startFrame, display: false)
        window.alphaValue = 0.0
        window.makeKeyAndOrderFront(nil)
        
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
                self.orbManager.showOrbs()
                // Force redraw of the semi-circle view
                self.semiCircleView?.needsDisplay = true
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
        private var animationTimer: Timer?
        private var animationPhase: Double = 0.0
        
        init(orbManager: OrbManager) {
            self.orbManager = orbManager
            super.init(frame: NSRect.zero)
            startAnimation()
        }
    
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            animationTimer?.invalidate()
        }
        
        private func startAnimation() {
            animationTimer?.invalidate()
            animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.animationPhase += 0.05
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
            print("🎯 Orb \(index): visible=\(orb.isVisible), angle=\(orb.angle), scale=\(orb.scale)")
            
            guard orb.isVisible else { continue }
            
            let x = centerX + radius * cos(orb.angle)
            let y = centerY + radius * sin(orb.angle)
            let size = 40.0 * orb.scale
            
            print("🎯 Drawing orb at (\(x), \(y)) with size \(size)")
            
            // Create modern, dynamic orb with multiple layers
            drawModernOrb(context: context, x: x, y: y, size: size, color: orb.color, taskCount: orb.taskCount, scale: orb.scale, animationPhase: animationPhase, orbIndex: index)
        }
    }
    
    private func drawModernOrb(context: CGContext, x: Double, y: Double, size: Double, color: NSColor, taskCount: Int, scale: Double, animationPhase: Double, orbIndex: Int) {
        // Calculate gentle, evolving effects based on animation phase and orb index
        let orbPhase = animationPhase + Double(orbIndex) * 0.3 // Offset each orb's animation
        
        // Create unique random paths for each orb's highlight movement
        let randomSeed1 = Double(orbIndex) * 2.3 + 1.7 // Unique seed for each orb
        let randomSeed2 = Double(orbIndex) * 1.9 + 3.1 // Different seed for Y movement
        let randomSeed3 = Double(orbIndex) * 0.8 + 2.5 // Speed variation seed
        
        let gentleRotation = orbPhase * 0.1 // Very slow, gentle rotation
        let internalFlow = sin(orbPhase * 0.15) * 0.05 // Slower, more noticeable internal movement
        let colorShift = sin(orbPhase * 0.2) * 0.1 // Gentle color evolution
        
        let orbRect = CGRect(x: x - size/2, y: y - size/2, width: size, height: size)
        
        // Create evolving gradient for the orb with gentle color shifts
        let evolvedColor = NSColor(
            red: min(1.0, color.redComponent + colorShift),
            green: min(1.0, color.greenComponent + colorShift * 0.5),
            blue: min(1.0, color.blueComponent + colorShift * 0.3),
            alpha: color.alphaComponent
        )
        
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: [
                                    evolvedColor.withAlphaComponent(0.9).cgColor,
                                    evolvedColor.withAlphaComponent(0.7).cgColor,
                                    evolvedColor.withAlphaComponent(0.5).cgColor
                                ] as CFArray,
                                locations: [0.0, 0.6, 1.0])!
        
        // 1. Outer glow - gentle, evolving atmosphere
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 0), blur: 25, color: evolvedColor.withAlphaComponent(0.4).cgColor)
        context.setFillColor(evolvedColor.withAlphaComponent(0.3).cgColor)
        context.addEllipse(in: orbRect.insetBy(dx: -8, dy: -8))
        context.fillPath()
        context.restoreGState()
        
        // 2. Mid-range glow - subtle evolution
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 0), blur: 15, color: evolvedColor.withAlphaComponent(0.5).cgColor)
        context.setFillColor(evolvedColor.withAlphaComponent(0.4).cgColor)
        context.addEllipse(in: orbRect.insetBy(dx: -4, dy: -4))
        context.fillPath()
        context.restoreGState()
        
        // 3. Main orb with evolving gradient and gentle rotation
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 6), blur: 12, color: evolvedColor.withAlphaComponent(0.6).cgColor)
        context.addEllipse(in: orbRect)
        context.clip()
        
        // Apply gentle rotation to the gradient
        context.translateBy(x: orbRect.midX, y: orbRect.midY)
        context.rotate(by: gentleRotation)
        context.translateBy(x: -orbRect.midX, y: -orbRect.midY)
        
        context.drawLinearGradient(gradient,
                                 start: CGPoint(x: orbRect.minX, y: orbRect.minY),
                                 end: CGPoint(x: orbRect.maxX, y: orbRect.maxY),
                                 options: [])
        context.restoreGState()
        
        // 4. Internal flowing highlight for 3D effect
        let highlightRect = orbRect.insetBy(dx: size * 0.15, dy: size * 0.15)
        let highlightGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: [
                                            NSColor.white.withAlphaComponent(0.6).cgColor,
                                            NSColor.white.withAlphaComponent(0.1).cgColor,
                                            NSColor.clear.cgColor
                                         ] as CFArray,
                                         locations: [0.0, 0.5, 1.0])!
        
        context.saveGState()
        context.addEllipse(in: highlightRect)
        context.clip()
        
        // Apply unique random circular flow movement to highlight for each orb
        let flowRadius = size * (0.15 + sin(randomSeed1) * 0.08) // Varying radius per orb
        let flowSpeed = 0.25 + sin(randomSeed3) * 0.12 // Varying speed per orb (even quicker)
        let flowX = cos(orbPhase * flowSpeed + randomSeed1) * flowRadius // Unique X movement
        let flowY = sin(orbPhase * flowSpeed + randomSeed2) * flowRadius // Unique Y movement
        
        context.drawRadialGradient(highlightGradient,
                                 startCenter: CGPoint(x: highlightRect.midX - size * 0.1 + flowX, y: highlightRect.midY - size * 0.1 + flowY),
                                 startRadius: 0,
                                 endCenter: CGPoint(x: highlightRect.midX + flowX, y: highlightRect.midY + flowY),
                                 endRadius: highlightRect.width / 2,
                                 options: [])
        context.restoreGState()
        
        // 5. Gentle internal energy rings
        for i in 0..<2 {
            let ringPhase = orbPhase + Double(i) * 1.5
            let ringSize = size * (1.1 + sin(ringPhase * 0.4) * 0.05) // Very subtle size variation
            let ringRect = CGRect(x: x - ringSize/2, y: y - ringSize/2, width: ringSize, height: ringSize)
            
            context.saveGState()
            let ringAlpha = 0.15 + sin(ringPhase * 0.6) * 0.05 // Gentle alpha variation
            context.setStrokeColor(evolvedColor.withAlphaComponent(ringAlpha).cgColor)
            context.setLineWidth(1.0)
            context.addEllipse(in: ringRect)
            context.strokePath()
            context.restoreGState()
        }
        
        // 6. Internal flowing energy particles
        for i in 0..<4 {
            let particlePhase = orbPhase + Double(i) * 1.2
            let particleRadius = size * 0.3 + sin(particlePhase * 0.8) * size * 0.1
            let particleX = x + cos(particlePhase * 0.5) * particleRadius
            let particleY = y + sin(particlePhase * 0.5) * particleRadius
            let particleSize = 1.5 + sin(particlePhase * 1.2) * 0.5
            let particleAlpha = 0.3 + sin(particlePhase * 0.9) * 0.2
            
            context.saveGState()
            context.setFillColor(evolvedColor.withAlphaComponent(particleAlpha).cgColor)
            context.addEllipse(in: CGRect(x: particleX - particleSize/2, y: particleY - particleSize/2, width: particleSize, height: particleSize))
            context.fillPath()
            context.restoreGState()
        }
        
        // 7. Task count badge with gentle evolution
        if taskCount > 0 {
            let badgeSize = 18.0 * scale
            let badgeRect = CGRect(x: x + size/3, y: y - size/3, width: badgeSize, height: badgeSize)
            
            // Badge background with gradient
            let badgeGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: [
                                            NSColor.black.withAlphaComponent(0.9).cgColor,
                                            NSColor.black.withAlphaComponent(0.7).cgColor
                                         ] as CFArray,
                                         locations: [0.0, 1.0])!
            
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: NSColor.black.withAlphaComponent(0.5).cgColor)
            context.addEllipse(in: badgeRect)
            context.clip()
            context.drawLinearGradient(badgeGradient,
                                     start: CGPoint(x: badgeRect.minX, y: badgeRect.minY),
                                     end: CGPoint(x: badgeRect.maxX, y: badgeRect.maxY),
                                     options: [])
            context.restoreGState()
            
            // Badge text with modern font
            let text = "\(taskCount)" as NSString
            let font = NSFont.systemFont(ofSize: 10 * scale, weight: .bold)
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
