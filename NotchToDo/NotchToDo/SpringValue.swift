import Foundation
import CoreGraphics

struct SpringValue {
    private(set) var value: CGFloat
    private(set) var velocity: CGFloat
    private(set) var target: CGFloat

    var stiffness: CGFloat
    var damping: CGFloat
    var threshold: CGFloat

    init(
        value: CGFloat = 0.0,
        target: CGFloat = 0.0,
        velocity: CGFloat = 0.0,
        stiffness: CGFloat = 180.0,
        damping: CGFloat = 22.0,
        threshold: CGFloat = 0.001
    ) {
        self.value = value
        self.velocity = velocity
        self.target = target
        self.stiffness = stiffness
        self.damping = damping
        self.threshold = threshold
    }

    mutating func update(deltaTime: CFTimeInterval) -> Bool {
        let dt = max(CGFloat(deltaTime), 0.0)
        guard dt > 0 else { return !isAtRest }

        let displacement = value - target
        let acceleration = (-stiffness * displacement) - (damping * velocity)

        velocity += acceleration * dt
        value += velocity * dt

        if abs(velocity) <= threshold && abs(displacement) <= threshold {
            value = target
            velocity = 0
            return false
        }

        return true
    }

    mutating func setTarget(_ newTarget: CGFloat) {
        target = newTarget
    }

    mutating func snap(to newValue: CGFloat, velocity newVelocity: CGFloat = 0.0) {
        value = newValue
        velocity = newVelocity
    }

    var isAtRest: Bool {
        abs(value - target) <= threshold && abs(velocity) <= threshold
    }
}
