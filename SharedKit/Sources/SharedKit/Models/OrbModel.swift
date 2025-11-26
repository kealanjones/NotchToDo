import Foundation

#if canImport(Combine)
import Combine
#endif

#if os(macOS)
import AppKit
public typealias PlatformColor = NSColor
#else
import UIKit
public typealias PlatformColor = UIColor
#endif

// MARK: - Orb Data Model (Cross-platform)
public class OrbModel: ObservableObject, Identifiable {
    public let id: UUID
    public let color: PlatformColor
    @Published public var name: String
    @Published public var taskCount: Int = 0
    @Published public var tasks: [TaskModel] = []
    @Published public var sortOrder: Double = 0.0
    public let createdAt: Date  // Immutable - set once at creation
    @Published public var updatedAt: Date?
    
    /// Callback for change notifications (used by macOS for persistence)
    public var onChange: (() -> Void)?

    public init(
        id: UUID = UUID(),
        name: String,
        color: PlatformColor,
        createdAt: Date = Date(),
        sortOrder: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.taskCount = tasks.count
    }

    public func addTask(_ task: TaskModel) {
        tasks.append(task)
        reindexTasks()
        taskCount = tasks.count
        notifyChange()
    }

    public func removeTask(_ task: TaskModel) -> Int? {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return nil }
        tasks.remove(at: index)
        reindexTasks()
        taskCount = tasks.count
        notifyChange()
        return index
    }

    public func insertTask(_ task: TaskModel, at index: Int) {
        tasks.insert(task, at: index)
        reindexTasks()
        taskCount = tasks.count
        notifyChange()
    }

    private func reindexTasks() {
        for (index, task) in tasks.enumerated() {
            task.sortOrder = Double(index)
        }
    }
    
    /// Notify observers of changes (for macOS persistence integration)
    public func notifyChange() {
        onChange?()
    }
}

// MARK: - Color Palette System
public struct OrbColorPalette {
    public static let colors: [PlatformColor] = [
        PlatformColor(red: 0.0, green: 0.6, blue: 1.0, alpha: 1.0),      // Bright Electric Blue
        PlatformColor(red: 1.0, green: 0.15, blue: 0.25, alpha: 1.0),    // Vibrant Crimson Red
        PlatformColor(red: 0.0, green: 1.0, blue: 0.4, alpha: 1.0),      // Luminous Emerald Green
        PlatformColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 1.0),     // Vivid Amber Orange
        PlatformColor(red: 0.75, green: 0.0, blue: 1.0, alpha: 1.0),     // Rich Royal Purple
        PlatformColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 1.0),     // Brilliant Cyan Blue
        PlatformColor(red: 1.0, green: 0.0, blue: 0.7, alpha: 1.0),      // Vibrant Magenta Pink
        PlatformColor(red: 1.0, green: 0.98, blue: 0.0, alpha: 1.0),     // Bright Golden Yellow
    ]

    public static func getColor(for index: Int) -> PlatformColor {
        return colors[index % colors.count]
    }

    public static func getUniqueColor(for orbIndex: Int) -> PlatformColor {
        return colors[orbIndex % colors.count]
    }
}

// MARK: - Color Extensions
public extension PlatformColor {
    func toHexString() -> String {
        #if os(macOS)
        guard let rgb = usingColorSpace(.extendedSRGB) ?? usingColorSpace(.sRGB) else {
            return "#4F5FFF"
        }
        let r = Int(round(rgb.redComponent * 255.0))
        let g = Int(round(rgb.greenComponent * 255.0))
        let b = Int(round(rgb.blueComponent * 255.0))
        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rInt = Int(round(r * 255.0))
        let gInt = Int(round(g * 255.0))
        let bInt = Int(round(b * 255.0))
        return String(format: "#%02X%02X%02X", rInt, gInt, bInt)
        #endif
    }

    static func fromHexString(_ hex: String) -> PlatformColor? {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else {
            return nil
        }
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0
        #if os(macOS)
        return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
        #else
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
        #endif
    }
}
