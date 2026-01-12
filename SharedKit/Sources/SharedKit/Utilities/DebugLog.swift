import Foundation

public enum DebugCategory: CaseIterable, Hashable {
    case app
    case intent
    case speech
    case overlay
    case tasks
    case persistence
    case sync
    case physics  // Used by macOS for orb physics

    public var displayName: String {
        switch self {
        case .app: return "App Lifecycle"
        case .intent: return "Intent Routing"
        case .speech: return "Speech & Voice"
        case .overlay: return "Overlay & UI"
        case .tasks: return "Tasks & Cards"
        case .persistence: return "Persistence"
        case .sync: return "Sync"
        case .physics: return "Physics"
        }
    }

    public var tag: String {
        switch self {
        case .app: return "APP"
        case .intent: return "INTENT"
        case .speech: return "SPEECH"
        case .overlay: return "OVERLAY"
        case .tasks: return "TASK"
        case .persistence: return "DATA"
        case .sync: return "SYNC"
        case .physics: return "PHYSICS"
        }
    }

    public static var defaultEnabled: Set<DebugCategory> {
        return [.intent, .speech, .overlay, .sync, .persistence]
    }
}

public final class DebugLogger {
    public static let shared = DebugLogger()

    private let lock = NSLock()
    private var enabledCategories: Set<DebugCategory> = DebugCategory.defaultEnabled

    private init() {}

    public func setCategory(_ category: DebugCategory, enabled: Bool) {
        lock.lock()
        if enabled {
            enabledCategories.insert(category)
        } else {
            enabledCategories.remove(category)
        }
        lock.unlock()
    }

    public func isEnabled(_ category: DebugCategory) -> Bool {
        lock.lock()
        let enabled = enabledCategories.contains(category)
        lock.unlock()
        return enabled
    }

    public func allCategories() -> [DebugCategory] {
        return DebugCategory.allCases
    }
}

public enum DebugLog {
    public static func log(
        _ message: @autoclosure () -> String,
        category: DebugCategory,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        guard DebugLogger.shared.isEnabled(category) else { return }
        let text = message()
        print("[\(category.tag)] \(text)")
    }
}
