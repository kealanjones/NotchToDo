import Foundation

protocol SpeechRecognizer {
    func start() throws
    func stop()
    func prepareForSession(id: UUID)
    func beginExternalSilenceHold()
    func endExternalSilenceHold()
    var onPartial: ((String) -> Void)? { get set }
    var onFinal: ((String) -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }
}

extension SpeechRecognizer {
    func prepareForSession(id: UUID) {}
    func beginExternalSilenceHold() {}
    func endExternalSilenceHold() {}
}

class MockSpeechRecognizer: SpeechRecognizer {
    var onPartial: ((String) -> Void)?
    var onFinal: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private var isRunning = false
    private var timer: Timer?
    
    func prepareForSession(id: UUID) {
        // Mock recognizer does not track sessions
    }
    
    func start() throws {
        guard !isRunning else { return }
        isRunning = true
        
        // Simulate partial results
        let partialTexts = ["add", "add buy", "add buy milk"]
        var index = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, index < partialTexts.count else { return }
            
            let text = partialTexts[index]
            self.onPartial?(text)
            index += 1
            
            if index >= partialTexts.count {
                self.timer?.invalidate()
                self.timer = nil
                self.onFinal?(text)
                self.isRunning = false
            }
        }
    }
    
    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
}
