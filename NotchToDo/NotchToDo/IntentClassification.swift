import Foundation
import NaturalLanguage
import CoreML

enum VoiceIntent: String {
    case createTask = "create_task"
    case createOrb = "create_orb"
    case showOverlay = "show_overlay"
    case clarification = "clarification"
    case unknown = "unknown"
}

struct VoiceIntentPrediction {
    enum Source {
        case coreML
        case heuristic
    }
    
    let intent: VoiceIntent
    let confidence: Double
    let label: String?
    let source: Source
}

final class IntentClassifier {
    static let shared = IntentClassifier()
    
    private let model: NLModel?
    private let minimumConfidence: Double = 0.38
    
    private let addVerbs: Set<String> = ["add", "create", "make", "start", "new"]
    private let openVerbs: Set<String> = ["open", "show", "reveal", "display", "bring"]
    private let orbKeywords: Set<String> = ["orb", "project", "workspace", "space"]
    private let taskKeywords: Set<String> = ["task", "tasks", "todo", "reminder", "item"]
    
    init(bundle: Bundle = .main) {
        model = IntentClassifier.loadModel(from: bundle)
    }
    
    func predictIntent(for text: String) -> VoiceIntentPrediction {
        let normalized = text.lowercased()
        
        if let model {
            let hypotheses = model.predictedLabelHypotheses(for: normalized, maximumCount: 4)
            if let top = hypotheses.max(by: { $0.value < $1.value }),
               let intent = VoiceIntent(rawValue: top.key),
               top.value >= minimumConfidence {
                return VoiceIntentPrediction(intent: intent, confidence: top.value, label: top.key, source: .coreML)
            }
        }
        
        return fallbackPrediction(for: normalized)
    }
}

private extension IntentClassifier {
    static func loadModel(from bundle: Bundle) -> NLModel? {
        if let compiledURL = bundle.url(forResource: "NotchIntentClassifier", withExtension: "mlmodelc") {
            return try? NLModel(contentsOf: compiledURL)
        }
        if let rawModelURL = bundle.url(forResource: "NotchIntentClassifier", withExtension: "mlmodel"),
           let compiledURL = try? MLModel.compileModel(at: rawModelURL) {
            return try? NLModel(contentsOf: compiledURL)
        }
        return nil
    }
    
    func fallbackPrediction(for text: String) -> VoiceIntentPrediction {
        let tokens = text.split { !$0.isLetter }.map { String($0) }
        let tokenSet = Set(tokens)
        
        let containsAdd = !addVerbs.isDisjoint(with: tokenSet)
        let containsOpen = !openVerbs.isDisjoint(with: tokenSet)
        let mentionsOrb = !orbKeywords.isDisjoint(with: tokenSet)
        let mentionsTask = !taskKeywords.isDisjoint(with: tokenSet)
        
        if containsAdd && mentionsOrb && mentionsTask {
            return VoiceIntentPrediction(intent: .clarification, confidence: 0.52, label: VoiceIntent.clarification.rawValue, source: .heuristic)
        }
        if containsAdd && mentionsOrb {
            return VoiceIntentPrediction(intent: .createOrb, confidence: 0.49, label: VoiceIntent.createOrb.rawValue, source: .heuristic)
        }
        if containsAdd && mentionsTask {
            return VoiceIntentPrediction(intent: .createTask, confidence: 0.47, label: VoiceIntent.createTask.rawValue, source: .heuristic)
        }
        if containsOpen && !mentionsTask && !mentionsOrb {
            return VoiceIntentPrediction(intent: .showOverlay, confidence: 0.45, label: VoiceIntent.showOverlay.rawValue, source: .heuristic)
        }
        if text == "open" {
            return VoiceIntentPrediction(intent: .showOverlay, confidence: 0.42, label: VoiceIntent.showOverlay.rawValue, source: .heuristic)
        }
        
        return VoiceIntentPrediction(intent: .unknown, confidence: 0.0, label: nil, source: .heuristic)
    }
}
