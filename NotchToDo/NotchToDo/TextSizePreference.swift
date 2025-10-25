import Foundation

/// Global text size preference for the app
/// Controls text size across task lists, detail views, and orb labels
class TextSizePreference {
    enum Size: String {
        case regular = "regular"
        case large = "large"

        var scaleFactor: CGFloat {
            switch self {
            case .regular:
                return 1.0
            case .large:
                return 1.3  // 30% larger
            }
        }
    }

    private static let userDefaultsKey = "textSizePreference"

    static var current: Size {
        get {
            let rawValue = UserDefaults.standard.string(forKey: userDefaultsKey) ?? Size.regular.rawValue
            return Size(rawValue: rawValue) ?? .regular
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: userDefaultsKey)
            // Post notification to update all views
            NotificationCenter.default.post(name: .textSizeDidChange, object: nil)
        }
    }

    static var scaleFactor: CGFloat {
        return current.scaleFactor
    }
}

extension Notification.Name {
    static let textSizeDidChange = Notification.Name("textSizeDidChange")
}
