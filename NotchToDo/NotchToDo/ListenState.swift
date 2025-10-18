import Foundation

enum ListenState: Equatable {
    case idle
    case wake
    case listening
    case transcribing
    case error(String)
}
