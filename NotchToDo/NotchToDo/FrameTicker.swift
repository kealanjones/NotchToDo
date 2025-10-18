import Foundation
import QuartzCore

@MainActor
protocol FrameUpdatable: AnyObject {
    func frameTick(deltaTime: CFTimeInterval)
}

@MainActor
final class FrameTicker {
    static let shared = FrameTicker()

    private var timer: Timer?
    private var lastTimestamp: CFTimeInterval?
    private let observers = NSHashTable<AnyObject>.weakObjects()

    private init() {}

    func addObserver(_ observer: FrameUpdatable) {
        let alreadyRegistered = observers.allObjects.contains { $0 === (observer as AnyObject) }
        if !alreadyRegistered {
            observers.add(observer as AnyObject)
        }
        startTimerIfNeeded()
    }

    func removeObserver(_ observer: FrameUpdatable) {
        observers.remove(observer as AnyObject)
        if observers.allObjects.isEmpty {
            stopTimer()
        }
    }

    private func startTimerIfNeeded() {
        guard timer == nil, !observers.allObjects.isEmpty else { return }

        lastTimestamp = CACurrentMediaTime()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.handleTimerTick()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        lastTimestamp = nil
    }

    private func handleTimerTick() {
        let timestamp = CACurrentMediaTime()
        let delta: CFTimeInterval

        if let lastTimestamp {
            delta = timestamp - lastTimestamp
        } else {
            delta = 1.0 / 60.0
        }

        lastTimestamp = timestamp
        broadcast(delta: delta)
    }

    private func broadcast(delta: CFTimeInterval) {
        let activeObservers = observers.allObjects.compactMap { $0 as? FrameUpdatable }
        if activeObservers.isEmpty {
            stopTimer()
            return
        }

        for observer in activeObservers {
            observer.frameTick(deltaTime: delta)
        }
    }
}
