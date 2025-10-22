import Cocoa
import AVFoundation

// MARK: - Celebration Effects System

/// Particle type for different celebration effects
enum ParticleType {
    case confetti
    case sparkle
    case star
    case check
}

/// Individual particle for animations
class Particle {
    var position: CGPoint
    var velocity: CGPoint
    var color: NSColor
    var size: CGFloat
    var alpha: CGFloat
    var rotation: CGFloat
    var rotationSpeed: CGFloat
    var lifetime: CFTimeInterval
    var age: CFTimeInterval = 0
    var type: ParticleType

    init(position: CGPoint, velocity: CGPoint, color: NSColor, size: CGFloat, type: ParticleType) {
        self.position = position
        self.velocity = velocity
        self.color = color
        self.size = size
        self.alpha = 1.0
        self.rotation = CGFloat.random(in: 0...(.pi * 2))
        self.rotationSpeed = CGFloat.random(in: -8...8)
        self.lifetime = Double.random(in: 0.6...1.2)
        self.type = type
    }

    func update(deltaTime: CFTimeInterval) -> Bool {
        age += deltaTime

        // Physics
        position.x += velocity.x * deltaTime
        position.y += velocity.y * deltaTime

        // Gravity
        velocity.y -= 400 * deltaTime

        // Air resistance
        velocity.x *= 0.98
        velocity.y *= 0.98

        // Rotation
        rotation += rotationSpeed * deltaTime

        // Fade out
        let normalizedAge = age / lifetime
        alpha = max(0, 1.0 - normalizedAge)

        return age < lifetime
    }
}

// MARK: - Particle Emitter

class ParticleEmitter {
    private var particles: [Particle] = []
    private var isActive = false

    func emit(at position: CGPoint, type: ParticleType, count: Int = 20) {
        isActive = true

        let colors: [NSColor] = [
            .systemYellow, .systemOrange, .systemPink,
            .systemPurple, .systemBlue, .systemGreen,
            .systemRed, .systemTeal
        ]

        for _ in 0..<count {
            let angle = CGFloat.random(in: 0...(.pi * 2))
            let speed = CGFloat.random(in: 150...400)
            let velocity = CGPoint(
                x: cos(angle) * speed,
                y: sin(angle) * speed + 200 // Bias upward
            )

            let color = colors.randomElement() ?? .systemYellow
            let size = CGFloat.random(in: 4...10)

            let particle = Particle(
                position: position,
                velocity: velocity,
                color: color,
                size: size,
                type: type
            )

            particles.append(particle)
        }
    }

    func update(deltaTime: CFTimeInterval) {
        particles.removeAll { !$0.update(deltaTime: deltaTime) }

        if particles.isEmpty {
            isActive = false
        }
    }

    func draw(in context: CGContext) {
        guard !particles.isEmpty else { return }

        context.saveGState()

        for particle in particles {
            context.saveGState()

            // Translate and rotate
            context.translateBy(x: particle.position.x, y: particle.position.y)
            context.rotate(by: particle.rotation)

            let color = particle.color.withAlphaComponent(particle.alpha)
            context.setFillColor(color.cgColor)

            switch particle.type {
            case .confetti:
                // Rectangle confetti
                let rect = CGRect(
                    x: -particle.size / 2,
                    y: -particle.size,
                    width: particle.size,
                    height: particle.size * 2
                )
                context.fill(rect)

            case .sparkle, .star:
                // Star shape
                drawStar(in: context, size: particle.size)

            case .check:
                // Checkmark
                drawCheckmark(in: context, size: particle.size, color: color)
            }

            context.restoreGState()
        }

        context.restoreGState()
    }

    private func drawStar(in context: CGContext, size: CGFloat) {
        let points = 5
        let outerRadius = size
        let innerRadius = size * 0.4

        context.beginPath()

        for i in 0..<points * 2 {
            let angle = CGFloat(i) * .pi / CGFloat(points)
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let x = cos(angle - .pi / 2) * radius
            let y = sin(angle - .pi / 2) * radius

            if i == 0 {
                context.move(to: CGPoint(x: x, y: y))
            } else {
                context.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.closePath()
        context.fillPath()
    }

    private func drawCheckmark(in context: CGContext, size: CGFloat, color: NSColor) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(size * 0.2)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        context.beginPath()
        context.move(to: CGPoint(x: -size * 0.3, y: 0))
        context.addLine(to: CGPoint(x: -size * 0.1, y: -size * 0.3))
        context.addLine(to: CGPoint(x: size * 0.4, y: size * 0.4))
        context.strokePath()
    }

    var hasActiveParticles: Bool {
        return isActive && !particles.isEmpty
    }
}

// MARK: - Celebration Sound Manager

class CelebrationSounds {
    static let shared = CelebrationSounds()

