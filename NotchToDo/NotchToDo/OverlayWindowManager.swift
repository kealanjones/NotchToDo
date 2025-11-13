import AppKit

final class OverlayWindowManager {
    weak var controller: NotchOverlayController?

    init(controller: NotchOverlayController) {
        self.controller = controller
    }

    func setupNotchIndicator() {
        guard let controller = controller else { return }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 50),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = false
        window.level = .statusBar
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovable = false
        window.acceptsMouseMovedEvents = true

        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor

        let notchView = NotchIndicatorView()
        if let screen = NSScreen.main {
            notchView.notchInfo = controller.getNotchInfo(for: screen)
        }
        window.contentView = notchView

        controller.notchIndicatorWindow = window
        positionNotchIndicator(window)
    }

    func positionNotchIndicator(_ window: NSWindow) {
        guard let controller = controller, let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let notchInfo = controller.getNotchInfo(for: screen)

        let x = screenFrame.midX - notchInfo.width / 2 - 20 + 0.5
        let y = screenFrame.maxY - notchInfo.height

        DebugLog.log("🔍 Window Positioning:", category: .app)
        DebugLog.log("Calculated X: \(x)", category: .app)
        DebugLog.log("Calculated Y: \(y)", category: .app)

        let windowRect = NSRect(x: x, y: y, width: notchInfo.width + 20, height: notchInfo.height + 20)
        window.setFrame(windowRect, display: true)

        DebugLog.log("Final window rect: \(windowRect)", category: .app)
    }

    func setupSemiCircle() {
        guard let controller = controller else { return }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 327, height: 168),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = false
        window.level = .statusBar
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovable = false
        window.acceptsMouseMovedEvents = true
        window.hidesOnDeactivate = false

        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor

        let semiCircleView = SemiCircleWithOrbsView(orbManager: controller.orbManager, controller: controller)
        window.contentView = semiCircleView

        controller.semiCircleWindow = window
        controller.semiCircleView = semiCircleView
        positionSemiCircle(window)

        DispatchQueue.main.async {
            semiCircleView.setupMouseTracking()
            DebugLog.log("🖱️ Mouse tracking setup attempted in setupSemiCircle", category: .app)
        }
    }

    func positionSemiCircle(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let x = screenFrame.midX - window.frame.width / 2
        let y = screenFrame.maxY - window.frame.height + 10
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
