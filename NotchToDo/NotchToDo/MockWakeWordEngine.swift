import Foundation

protocol WakeWordEngine {
    func start() throws
    func stop()
    var onTriggered: (() -> Void)? { get set }
}

class MockWakeWordEngine: WakeWordEngine {
    var onTriggered: (() -> Void)?
    private var isRunning = false
    private var timer: Timer?
    
    func start() throws {
        guard !isRunning else { return }
        isRunning = true
        
        // Simulate wake word detection after 2 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.isRunning = false
            self.timer?.invalidate()
            self.timer = nil
            self.onTriggered?()
        }
    }
    
    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
}
