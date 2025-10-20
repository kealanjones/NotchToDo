import AppKit

final class NotchCompactPreviewView: NSView {
    var orbColor: NSColor = .systemBlue { didSet { needsDisplay = true } }
    var title: String = "" { didSet { needsDisplay = true } }
    var subtitle: String = "" { didSet { needsDisplay = true } }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(dirtyRect)

        let rect = bounds.insetBy(dx: 1, dy: 1)
        let radius: CGFloat = rect.height / 2
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

        // Background glass
        ctx.saveGState()
        ctx.setFillColor(NSColor(calibratedWhite: 0.08, alpha: 0.85).cgColor)
        path.fill()
        ctx.restoreGState()

        // Rim
        ctx.saveGState()
        ctx.setStrokeColor(orbColor.withAlphaComponent(0.25).cgColor)
        ctx.setLineWidth(1)
        path.stroke()
        ctx.restoreGState()

        // Orb dot
        let dotSize: CGFloat = 10
        let dotRect = CGRect(x: rect.minX + 10, y: rect.midY - dotSize/2, width: dotSize, height: dotSize)
        ctx.setFillColor(orbColor.cgColor)
        ctx.fillEllipse(in: dotRect)

        // Text
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.75)
        ]
        let textX = dotRect.maxX + 8
        let titleRect = CGRect(x: textX, y: rect.midY + 1, width: rect.width - textX - 12, height: 14)
        let subtitleRect = CGRect(x: textX, y: rect.midY - 13, width: rect.width - textX - 12, height: 12)
        (title as NSString).draw(in: titleRect, withAttributes: titleAttrs)
        (subtitle as NSString).draw(in: subtitleRect, withAttributes: subtitleAttrs)
    }
}

final class NotchCompactPreviewController {
    private var window: NSWindow?
    private var view: NotchCompactPreviewView?
    private var hideWorkItem: DispatchWorkItem?

    func present(orbColor: NSColor, title: String, subtitle: String, duration: TimeInterval = 2.5) {
        ensureWindow()
        view?.orbColor = orbColor
        view?.title = title
        view?.subtitle = subtitle
        guard let window else { return }

        positionNearNotch(window)
        window.alphaValue = 0
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            window.animator().alphaValue = 1
        }

        hideWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    func hide() {
        guard let window = window else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            window.animator().alphaValue = 0
        } completionHandler: {
            window.orderOut(nil)
        }
    }

    private func ensureWindow() {
        guard window == nil else { return }
        let view = NotchCompactPreviewView(frame: NSRect(x: 0, y: 0, width: 240, height: 32))
        let win = NSWindow(contentRect: view.bounds, styleMask: [.borderless], backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = .statusBar
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
        win.contentView = view
        self.window = win
        self.view = view
    }

    private func positionNearNotch(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let width = window.frame.width
        let height = window.frame.height
        let x = frame.midX - width/2
        let y = frame.maxY - height - 6
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}


