import Foundation

#if os(macOS)
import AppKit
typealias PlatformColor = NSColor
#else
import UIKit
typealias PlatformColor = UIColor
#endif

// MARK: - Orb Data Model (iOS-compatible)
class OrbModel: ObservableObject, Identifiable {
    let id: UUID
    let color: PlatformColor
    @Published var name: String
    @Published var taskCount: Int = 0
    @Published var tasks: [TaskModel] = []
    var sortOrder: Double = 0.0
    var createdAt: Date
    var updatedAt: Date?

    init(
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

    func addTask(_ task: TaskModel) {
        tasks.append(task)
        reindexTasks()
        taskCount = tasks.count
    }

    func removeTask(_ task: TaskModel) -> Int? {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return nil }
        tasks.remove(at: index)
        reindexTasks()
        taskCount = tasks.count
        return index
    }

    func insertTask(_ task: TaskModel, at index: Int) {
        tasks.insert(task, at: index)
        reindexTasks()
        taskCount = tasks.count
    }

    private func reindexTasks() {
        for (index, task) in tasks.enumerated() {
            task.sortOrder = Double(index)
        }
    }
}

// MARK: - Color Palette System
struct OrbColorPalette {
    static let colors: [PlatformColor] = [
        PlatformColor(red: 0.0, green: 0.6, blue: 1.0, alpha: 1.0),      // Bright Electric Blue
        PlatformColor(red: 1.0, green: 0.15, blue: 0.25, alpha: 1.0),    // Vibrant Crimson Red
        PlatformColor(red: 0.0, green: 1.0, blue: 0.4, alpha: 1.0),      // Luminous Emerald Green
        PlatformColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 1.0),     // Vivid Amber Orange
        PlatformColor(red: 0.75, green: 0.0, blue: 1.0, alpha: 1.0),     // Rich Royal Purple
        PlatformColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 1.0),     // Brilliant Cyan Blue
        PlatformColor(red: 1.0, green: 0.0, blue: 0.7, alpha: 1.0),      // Vibrant Magenta Pink
        PlatformColor(red: 1.0, green: 0.98, blue: 0.0, alpha: 1.0),     // Bright Golden Yellow
    ]

    static func getColor(for index: Int) -> PlatformColor {
        return colors[index % colors.count]
    }

    static func getUniqueColor(for orbIndex: Int) -> PlatformColor {
        return colors[orbIndex % colors.count]
    }
}

// MARK: - Color Extensions
extension PlatformColor {
    func toHexString() -> String {
        #if os(macOS)
        guard let rgb = usingColorSpace(.extendedSRGB) ?? usingColorSpace(.sRGB) else {
            return "#4F5FFF"
        }
        let r = Int(round(rgb.redComponent * 255.0))
        let g = Int(round(rgb.greenComponent * 255.0))
        let b = Int(round(rgb.blueComponent * 255.0))
        #else
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rInt = Int(round(r * 255.0))
        let gInt = Int(round(g * 255.0))
        let bInt = Int(round(b * 255.0))
        return String(format: "#%02X%02X%02X", rInt, gInt, bInt)
        #endif
        return String(format: "#%02X%02X%02X", r, g, b)
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
