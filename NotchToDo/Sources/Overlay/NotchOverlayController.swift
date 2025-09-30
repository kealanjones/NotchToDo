import Cocoa
import SwiftUI

class NotchOverlayController: ObservableObject {
    private var overlayWindow: NSWindow?
    private var overlayView: NotchOverlayView?
    private var isVisible = false
    
    init() {
        setupOverlayWindow()
    }
    
    private func setupOverlayWindow() {
        // Create borderless window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 270, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = true
        window.level = .floating
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        // Create SwiftUI view
        let overlayView = NotchOverlayView()
        let hostingView = NSHostingView(rootView: overlayView)
        window.contentView = hostingView
        
        self.overlayWindow = window
        self.overlayView = overlayView
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
        
        window.makeKeyAndOrderFront(nil)
        isVisible = true
    }
    
    func hideOverlay() {
        guard let window = overlayWindow, isVisible else { return }
        
        window.orderOut(nil)
        isVisible = false
    }
    
    func setState(_ state: ListenState) {
        overlayView?.setState(state)
    }
    
    private func positionWindowAtNotch(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.frame
        let windowSize = window.frame.size
        
        // Position at top center of screen (notch area)
        let x = screenFrame.midX - windowSize.width / 2
        let y = screenFrame.maxY - windowSize.height - 0 // 20px from top
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - Notch Detection
extension NotchOverlayController {
    private func detectNotchBounds() -> NSRect? {
        // TODO: Implement proper notch detection
        // For now, return a heuristic based on screen size
        guard let screen = NSScreen.main else { return nil }
        
        let screenFrame = screen.frame
        let notchWidth: CGFloat = 200
        let notchHeight: CGFloat = 30
        
        return NSRect(
            x: screenFrame.midX - notchWidth / 2,
            y: screenFrame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )
    }
}

