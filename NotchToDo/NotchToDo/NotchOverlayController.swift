import Cocoa
import SwiftUI
import QuartzCore

class NotchOverlayController: ObservableObject {
    private var overlayWindow: NSWindow?
    private var overlayView: NotchOverlayView?
    private var isVisible = false
    
    @Published var isVerticallyExpanding = false
    
    init() {
        setupOverlayWindow()
    }
    
    private func setupOverlayWindow() {
        // Create borderless window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 270, height: 400),
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
    
    
    private func positionWindowAtNotch(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.frame
        let windowSize = window.frame.size
        
        // Position at top center of screen, extending above the screen frame
        let x = screenFrame.midX - windowSize.width / 2
        let y = screenFrame.maxY - windowSize.height + 20 // Extend 20px above screen
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
}
