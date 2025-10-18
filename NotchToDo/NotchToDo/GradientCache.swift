import Cocoa
import QuartzCore

final class GradientCache {
    static let shared = GradientCache()

    private struct CachedGradient {
        let gradient: CGGradient
        let colors: [CGColor]
    }

    private let lock = NSLock()
    private var cache: [GradientKey: CachedGradient] = [:]

    private init() {}

    func gradient(colors: [NSColor], locations: [CGFloat]) -> CGGradient? {
        cachedEntry(colors: colors, locations: locations)?.gradient
    }

    func gradient(cgColors: [CGColor], locations: [CGFloat]) -> CGGradient? {
        cachedEntry(cgColors: cgColors, locations: locations)?.gradient
    }

    func gradientColors(colors: [NSColor], locations: [CGFloat]) -> [CGColor]? {
        cachedEntry(colors: colors, locations: locations)?.colors
    }

    func gradientColors(cgColors: [CGColor], locations: [CGFloat]) -> [CGColor]? {
        cachedEntry(cgColors: cgColors, locations: locations)?.colors
    }

    private func cachedEntry(colors: [NSColor], locations: [CGFloat]) -> CachedGradient? {
        guard colors.count == locations.count else { return nil }
        guard let key = GradientKey(colors: colors, locations: locations) else { return nil }

        lock.lock()
        if let existing = cache[key] {
            lock.unlock()
            return existing
        }

        var cgColors: [CGColor] = []
        cgColors.reserveCapacity(colors.count)

        for color in colors {
            guard let converted = color.usingColorSpace(.deviceRGB) ?? color.usingColorSpace(.sRGB) else {
                lock.unlock()
                return nil
            }
            cgColors.append(converted.cgColor)
        }

        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: cgColors as CFArray,
            locations: locations
        ) else {
            lock.unlock()
            return nil
        }

        let entry = CachedGradient(gradient: gradient, colors: cgColors)
        cache[key] = entry
        lock.unlock()
        return entry
    }

    private func cachedEntry(cgColors: [CGColor], locations: [CGFloat]) -> CachedGradient? {
        let nsColors = cgColors.compactMap { NSColor(cgColor: $0) }
        guard nsColors.count == cgColors.count else { return nil }
        return cachedEntry(colors: nsColors, locations: locations)
    }
}

private struct GradientKey: Hashable {
    private let colors: [ColorComponents]
    private let locations: [Double]

    init?(colors: [NSColor], locations: [CGFloat]) {
        var components: [ColorComponents] = []
        components.reserveCapacity(colors.count)

        for color in colors {
            guard let converted = color.usingColorSpace(.deviceRGB) ?? color.usingColorSpace(.sRGB) else {
                return nil
            }
            components.append(ColorComponents(color: converted))
        }

        self.colors = components
        self.locations = locations.map { Double($0) }
    }
}

private struct ColorComponents: Hashable {
    let r: Double
    let g: Double
    let b: Double
    let a: Double

    init(color: NSColor) {
        self.r = Double(color.redComponent)
        self.g = Double(color.greenComponent)
        self.b = Double(color.blueComponent)
        self.a = Double(color.alphaComponent)
    }
}
