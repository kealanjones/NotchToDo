import AppKit
import QuartzCore

class SpeechCaptureBubbleView: NSView {
    private let bubbleLayer = CALayer()
    private let backgroundGradient = CAGradientLayer()
    private let glossGradient = CAGradientLayer()
    private let borderLayer = CAShapeLayer()
    private let entranceRippleLayer = CAShapeLayer()
    private let finalizePulseLayer = CAShapeLayer()
    private let finalizeTrailLayer = CAReplicatorLayer()
    private let finalizeTrailDot = CALayer()
    private let transcriptField: NSTextField
    private let statusField: NSTextField
    private let thinkingDotsLayer = CALayer()
    
    private var isThinking = false
    private var glowColor: NSColor?
    private var isClarificationMode = false
    private var finalizeEffectInFlight = false
    private var finalizePath: CGPath?
    private var finalizeTrailStart: CGPoint = .zero
    private var finalizeTrailEnd: CGPoint = .zero
    private var finalizeTrailPath: CGPath?
    
    override init(frame frameRect: NSRect) {
        transcriptField = NSTextField(labelWithString: "")
        statusField = NSTextField(labelWithString: "")
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        setupLayers()
        setupLabels()
        resetForNewCapture()
    }
    
    required init?(coder: NSCoder) {
        transcriptField = NSTextField(labelWithString: "")
        statusField = NSTextField(labelWithString: "")
        super.init(coder: coder)
        wantsLayer = true
        layer?.masksToBounds = false
        setupLayers()
        setupLabels()
        resetForNewCapture()
    }
    
