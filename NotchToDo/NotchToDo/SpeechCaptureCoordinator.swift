import AppKit
import NaturalLanguage

protocol SpeechCaptureCoordinatorDelegate: AnyObject {
    var isSemiCircleVisible: Bool { get }
    var semiCircleWindow: NSWindow? { get }
    var notchIndicatorWindow: NSWindow? { get }
    var semiCircleView: SemiCircleWithOrbsView? { get }
    var orbManager: OrbManager { get }
    var compactPreview: NotchCompactPreviewController { get }
    func setState(_ state: ListenState)
    func resetFadeTimer()
    func showSemiCircle(completion: (() -> Void)?)
    func resolveTargetOrbForNewTask() -> ProjectOrb
    func addTask(_ title: String, to targetOrb: ProjectOrb)
    func speechCaptureCoordinator(_ coordinator: SpeechCaptureCoordinator, didFailWith message: String)
    func suspendAutoFade()
    func resumeAutoFade()
    func speechCaptureBubbleDidAppear()
    func speechCaptureBubbleDidDisappear()
}

final class SpeechCaptureCoordinator {
    weak var delegate: SpeechCaptureCoordinatorDelegate?

    private let taskClassifier = TaskClassifier.shared

    private var speechBubbleWindow: NSWindow?
    private var speechBubbleView: SpeechCaptureBubbleView?
    private var speechClassificationWorkItem: DispatchWorkItem?
    private var pendingTranscript: String?
    private var pendingTaskTitle: String?
    private var pendingBubbleTargetOrbId: UUID?
    private var activeSessionID: UUID?
    private let initialSessionTimeout: TimeInterval = 6.0
    private let activitySessionTimeout: TimeInterval = 10.0
    private var sessionTimeoutWorkItem: DispatchWorkItem?
    private var isExternalSilenceHoldActive = false
    private let bubbleMinWidth: CGFloat = 320
    private let bubbleMaxWidth: CGFloat = 420
    private let bubbleMinHeight: CGFloat = 120
    private let bubbleHeightScreenPadding: CGFloat = 240
    private let fallbackMaxBubbleHeight: CGFloat = 640

    private func logSessionEvent(_ message: String) {
        let prefix: String
        if let id = activeSessionID {
            prefix = "[SpeechSession][\(id.uuidString.prefix(6))]"
        } else {
            prefix = "[SpeechSession][no-session]"
        }
        DebugLog.log("\(prefix) \(message)", category: .speech)
    }

    init(delegate: SpeechCaptureCoordinatorDelegate) {
        self.delegate = delegate
    }

    // MARK: - Accessors

    func speechBubbleCenter(relativeTo view: NSView) -> CGPoint? {
        guard let bubbleWindow = speechBubbleWindow, bubbleWindow.isVisible,
              let targetWindow = view.window else { return nil }
        let screenPoint = CGPoint(x: bubbleWindow.frame.midX, y: bubbleWindow.frame.midY)
        let screenRect = NSRect(origin: screenPoint, size: .zero)
        let windowPoint = targetWindow.convertFromScreen(screenRect).origin
        return view.convert(windowPoint, from: nil)
    }

    func bubbleTargetOrbId() -> UUID? {
        return pendingBubbleTargetOrbId
    }

    func isSpeechCaptureActive() -> Bool {
        return speechBubbleWindow?.isVisible ?? false
    }
    
    func setExternalSilenceHoldActive(_ active: Bool) {
        guard isExternalSilenceHoldActive != active else { return }
        isExternalSilenceHoldActive = active
        logSessionEvent("external silence hold \(active ? "activated" : "released")")
        DispatchQueue.main.async { [weak self] in
            self?.speechBubbleView?.setSilenceHoldActive(active)
        }
    }

    // MARK: - Session Lifecycle

    func beginSession(sessionID: UUID, wakePhrase: String? = nil) {
        activeSessionID = sessionID
        pendingTranscript = nil
        pendingTaskTitle = nil
        speechClassificationWorkItem?.cancel()
        let wakeSuffix = wakePhrase.map { " (wake: \($0))" } ?? ""
        logSessionEvent("begin session" + wakeSuffix)
        isExternalSilenceHoldActive = false
        ensureSpeechBubbleWindow()
        speechBubbleView?.resetForNewCapture()
        speechBubbleView?.forcePreferredSizeUpdate()
        speechBubbleView?.applyPopAnimation()
        delegate?.setState(.listening)
        delegate?.suspendAutoFade()
        pendingBubbleTargetOrbId = nil
        presentSpeechBubble()
        AudioFeedback.shared.play(.startListening, volume: 0.5)
        delegate?.resetFadeTimer()
        scheduleSessionTimeout(initialSessionTimeout)
    }