    private var completionPlayer: AVAudioPlayer?
    private var celebrationPlayer: AVAudioPlayer?

    private init() {
        setupSounds()
    }

    private func setupSounds() {
        // We'll use system sounds as fallback
        // In production, you'd include custom sound files
    }

    func playCompletion() {
        // Play a satisfying completion sound
        playSystemSound(soundID: 1057) // Pop sound
    }

    func playCelebration() {
        // Play celebration for multiple completions
        playSystemSound(soundID: 1111) // Success sound
    }

    func playUndo() {
        // Subtle undo sound
        playSystemSound(soundID: 1006) // Swoosh
    }

    private func playSystemSound(soundID: SystemSoundID) {
        guard AudioFeedback.shared.isEnabled else { return }
        AudioServicesPlaySystemSound(soundID)
    }
}

// MARK: - Ripple Effect

class RippleEffect {
    private var radius: CGFloat = 0
    private var maxRadius: CGFloat = 100
    private var alpha: CGFloat = 1.0
    private var isActive = false
    private var age: CFTimeInterval = 0
    private let lifetime: CFTimeInterval = 0.8
    private var center: CGPoint = .zero
    private var color: NSColor = .systemGreen

    func trigger(at point: CGPoint, color: NSColor = .systemGreen, maxRadius: CGFloat = 100) {
        self.center = point
        self.color = color
        self.maxRadius = maxRadius
        self.radius = 0
        self.alpha = 1.0
        self.age = 0
        self.isActive = true
    }

    func update(deltaTime: CFTimeInterval) {
        guard isActive else { return }

        age += deltaTime
        let progress = age / lifetime

        radius = maxRadius * CGFloat(progress)
        alpha = 1.0 - CGFloat(progress)

        if age >= lifetime {
            isActive = false
        }
    }

    func draw(in context: CGContext) {
        guard isActive else { return }

        context.saveGState()

        let rippleColor = color.withAlphaComponent(alpha * 0.4)
        context.setStrokeColor(rippleColor.cgColor)
        context.setLineWidth(3)

        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        context.strokeEllipse(in: rect)

        context.restoreGState()
    }

    var hasActiveRipple: Bool {
        return isActive
    }
}

// MARK: - Celebration Manager

class CelebrationManager {
    static let shared = CelebrationManager()

    private let particleEmitter = ParticleEmitter()
    private let rippleEffect = RippleEffect()
    private var consecutiveCompletions = 0
    private var lastCompletionTime: CFTimeInterval = 0

    private init() {}

    func celebrateTaskCompletion(at position: CGPoint, color: NSColor = .systemGreen) {
        let now = CACurrentMediaTime()

        // Track consecutive completions for extra celebration
        if now - lastCompletionTime < 3.0 {
            consecutiveCompletions += 1
        } else {
            consecutiveCompletions = 1
        }

        lastCompletionTime = now

        // Ripple effect
        rippleEffect.trigger(at: position, color: color, maxRadius: 60)

        // Particle count based on streak
        let particleCount = min(20 + consecutiveCompletions * 5, 50)

        // Confetti burst
        particleEmitter.emit(at: position, type: .confetti, count: particleCount)

        // Sound effect
        if consecutiveCompletions >= 3 {
            CelebrationSounds.shared.playCelebration()
        } else {
            CelebrationSounds.shared.playCompletion()
        }

        // Bonus sparkles for streaks
        if consecutiveCompletions >= 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.particleEmitter.emit(at: position, type: .sparkle, count: 15)
            }
        }
    }

    func celebrateUndo(at position: CGPoint) {
        rippleEffect.trigger(at: position, color: .systemOrange, maxRadius: 40)
        CelebrationSounds.shared.playUndo()
    }

    func update(deltaTime: CFTimeInterval) {
        particleEmitter.update(deltaTime: deltaTime)
        rippleEffect.update(deltaTime: deltaTime)
    }

    func draw(in context: CGContext) {
        rippleEffect.draw(in: context)
        particleEmitter.draw(in: context)
    }

    var hasActiveEffects: Bool {
        return particleEmitter.hasActiveParticles || rippleEffect.hasActiveRipple
    }
}