    private func setupLayers() {
        bubbleLayer.masksToBounds = true
        bubbleLayer.cornerRadius = 18
        bubbleLayer.borderWidth = 0
        bubbleLayer.shadowOpacity = 0
        
        backgroundGradient.startPoint = CGPoint(x: 0.2, y: 0)
        backgroundGradient.endPoint = CGPoint(x: 0.8, y: 1)
        backgroundGradient.colors = [
            NSColor(calibratedWhite: 0.08, alpha: 0.86).cgColor,
            NSColor(calibratedWhite: 0.2, alpha: 0.9).cgColor
        ]
        
        glossGradient.startPoint = CGPoint(x: 0.2, y: 1.0)
        glossGradient.endPoint = CGPoint(x: 0.8, y: 0.0)
        glossGradient.colors = [
            NSColor.white.withAlphaComponent(0.18).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor
        ]
        glossGradient.locations = [0.0, 1.0]
        
        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.strokeColor = NSColor.white.withAlphaComponent(0.18).cgColor
        borderLayer.lineWidth = 1.0
        
        bubbleLayer.addSublayer(backgroundGradient)
        bubbleLayer.addSublayer(glossGradient)
        bubbleLayer.addSublayer(borderLayer)
        
        entranceRippleLayer.fillColor = NSColor.white.withAlphaComponent(0.08).cgColor
        entranceRippleLayer.strokeColor = NSColor.white.withAlphaComponent(0.22).cgColor
        entranceRippleLayer.lineWidth = 1.0
        entranceRippleLayer.opacity = 0.0
        bubbleLayer.addSublayer(entranceRippleLayer)
        
        finalizePulseLayer.fillColor = NSColor.white.withAlphaComponent(0.12).cgColor
        finalizePulseLayer.strokeColor = NSColor.white.withAlphaComponent(0.35).cgColor
        finalizePulseLayer.lineWidth = 1.0
        finalizePulseLayer.opacity = 0.0
        bubbleLayer.addSublayer(finalizePulseLayer)
        
        finalizeTrailLayer.opacity = 0.0
        finalizeTrailLayer.instanceCount = 6
        finalizeTrailLayer.instanceDelay = 0.055
        finalizeTrailLayer.instanceAlphaOffset = Float(-0.12)
        finalizeTrailLayer.instanceTransform = CATransform3DIdentity
        finalizeTrailDot.cornerRadius = 3
        finalizeTrailDot.backgroundColor = NSColor.white.withAlphaComponent(0.8).cgColor
        finalizeTrailDot.bounds = CGRect(x: 0, y: 0, width: 6, height: 6)
        finalizeTrailDot.opacity = 0.0
        finalizeTrailLayer.addSublayer(finalizeTrailDot)
        bubbleLayer.addSublayer(finalizeTrailLayer)
        
        layer?.addSublayer(bubbleLayer)
        
        thinkingDotsLayer.opacity = 0
        bubbleLayer.addSublayer(thinkingDotsLayer)
        
        layer?.shadowOpacity = 0.35
        layer?.shadowRadius = 22
        layer?.shadowOffset = CGSize(width: 0, height: -6)
        layer?.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.45).cgColor
    }
    
    private func setupLabels() {
        transcriptField.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        transcriptField.textColor = NSColor.white
        transcriptField.alignment = .left
        transcriptField.lineBreakMode = .byWordWrapping
        transcriptField.maximumNumberOfLines = 0
        transcriptField.backgroundColor = .clear
        transcriptField.wantsLayer = true
        transcriptField.alphaValue = 0.0
        
        statusField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        statusField.textColor = NSColor.white.withAlphaComponent(0.7)
        statusField.alignment = .left
        statusField.backgroundColor = .clear
        statusField.wantsLayer = true
        statusField.alphaValue = 0.8
        
        addSubview(statusField)
        addSubview(transcriptField)
    }
    
    override func layout() {
        super.layout()
        bubbleLayer.frame = bounds
        backgroundGradient.frame = bubbleLayer.bounds
        glossGradient.frame = bubbleLayer.bounds
        let bubblePath = NSBezierPath(roundedRect: bubbleLayer.bounds, xRadius: bubbleLayer.cornerRadius, yRadius: bubbleLayer.cornerRadius)
        borderLayer.path = bubblePath.cgPath
        entranceRippleLayer.frame = bubbleLayer.bounds
        entranceRippleLayer.path = bubblePath.cgPath
        finalizePulseLayer.frame = bubbleLayer.bounds
        finalizePulseLayer.path = bubblePath.cgPath
        finalizePath = bubblePath.cgPath
        finalizeTrailLayer.frame = bubbleLayer.bounds
        let trailY = bubbleLayer.bounds.maxY - 18
        finalizeTrailStart = CGPoint(x: bubbleLayer.bounds.minX + 26, y: trailY)
        finalizeTrailEnd = CGPoint(x: bubbleLayer.bounds.maxX - 26, y: trailY)
        finalizeTrailDot.position = finalizeTrailStart
        let trailPath = CGMutablePath()
        let controlOffset: CGFloat = 34
        let lift: CGFloat = 12
        trailPath.move(to: finalizeTrailStart)
        trailPath.addCurve(
            to: finalizeTrailEnd,
            control1: CGPoint(x: finalizeTrailStart.x + controlOffset, y: trailY + lift),
            control2: CGPoint(x: finalizeTrailEnd.x - controlOffset, y: trailY + lift)
        )
        finalizeTrailPath = trailPath
        
        layoutLabels()
        layoutThinkingDots()
    }
    
    private func layoutLabels() {
        let padding: CGFloat = 18
        let statusHeight: CGFloat = 18
        let transcriptTop = padding + statusHeight + 6
        
        statusField.frame = NSRect(
            x: padding,
            y: bounds.height - padding - statusHeight,
            width: bounds.width - padding * 2,
            height: statusHeight
        )
        
        transcriptField.frame = NSRect(
            x: padding,
            y: padding,
            width: bounds.width - padding * 2,
            height: bounds.height - transcriptTop - padding
        )
    }
    
    private func layoutThinkingDots() {
        let dotCount = 3
        let dotDiameter: CGFloat = 6
        let spacing: CGFloat = 8
        let totalWidth = CGFloat(dotCount) * dotDiameter + CGFloat(dotCount - 1) * spacing
        let dotsOrigin = CGPoint(
            x: bounds.midX - totalWidth / 2,
            y: transcriptField.frame.midY - dotDiameter / 2
        )
        
        thinkingDotsLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        for index in 0..<dotCount {
            let dot = CALayer()
            dot.cornerRadius = dotDiameter / 2
            dot.backgroundColor = NSColor.white.withAlphaComponent(0.65).cgColor
            dot.frame = CGRect(
                x: dotsOrigin.x + CGFloat(index) * (dotDiameter + spacing),
                y: dotsOrigin.y,
                width: dotDiameter,
                height: dotDiameter
            )
            thinkingDotsLayer.addSublayer(dot)
            addPulseAnimation(to: dot, offset: Double(index) * 0.18)
        }
        
        thinkingDotsLayer.frame = bounds
    }
    
    private func addPulseAnimation(to layer: CALayer, offset: CFTimeInterval) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0.25
        animation.toValue = 0.9
        animation.duration = 0.9
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.beginTime = CACurrentMediaTime() + offset
        layer.add(animation, forKey: "pulse")
    }
    
    func resetForNewCapture() {
        transcriptField.stringValue = ""
        transcriptField.alphaValue = 0.0
        statusField.stringValue = "Listening…"
        statusField.alphaValue = 0.8
        setGlowColor(nil, animated: false)
        setThinking(false)
        setClarificationAccent(false)
        finalizeEffectInFlight = false
        entranceRippleLayer.removeAllAnimations()
        entranceRippleLayer.opacity = 0.0
        finalizePulseLayer.removeAllAnimations()
        finalizePulseLayer.opacity = 0.0
        finalizeTrailLayer.removeAllAnimations()
        finalizeTrailLayer.opacity = 0.0
        finalizeTrailDot.removeAllAnimations()
        finalizeTrailDot.opacity = 0.0
        finalizeTrailDot.position = finalizeTrailStart
    }
    
    func updateTranscript(_ text: String, isFinal: Bool) {
        guard transcriptField.stringValue != text else { return }
        transcriptField.stringValue = text
        
        let targetAlpha: CGFloat = text.isEmpty ? 0.0 : 1.0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            transcriptField.animator().alphaValue = targetAlpha
        }
        
        if isFinal {
            transcriptField.textColor = NSColor.white
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.triggerFinalizeEffect()
            }
        } else {
            transcriptField.textColor = NSColor.white.withAlphaComponent(0.85)
        }
    }
    
    func setStatus(_ text: String?, animated: Bool = true) {
        let newText = text ?? ""
        guard statusField.stringValue != newText else { return }
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                statusField.animator().alphaValue = 0.0
            } completionHandler: {
                self.statusField.stringValue = newText
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.16
                    self.statusField.animator().alphaValue = newText.isEmpty ? 0.0 : 0.8
                }
            }
        } else {
            statusField.stringValue = newText
            statusField.alphaValue = newText.isEmpty ? 0.0 : 0.8
        }
    }
    
    func setThinking(_ active: Bool) {
        guard isThinking != active else { return }
        isThinking = active
        let targetOpacity: Float = active ? 1.0 : 0.0
        thinkingDotsLayer.opacity = targetOpacity
        
        if active {
            layoutThinkingDots()
            startThinkingAnimations()
        } else {
            thinkingDotsLayer.sublayers?.forEach { $0.removeAllAnimations() }
            stopThinkingAnimations()
        }
    }
    
    func setGlowColor(_ color: NSColor?, animated: Bool = true) {
        glowColor = color
        let targetColor = color?.withAlphaComponent(0.75) ?? NSColor.systemBlue.withAlphaComponent(0.45)
        let shadowOpacity: Float = color == nil ? 0.35 : 0.85
        let shadowRadius: CGFloat = color == nil ? 22 : 28
        
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        layer?.shadowColor = targetColor.cgColor
        layer?.shadowRadius = shadowRadius
        layer?.shadowOpacity = shadowOpacity
        CATransaction.commit()
        
        let borderColor = color?.withAlphaComponent(0.35) ?? NSColor.white.withAlphaComponent(0.18)
        borderLayer.strokeColor = borderColor.cgColor
    }
    
    func applyPopAnimation() {
        let animation = CASpringAnimation(keyPath: "transform.scale")
        animation.damping = 12
        animation.stiffness = 150
        animation.mass = 1
        animation.initialVelocity = 0.4
        animation.fromValue = 0.92
        animation.toValue = 1.0
        animation.duration = animation.settlingDuration
        layer?.add(animation, forKey: "pop")
        playEntranceRipple()
    }
    
    private func startThinkingAnimations() {
        let breath = CABasicAnimation(keyPath: "transform.scale")
        breath.fromValue = 0.985
        breath.toValue = 1.015
        breath.duration = 1.4
        breath.autoreverses = true
        breath.repeatCount = .infinity
        breath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        bubbleLayer.add(breath, forKey: "think-breathe")
        
        let shimmer = CABasicAnimation(keyPath: "locations")
        shimmer.fromValue = [0.0, 0.35, 1.0]
        shimmer.toValue = [0.0, 0.55, 1.0]
        shimmer.duration = 1.6
        shimmer.autoreverses = true
        shimmer.repeatCount = .infinity
        shimmer.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glossGradient.add(shimmer, forKey: "think-shimmer")
    }
    
    private func stopThinkingAnimations() {
        bubbleLayer.removeAnimation(forKey: "think-breathe")
        glossGradient.removeAnimation(forKey: "think-shimmer")
    }
    
    private func playEntranceRipple() {
        entranceRippleLayer.removeAllAnimations()
        entranceRippleLayer.opacity = 1.0
        
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.94
        scale.toValue = 1.12
        scale.duration = 0.5
        
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.28
        fade.toValue = 0.0
        fade.duration = 0.5
        
        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = 0.5
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.isRemovedOnCompletion = true
        
        entranceRippleLayer.add(group, forKey: "entrance-ripple")
        entranceRippleLayer.opacity = 0.0
    }
    
    private func triggerFinalizeEffect() {
        if finalizeEffectInFlight { return }
        if finalizeTrailPath == nil {
            layoutSubtreeIfNeeded()
        }
        guard let finalizeTrailPath else { return }
        
        finalizeEffectInFlight = true
        
        finalizePulseLayer.removeAllAnimations()
        finalizeTrailLayer.removeAllAnimations()
        finalizeTrailDot.removeAllAnimations()
        
        finalizePulseLayer.opacity = 1.0
        let ringScale = CABasicAnimation(keyPath: "transform.scale")
        ringScale.fromValue = 0.9
        ringScale.toValue = 1.35
        ringScale.duration = 0.55
        ringScale.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.3, 0.18, 1.0)
        
        let ringFade = CABasicAnimation(keyPath: "opacity")
        ringFade.fromValue = 0.45
        ringFade.toValue = 0.0
        ringFade.duration = 0.55
        ringFade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        let ringGroup = CAAnimationGroup()
        ringGroup.animations = [ringScale, ringFade]
        ringGroup.duration = 0.55
        ringGroup.isRemovedOnCompletion = true
        finalizePulseLayer.add(ringGroup, forKey: "finalize-ring")
        finalizePulseLayer.opacity = 0.0
        
        finalizeTrailDot.position = finalizeTrailStart
        finalizeTrailLayer.opacity = 1.0
        finalizeTrailDot.opacity = 1.0
        
        let sweep = CAKeyframeAnimation(keyPath: "position")
        sweep.path = finalizeTrailPath
        sweep.duration = 0.58
        sweep.calculationMode = .paced
        sweep.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        let dotFade = CABasicAnimation(keyPath: "opacity")
        dotFade.fromValue = 1.0
        dotFade.toValue = 0.0
        dotFade.duration = 0.58
        dotFade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        let dotGroup = CAAnimationGroup()
        dotGroup.animations = [sweep, dotFade]
        dotGroup.duration = 0.58
        dotGroup.fillMode = .forwards
        dotGroup.isRemovedOnCompletion = true
        finalizeTrailDot.add(dotGroup, forKey: "finalize-trail")
        
        cleanupFinalizeEffect(after: 0.7)
    }
    
    private func cleanupFinalizeEffect(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.finalizeEffectInFlight = false
            self.finalizePulseLayer.opacity = 0.0
            self.finalizeTrailLayer.opacity = 0.0
            self.finalizeTrailDot.opacity = 0.0
            self.finalizeTrailDot.position = self.finalizeTrailStart
        }
    }
    
    func setClarificationAccent(_ active: Bool) {
        isClarificationMode = active
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if active {
            backgroundGradient.colors = [
                NSColor(calibratedWhite: 0.12, alpha: 0.88).cgColor,
                NSColor.systemBlue.withAlphaComponent(0.32).cgColor
            ]
            glossGradient.colors = [
                NSColor.white.withAlphaComponent(0.24).cgColor,
                NSColor.white.withAlphaComponent(0.05).cgColor
            ]
        } else {
            backgroundGradient.colors = [
                NSColor(calibratedWhite: 0.08, alpha: 0.86).cgColor,
                NSColor(calibratedWhite: 0.2, alpha: 0.9).cgColor
            ]
            glossGradient.colors = [
                NSColor.white.withAlphaComponent(0.18).cgColor,
                NSColor.white.withAlphaComponent(0.0).cgColor
            ]
        }
        CATransaction.commit()
    }
}

private extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)
        
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo, .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }
        return path
    }
}