    func updatePartialTranscript(_ partialTranscript: String) {
        pendingTranscript = partialTranscript
        let snippet = partialTranscript.prefix(80)
        logSessionEvent("partial transcript: \(snippet)")
        ensureSpeechBubbleWindow()
        if speechBubbleWindow?.isVisible != true {
            presentSpeechBubble()
        }
        delegate?.setState(.transcribing)
        speechBubbleView?.setStatus("Recording…")
        speechBubbleView?.setThinking(false)
        speechBubbleView?.updateTranscript(partialTranscript, isFinal: false)
        scheduleSessionTimeout(activitySessionTimeout)
    }

    func finalizeTranscript(_ transcript: String, resolvedTaskTitle: String?) {
        cancelSessionTimeout()
        let displayText = resolvedTaskTitle ?? transcript
        logSessionEvent("final transcript resolved: \(displayText)")
        pendingTranscript = displayText
        pendingTaskTitle = resolvedTaskTitle ?? transcript
        ensureSpeechBubbleWindow()
        if speechBubbleWindow?.isVisible != true {
            presentSpeechBubble()
        }
        delegate?.setState(.transcribing)
        speechBubbleView?.setStatus("Understanding…")
        speechBubbleView?.setThinking(true)
        speechBubbleView?.updateTranscript(displayText, isFinal: true)
        AudioFeedback.shared.play(.success, volume: 0.6)

        speechClassificationWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.completeTranscriptRouting()
        }
        speechClassificationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
    }

    func finalizeCommand(transcript: String, status: String?, completion: (() -> Void)?) {
        cancelSessionTimeout()
        logSessionEvent("finalizing command: \(transcript)")
        pendingTranscript = transcript
        pendingTaskTitle = nil
        ensureSpeechBubbleWindow()
        if speechBubbleWindow?.isVisible != true {
            presentSpeechBubble()
        }
        delegate?.setState(.transcribing)
        speechBubbleView?.setThinking(true)
        speechBubbleView?.setStatus(status ?? "Working…")
        speechBubbleView?.updateTranscript(transcript, isFinal: true)
        speechBubbleView?.setClarificationAccent(false)
        speechClassificationWorkItem?.cancel()
        let finishDelay: TimeInterval = 0.9
        DispatchQueue.main.asyncAfter(deadline: .now() + finishDelay) { [weak self] in
            guard let self else { return }
            self.speechBubbleView?.setThinking(false)
            self.speechBubbleView?.setStatus(nil)
            self.pendingTranscript = nil
            self.pendingTaskTitle = nil
            self.delegate?.setState(.idle)
            self.logSessionEvent("command finalized, dismissing bubble")
            self.activeSessionID = nil
            self.dismissSpeechBubble(after: 0.15) {
                completion?()
            }
        }
    }

    func cancelSession() {
        logSessionEvent("session cancel requested")
        cancelSessionTimeout()
        pendingTranscript = nil
        pendingTaskTitle = nil
        speechClassificationWorkItem?.cancel()
        delegate?.setState(.idle)
        pendingBubbleTargetOrbId = nil
        activeSessionID = nil
        dismissSpeechBubble()
    }

    func revealOverlayForVoice(completion: (() -> Void)?) {
        ensureSemiCircleVisible {
            completion?()
        }
    }

    func showClarificationPrompt(for title: String) {
        logSessionEvent("clarification requested for: \(title)")
        ensureSpeechBubbleWindow()
        if speechBubbleWindow?.isVisible != true {
            presentSpeechBubble()
        }
        delegate?.setState(.transcribing)
        speechBubbleView?.setThinking(false)
        speechBubbleView?.setClarificationAccent(true)
        speechBubbleView?.updateTranscript("Add \"\(title)\" as a task or new orb?", isFinal: false)
        speechBubbleView?.setStatus("Say 'Notch confirm task' or 'Notch confirm project'")
        scheduleSessionTimeout(activitySessionTimeout)
    }

    func remindClarification(for title: String) {
        speechBubbleView?.setStatus("Confirm task or project for \"\(title)\"")
        speechBubbleView?.setClarificationAccent(true)
        scheduleSessionTimeout(activitySessionTimeout)
    }

    func dismissClarificationPrompt() {
        logSessionEvent("clarification prompt dismissed")
        cancelSessionTimeout()
        speechBubbleView?.setClarificationAccent(false)
        speechBubbleView?.setStatus(nil)
        dismissSpeechBubble(after: 0.1)
    }

    func showSpeechError(_ errorMessage: String) {
        cancelSessionTimeout()
        ensureSpeechBubbleWindow()
        if speechBubbleWindow?.isVisible != true {
            presentSpeechBubble()
        }
        logSessionEvent("showing speech error: \(errorMessage)")
        speechBubbleView?.updateTranscript("Error", isFinal: true)
        speechBubbleView?.setStatus(errorMessage)
        speechBubbleView?.setThinking(false)
        dismissSpeechBubble(after: 3.0)
        activeSessionID = nil
    }

    func resetUIState() {
        cancelSessionTimeout()
        speechClassificationWorkItem?.cancel()
        pendingTranscript = nil
        pendingTaskTitle = nil
        pendingBubbleTargetOrbId = nil
        speechBubbleWindow?.orderOut(nil)
        speechBubbleView?.resetForNewCapture()
        speechBubbleView?.forcePreferredSizeUpdate()
        isExternalSilenceHoldActive = false
        speechBubbleView?.setSilenceHoldActive(false, animated: false)
        delegate?.resumeAutoFade()
        delegate?.speechCaptureBubbleDidDisappear()
    }

    // MARK: - Embedding Cache

    func refreshOrbEmbeddingCache() {
        guard let orbManager = delegate?.orbManager else { return }
        taskClassifier.refreshOrbCache(orbs: orbManager.orbs)
    }

    func primeEmbedding(for orb: ProjectOrb) {
        taskClassifier.primeCache(for: orb)
    }

    // MARK: - Helpers

    private func ensureSpeechBubbleWindow() {
        if let bubbleView = speechBubbleView, speechBubbleWindow != nil {
            configureSpeechBubbleView(bubbleView)
            bubbleView.forcePreferredSizeUpdate()
            return
        }

        let bubbleView = SpeechCaptureBubbleView(frame: NSRect(x: 0, y: 0, width: 320, height: 120))
        configureSpeechBubbleView(bubbleView)
        let window = NSWindow(
            contentRect: bubbleView.bounds,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovable = false
        window.isReleasedWhenClosed = false
        window.contentView = bubbleView

        speechBubbleWindow = window
        speechBubbleView = bubbleView
        bubbleView.forcePreferredSizeUpdate()
    }

    private func configureSpeechBubbleView(_ bubbleView: SpeechCaptureBubbleView) {
        bubbleView.preferredSizeDidChange = { [weak self] size in
            guard let self else { return }
            let animate = self.speechBubbleWindow?.isVisible == true
            self.resizeSpeechBubble(to: size, animated: animate)
        }
    }

    private func presentSpeechBubble() {
        delegate?.suspendAutoFade()
        guard let window = speechBubbleWindow else { return }
        positionSpeechBubbleWindow()
        let finalOrigin = window.frame.origin
        var startOrigin = finalOrigin
        startOrigin.y += 18
        window.setFrameOrigin(startOrigin)
        window.alphaValue = 0.0
        let wasVisible = window.isVisible
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.26
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.8, 0.2, 1.0)
            window.animator().alphaValue = 1.0
            window.animator().setFrameOrigin(finalOrigin)
        }

        if !wasVisible {
            delegate?.speechCaptureBubbleDidAppear()
        }
    }

    private func positionSpeechBubbleWindow(animated: Bool = false) {
        guard let window = speechBubbleWindow else { return }
        let origin = computeSpeechBubbleOrigin(for: window.frame.size)
        if animated {
            window.animator().setFrameOrigin(origin)
        } else {
            window.setFrameOrigin(origin)
        }
    }

    private func resizeSpeechBubble(to size: NSSize, animated: Bool) {
        guard let window = speechBubbleWindow else { return }
        let clamped = clampBubbleSize(size)
        let currentSize = window.frame.size
        if abs(currentSize.width - clamped.width) < 0.5 && abs(currentSize.height - clamped.height) < 0.5 {
            return
        }
        let targetOrigin = computeSpeechBubbleOrigin(for: clamped)
        let targetFrame = NSRect(origin: targetOrigin, size: clamped)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(targetFrame, display: true)
            }
        } else {
            window.setFrame(targetFrame, display: true)
        }
    }

    private func clampBubbleSize(_ size: NSSize) -> NSSize {
        let width = min(bubbleMaxWidth, max(bubbleMinWidth, size.width))
        let maxHeight = dynamicMaxBubbleHeight()
        let height = min(maxHeight, max(bubbleMinHeight, size.height))
        return NSSize(width: width, height: height)
    }

    private func computeSpeechBubbleOrigin(for size: NSSize) -> NSPoint {
        let anchor = anchorRectForSpeechBubble()
        var origin = NSPoint(x: anchor.midX - size.width / 2, y: anchor.maxY)

        if delegate?.isSemiCircleVisible == true, let semiCircleFrame = delegate?.semiCircleWindow?.frame {
            origin.y = semiCircleFrame.minY - size.height - 24
        } else if let screen = NSScreen.main {
            let top = screen.frame.maxY
            let middle = screen.frame.midY
            let blendFactor: CGFloat = 0.55
            let centerY = top - (top - middle) * blendFactor
            origin.y = centerY - size.height / 2.0
            origin.x = screen.frame.midX - size.width / 2.0
        } else {
            origin.y = anchor.maxY - size.height - 40
        }

        if let screen = NSScreen.main {
            let frame = screen.frame
            let minX = frame.minX + 20
            let maxX = frame.maxX - size.width - 20
            origin.x = min(max(origin.x, minX), maxX)
            origin.y = min(frame.maxY - size.height - 20, origin.y)
        }

        return origin
    }

    private func dynamicMaxBubbleHeight() -> CGFloat {
        guard let screen = NSScreen.main else {
            return fallbackMaxBubbleHeight
        }
        let available = screen.visibleFrame.height - bubbleHeightScreenPadding
        return max(bubbleMinHeight, available)
    }

    private func anchorRectForSpeechBubble() -> NSRect {
        if let semiCircleWindow = delegate?.semiCircleWindow, semiCircleWindow.isVisible {
            return semiCircleWindow.frame
        }
        if let notchIndicatorWindow = delegate?.notchIndicatorWindow {
            return notchIndicatorWindow.frame
        }
        if let screen = NSScreen.main {
            let frame = screen.frame
            return NSRect(x: frame.midX - 1, y: frame.maxY - 200, width: 2, height: 2)
        }
        return NSRect(x: 0, y: 0, width: 2, height: 2)
    }

    private func ensureSemiCircleVisible(completion: @escaping () -> Void) {
        if delegate?.isSemiCircleVisible == true {
            completion()
        } else {
            delegate?.showSemiCircle(completion: completion)
        }
    }

    private func completeTranscriptRouting() {
        cancelSessionTimeout()
        guard let displayText = pendingTranscript, !displayText.isEmpty else {
            logSessionEvent("no transcript available; ending session")
            delegate?.setState(.idle)
            dismissSpeechBubble(after: 0.05)
            activeSessionID = nil
            return
        }

        guard let delegate = delegate else {
            logSessionEvent("delegate missing; ending session")
            dismissSpeechBubble(after: 0.05)
            activeSessionID = nil
            return
        }

        let taskTitle = pendingTaskTitle ?? displayText
        speechBubbleView?.setThinking(false)

        let targetOrb = classifyOrb(for: taskTitle, delegate: delegate)
        logSessionEvent("routing to orb: \(targetOrb.name) (tasks: \(targetOrb.taskCount))")
        pendingBubbleTargetOrbId = targetOrb.id
        speechBubbleView?.setStatus("Sorting into \(targetOrb.name)…")
        speechBubbleView?.setGlowColor(targetOrb.color, animated: true)
        speechBubbleView?.applyPopAnimation()

        let repositionDelay: TimeInterval = 0.45
        let semiCircleRevealDelay: TimeInterval = 0.45
        let dropDelay: TimeInterval = 0.45

        DispatchQueue.main.asyncAfter(deadline: .now() + repositionDelay) { [weak self] in
            guard let self else { return }
            self.prepareBubbleForOrbAnimation(targetOrb: targetOrb) { [weak self] in
                guard let self else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + semiCircleRevealDelay) { [weak self] in
                    guard let self else { return }
                    self.ensureSemiCircleVisible {
                        DispatchQueue.main.asyncAfter(deadline: .now() + dropDelay) { [weak self] in
                            guard let self else { return }
                            self.animateSpeechBubble(into: targetOrb, with: taskTitle)
                        }
                    }
                }
            }
        }
    }

    private func prepareBubbleForOrbAnimation(targetOrb: ProjectOrb, completion: @escaping () -> Void) {
        guard let window = speechBubbleWindow else {
            completion()
            return
        }

        guard let anchorPoint = orbScreenPosition(for: targetOrb) ?? bubbleFallbackPoint() else {
            completion()
            return
        }

        let originX = anchorPoint.x - window.frame.width / 2
        var originY: CGFloat
        if let semiCircleFrame = delegate?.semiCircleWindow?.frame {
            originY = semiCircleFrame.minY - window.frame.height - 28
        } else {
            originY = anchorPoint.y - window.frame.height / 2 - 120
        }

        var origin = NSPoint(x: originX, y: originY)

        if let screen = NSScreen.main {
            let frame = screen.frame
            origin.x = max(frame.minX + 20, min(origin.x, frame.maxX - window.frame.width - 20))
            origin.y = max(frame.minY + 40, min(origin.y, frame.maxY - window.frame.height - 40))
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.3, 0.8, 0.2, 1.0)
            window.animator().setFrameOrigin(origin)
        } completionHandler: {
            completion()
        }
    }

    private func classifyOrb(for transcript: String, delegate: SpeechCaptureCoordinatorDelegate) -> ProjectOrb {
        let orbs = delegate.orbManager.orbs
        guard !orbs.isEmpty else {
            return delegate.resolveTargetOrbForNewTask()
        }

        // Use the new TaskClassifier for intelligent orb suggestion
        let suggestion = taskClassifier.suggestOrbs(for: transcript, orbs: orbs, topN: 1)

        if let primaryMatch = suggestion.primarySuggestion {
            DebugLog.log("""
                ML-powered classification:
                - Task: '\(transcript)'
                - Selected orb: \(primaryMatch.orb.name)
                - Confidence: \(String(format: "%.2f", primaryMatch.confidence))
                - Method: \(primaryMatch.method.rawValue)
                """, category: .ml)
            return primaryMatch.orb
        }

        // Fallback to default behavior
        return delegate.resolveTargetOrbForNewTask()
    }

    private func animateSpeechBubble(into orb: ProjectOrb, with taskTitle: String) {
        guard let delegate = delegate else { return }

        guard let window = speechBubbleWindow else {
            logSessionEvent("bubble window missing during animation; finishing session")
            pendingBubbleTargetOrbId = nil
            delegate.addTask(taskTitle, to: orb)
            // Record feedback for ML training
            taskClassifier.recordFeedback(taskText: taskTitle, chosenOrb: orb)
            pendingTranscript = nil
            pendingTaskTitle = nil
            delegate.setState(.idle)
            activeSessionID = nil
            return
        }

        guard let targetPoint = orbScreenPosition(for: orb) else {
            logSessionEvent("orb screen position unavailable; finishing session")
            pendingBubbleTargetOrbId = nil
            dismissSpeechBubble()
            delegate.addTask(taskTitle, to: orb)
            // Record feedback for ML training
            taskClassifier.recordFeedback(taskText: taskTitle, chosenOrb: orb)
            pendingTranscript = nil
            pendingTaskTitle = nil
            delegate.setState(.idle)
            activeSessionID = nil
            return
        }

        let startFrame = window.frame
        let targetSize = NSSize(width: 46, height: 46)
        let targetOrigin = NSPoint(
            x: targetPoint.x - targetSize.width / 2,
            y: targetPoint.y - targetSize.height / 2
        )
        let targetFrame = NSRect(origin: targetOrigin, size: targetSize)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.45
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.45, 0.1, 0.7, 1.0)
            window.animator().setFrame(targetFrame, display: true)
            window.animator().alphaValue = 0.0
        } completionHandler: { [weak self] in
            guard let self else { return }
            orb.applyImpulse(CGPoint(x: 0, y: 3.5))
            self.pendingBubbleTargetOrbId = nil
            delegate.addTask(taskTitle, to: orb)
            // Record feedback for ML training
            self.taskClassifier.recordFeedback(taskText: taskTitle, chosenOrb: orb)
            AudioFeedback.shared.play(.dropIntoOrb, volume: 0.55)
            delegate.compactPreview.present(
                orbColor: orb.color,
                title: orb.name,
                subtitle: taskTitle
            )
            self.pendingTranscript = nil
            self.pendingTaskTitle = nil
            delegate.setState(.idle)
            self.logSessionEvent("session completed and bubble dismissed")
            self.activeSessionID = nil
            self.dismissSpeechBubble {
                window.setFrame(startFrame, display: false)
                window.alphaValue = 1.0
            }
        }
    }

    private func orbScreenPosition(for orb: ProjectOrb) -> CGPoint? {
        guard let semiCircleView = delegate?.semiCircleView,
              let semiCircleWindow = delegate?.semiCircleWindow else { return nil }
        let centerX = semiCircleView.bounds.midX
        let centerY = semiCircleView.bounds.maxY - 10
        let radius = min(semiCircleView.bounds.width, semiCircleView.bounds.height) / 2 + 18.5

        var x = centerX + radius * cos(orb.angle)
        var y = centerY + radius * sin(orb.angle)
        x += orb.physicsDisplacement.x
        y += orb.physicsDisplacement.y + orb.hoverVerticalOffset

        let viewPoint = CGPoint(x: x, y: y)
        let windowPoint = semiCircleView.convert(viewPoint, to: nil)
        let screenPoint = semiCircleWindow.convertToScreen(NSRect(origin: windowPoint, size: .zero)).origin
        return screenPoint
    }

    private func bubbleFallbackPoint() -> CGPoint? {
        if let screen = NSScreen.main {
            let frame = screen.frame
            return CGPoint(x: frame.midX, y: frame.maxY - 200)
        }
        return nil
    }

    private func scheduleSessionTimeout(_ interval: TimeInterval) {
        sessionTimeoutWorkItem?.cancel()
        logSessionEvent("arming timeout for \(interval)s")
        let work = DispatchWorkItem { [weak self] in
            self?.handleSessionTimeout()
        }
        sessionTimeoutWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: work)
    }

    private func cancelSessionTimeout() {
        if sessionTimeoutWorkItem != nil {
            logSessionEvent("cancelled active timeout")
        }
        sessionTimeoutWorkItem?.cancel()
        sessionTimeoutWorkItem = nil
    }

    private func handleSessionTimeout() {
        guard speechBubbleWindow?.isVisible == true else { return }
        logSessionEvent("session timeout fired")
        speechClassificationWorkItem?.cancel()
        pendingTranscript = nil
        pendingTaskTitle = nil
        pendingBubbleTargetOrbId = nil
        delegate?.setState(.error("Listening timed out"))
        showSpeechError("Listening timed out")
        delegate?.speechCaptureCoordinator(self, didFailWith: "Listening timed out")
        activeSessionID = nil
    }

    private func dismissSpeechBubble(after delay: TimeInterval = 0.0, completion: (() -> Void)? = nil) {
        setExternalSilenceHoldActive(false)
        guard let window = speechBubbleWindow else {
            delegate?.resumeAutoFade()
            delegate?.speechCaptureBubbleDidDisappear()
            completion?()
            return
        }

        logSessionEvent("dismissing speech bubble after delay: \(delay)")

        let fadeOut = {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                window.animator().alphaValue = 0.0
            } completionHandler: {
                self.pendingBubbleTargetOrbId = nil
                window.orderOut(nil)
                self.delegate?.resumeAutoFade()
                self.delegate?.speechCaptureBubbleDidDisappear()
                completion?()
            }
        }

        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: fadeOut)
        } else {
            fadeOut()
        }
    }
}
