import Foundation

enum DebugCategory: CaseIterable, Hashable {
    case app
    case intent
    case speech
    case overlay
    case tasks
    case physics
    case persistence
    
    var displayName: String {
        switch self {
        case .app: return "App Lifecycle"
        case .intent: return "Intent Routing"
        case .speech: return "Speech & Voice"
        case .overlay: return "Overlay & UI"
        case .tasks: return "Tasks & Cards"
        case .physics: return "Physics"
        case .persistence: return "Persistence"
        }
    }
    
    var tag: String {
        switch self {
        case .app: return "APP"
        case .intent: return "INTENT"
        case .speech: return "SPEECH"
        case .overlay: return "OVERLAY"
        case .tasks: return "TASK"
        case .physics: return "PHYS"
        case .persistence: return "DATA"
        }
    }
    
    static var defaultEnabled: Set<DebugCategory> {
        return [.app, .intent, .speech, .overlay, .tasks, .persistence]
    }
}

final class DebugLogger {
    static let shared = DebugLogger()
    
    private let lock = NSLock()
    private var enabledCategories: Set<DebugCategory> = DebugCategory.defaultEnabled
    
    func setCategory(_ category: DebugCategory, enabled: Bool) {
        lock.lock()
        if enabled {
            enabledCategories.insert(category)
        } else {
            enabledCategories.remove(category)
        }
        lock.unlock()
    }
    
    func isEnabled(_ category: DebugCategory) -> Bool {
        lock.lock()
        let enabled = enabledCategories.contains(category)
        lock.unlock()
        return enabled
    }
    
    func allCategories() -> [DebugCategory] {
        return DebugCategory.allCases
    }
}

enum DebugLog {
    static func log(
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
