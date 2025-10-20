import QuartzCore
import Cocoa


class NotchIndicatorView: NSView {
    var notchInfo: (width: CGFloat, height: CGFloat, centerX: CGFloat, safeAreaTop: CGFloat) = (272, 25, 0, 0)
    private var displayProgress: CGFloat = 0.0
    private var targetProgress: CGFloat = 0.0
    private var hasCompletedSweep = false
    private var progressAnimationTimer: Timer?
    private var glowIntensity: CGFloat = 0.0
    private var isPerformingSweep = false
    private var listenState: ListenState = .idle
    
    // Contextual animation properties
    var activeOrbColor: NSColor?
    var projectProgress: CGFloat = 0.0  // 0.0 to 1.0
    
    static var contextualAnimationsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "ContextualNotchAnimationsEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "ContextualNotchAnimationsEnabled") }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    deinit {
        progressAnimationTimer?.invalidate()
    }
    
    func resetAndStartTrace(completion: (() -> Void)? = nil) {
        progressAnimationTimer?.invalidate()
        displayProgress = 0.0
        targetProgress = 1.0
        isPerformingSweep = true
        hasCompletedSweep = false
        animateProgress(to: 1.0, duration: 0.6) { [weak self] in
            guard let self else { return }
            self.isPerformingSweep = false
            self.displayProgress = self.targetProgress
            self.needsDisplay = true
            self.hasCompletedSweep = true
            completion?()
        }
    }
    
    func update(for state: ListenState) {
        listenState = state
        targetProgress = progress(for: state)
        glowIntensity = glow(for: state)
        
        if hasCompletedSweep {
            displayProgress = 1.0
        } else if !isPerformingSweep {
            animateProgress(to: targetProgress, duration: 0.35)
        }
        needsDisplay = true
    }
    
    func updateContext(orbColor: NSColor?, progress: CGFloat) {
        guard NotchIndicatorView.contextualAnimationsEnabled else { return }
        
        let colorChanged = activeOrbColor != orbColor
        activeOrbColor = orbColor
        projectProgress = min(max(progress, 0.0), 1.0)
        
        // Smoothly update glow if context changed
        if colorChanged {
            glowIntensity = glow(for: listenState)
        }
        
        needsDisplay = true
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
        
        // Create the notch path
        let path = NSBezierPath(roundedRect: notchRect, xRadius: cornerRadius, yRadius: cornerRadius)
        let cgPath = convertNSBezierPathToCGPath(path)
        
        // Draw the notch rectangle with manual dimensions FIRST (background)
        context.saveGState()
        context.setFillColor(NSColor.clear.cgColor)
        context.addPath(cgPath)
        context.fillPath()
        context.restoreGState()
        
        // Subtle base outline
        context.saveGState()
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.12).cgColor)
        context.setLineWidth(1.0)
        context.addPath(cgPath)
        context.strokePath()
        context.restoreGState()
        
        // Draw shining white trace around the notch perimeter SECOND (on top)
        drawShiningTrace(context: context, notchRect: notchRect, cornerRadius: cornerRadius)
    }
    
    private func drawShiningTrace(context: CGContext, notchRect: NSRect, cornerRadius: CGFloat) {
        // Calculate perimeter for tracing around the yellow box edge
        let perimeter = 2 * (notchRect.width + notchRect.height) - 8 * cornerRadius + 2 * .pi * cornerRadius
        let topLinearLength = notchRect.width - 2 * cornerRadius
        let startOffset = topLinearLength / 2 // top center reference point
        let sweepProgress = min(max(displayProgress, 0.0), 1.0)
        let travelDistance = min(max(sweepProgress * perimeter, 0), perimeter)
        guard travelDistance > 0.001 else { return }
        
        let segmentLength = min(max(perimeter * 0.1, 42), travelDistance)
        let headPath = createPerimeterTrace(
            notchRect: notchRect,
            cornerRadius: cornerRadius,
            startPosition: startOffset - travelDistance,
            traceLength: segmentLength
        )
        
        // Draw the shining trace with a state-aware glow
        context.saveGState()
        
        let baseColor = traceColor(for: listenState)
        let outerGlowColor = baseColor.blended(withFraction: 0.5, of: .white) ?? baseColor
        let midGlowColor = baseColor
        let intensity = max(glowIntensity, 0.05)

        // Outer halo
        context.setShadow(offset: .zero, blur: 58 * intensity, color: outerGlowColor.withAlphaComponent(0.32 * intensity).cgColor)
        context.setStrokeColor(baseColor.withAlphaComponent(0.52 * intensity + 0.2).cgColor)
        context.setLineWidth(4.6)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addPath(convertNSBezierPathToCGPath(headPath))
        context.strokePath()
        
        // Mid halo
        context.setShadow(offset: .zero, blur: 26 * intensity, color: midGlowColor.withAlphaComponent(0.48 * intensity + 0.1).cgColor)
        context.setStrokeColor(midGlowColor.withAlphaComponent(0.72 * intensity + 0.2).cgColor)
        context.setLineWidth(3.0)
        context.addPath(convertNSBezierPathToCGPath(headPath))
        context.strokePath()
        
        // Core bright sweep
        context.setShadow(offset: .zero, blur: 16 * intensity, color: NSColor.white.withAlphaComponent(0.75 * intensity).cgColor)
        context.setStrokeColor(NSColor.white.withAlphaComponent(1.05 * intensity + 0.28).cgColor)
        context.setLineWidth(2.2)
        context.addPath(convertNSBezierPathToCGPath(headPath))
        context.strokePath()
        
        context.restoreGState()
    }
    
    private func traceColor(for state: ListenState) -> NSColor {
        // Use contextual color if enabled and available
        if NotchIndicatorView.contextualAnimationsEnabled, state == .idle, let orbColor = activeOrbColor {
            // Blend orb color with progress intensity
            let progressIntensity = 0.3 + (projectProgress * 0.5)  // Range: 0.3 to 0.8
            return orbColor.withAlphaComponent(progressIntensity)
        }
        
        // Default state-based colors
        switch state {
        case .idle:
            return NSColor.systemTeal.withAlphaComponent(0.4)
        case .wake:
            return NSColor.systemOrange
        case .listening:
            return NSColor.systemGreen
        case .transcribing:
            return NSColor.systemBlue
        case .error:
            return NSColor.systemRed
        }
    }
    
    private func progress(for state: ListenState) -> CGFloat {
        switch state {
        case .idle:
            return 0.0
        case .wake:
            return 0.3
        case .listening:
            return 0.6
        case .transcribing:
            return 0.9
        case .error:
            return 1.0
        }
    }

    private func glow(for state: ListenState) -> CGFloat {
        let baseGlow: CGFloat
        switch state {
        case .idle:
            baseGlow = 0.35
        case .wake:
            baseGlow = 0.6
        case .listening:
            baseGlow = 0.8
        case .transcribing:
            baseGlow = 0.9
        case .error:
            baseGlow = 1.0
        }
        
        // Enhance glow based on project progress when contextual animations are enabled
        if NotchIndicatorView.contextualAnimationsEnabled, state == .idle, activeOrbColor != nil {
            // Boost glow intensity as project nears completion
            let progressBoost = projectProgress * 0.3  // Up to +0.3 intensity
            return min(baseGlow + progressBoost, 1.0)
        }
        
        return baseGlow
    }
    
    private func animateProgress(to value: CGFloat, duration: TimeInterval, completion: (() -> Void)? = nil) {
        progressAnimationTimer?.invalidate()
        
        let startValue = displayProgress
        let delta = value - startValue
        guard abs(delta) > 0.0001, duration > 0 else {
            displayProgress = value
            needsDisplay = true
            completion?()
            return
        }
        
        let startTime = CACurrentMediaTime()
        progressAnimationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            
            let elapsed = CACurrentMediaTime() - startTime
            let progress = min(elapsed / duration, 1.0)
            let eased = 1.0 - pow(1.0 - progress, 3.0)
            self.displayProgress = startValue + delta * CGFloat(eased)
            self.needsDisplay = true
            
            if progress >= 1.0 {
                timer.invalidate()
                self.progressAnimationTimer = nil
                self.displayProgress = value
                self.needsDisplay = true
                completion?()
            }
        }
    }
    
    private func createPerimeterTrace(notchRect: NSRect, cornerRadius: CGFloat, startPosition: CGFloat, traceLength: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        let perimeter = 2 * (notchRect.width + notchRect.height) - 8 * cornerRadius + 2 * .pi * cornerRadius
        let clampedLength = max(0, min(traceLength, perimeter))
        guard clampedLength > 0 else { return path }

        var start = startPosition
        while start < 0 { start += perimeter }
        start.formTruncatingRemainder(dividingBy: perimeter)

        let steps = max(2, Int(ceil(clampedLength / 6)))
        path.move(to: point(on: notchRect, cornerRadius: cornerRadius, distance: start))

        for step in 1...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            var distance = start + progress * clampedLength
            distance.formTruncatingRemainder(dividingBy: perimeter)
            path.line(to: point(on: notchRect, cornerRadius: cornerRadius, distance: distance))
        }

        return path
    }

    private func point(on rect: NSRect, cornerRadius: CGFloat, distance: CGFloat) -> NSPoint {
        let topWidth = rect.width - 2 * cornerRadius
        let sideHeight = rect.height - 2 * cornerRadius
        let cornerArc = .pi * cornerRadius / 2
        let perimeter = 2 * (rect.width + rect.height) - 8 * cornerRadius + 2 * .pi * cornerRadius

        var d = distance
        while d < 0 { d += perimeter }
        d.formTruncatingRemainder(dividingBy: perimeter)

        switch d {
        case 0..<topWidth:
            return NSPoint(x: rect.minX + cornerRadius + d, y: rect.maxY)
        case topWidth..<(topWidth + cornerArc):
            let t = (d - topWidth) / cornerArc
            let angle = t * (.pi / 2)
            return NSPoint(x: rect.maxX - cornerRadius + cornerRadius * cos(angle),
                          y: rect.maxY - cornerRadius + cornerRadius * sin(angle))
        case (topWidth + cornerArc)..<(topWidth + cornerArc + sideHeight):
            let offset = d - topWidth - cornerArc
            return NSPoint(x: rect.maxX, y: rect.maxY - cornerRadius - offset)
        case (topWidth + cornerArc + sideHeight)..<(topWidth + 2 * cornerArc + sideHeight):
            let t = (d - topWidth - sideHeight - cornerArc) / cornerArc
            let angle = (.pi / 2) + t * (.pi / 2)
            return NSPoint(x: rect.maxX - cornerRadius + cornerRadius * cos(angle),
                          y: rect.minY + cornerRadius + cornerRadius * sin(angle))
        case (topWidth + 2 * cornerArc + sideHeight)..<(2 * topWidth + 2 * cornerArc + sideHeight):
            let offset = d - (topWidth + 2 * cornerArc + sideHeight)
            return NSPoint(x: rect.maxX - cornerRadius - offset, y: rect.minY)
        case (2 * topWidth + 2 * cornerArc + sideHeight)..<(2 * (topWidth + cornerArc) + sideHeight):
            let t = (d - (2 * topWidth + 2 * cornerArc + sideHeight)) / cornerArc
            let angle = .pi + t * (.pi / 2)
            return NSPoint(x: rect.minX + cornerRadius + cornerRadius * cos(angle),
                          y: rect.minY + cornerRadius + cornerRadius * sin(angle))
        case (2 * (topWidth + cornerArc) + sideHeight)..<(2 * (topWidth + cornerArc) + 2 * sideHeight):
            let offset = d - (2 * (topWidth + cornerArc) + sideHeight)
            return NSPoint(x: rect.minX, y: rect.minY + cornerRadius + offset)
        default:
            let offset = d - (2 * (topWidth + cornerArc) + 2 * sideHeight)
            let t = offset / cornerArc
            let angle = (3 * .pi / 2) + t * (.pi / 2)
            return NSPoint(x: rect.minX + cornerRadius + cornerRadius * cos(angle),
                          y: rect.maxY - cornerRadius + cornerRadius * sin(angle))
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
