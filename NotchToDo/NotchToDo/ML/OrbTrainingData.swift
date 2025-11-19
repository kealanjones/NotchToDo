import Foundation
import CoreData

/// Represents a training example for orb classification
struct TrainingExample: Codable, Identifiable {
    let id: UUID
    let taskText: String
    let orbId: UUID
    let orbName: String
    let timestamp: Date
    let wasManualCorrection: Bool

    init(
        id: UUID = UUID(),
        taskText: String,
        orbId: UUID,
        orbName: String,
        timestamp: Date = Date(),
        wasManualCorrection: Bool = false
    ) {
        self.id = id
        self.taskText = taskText
        self.orbId = orbId
        self.orbName = orbName
        self.timestamp = timestamp
        self.wasManualCorrection = wasManualCorrection
    }
}

/// Manages training data for orb classification
final class OrbTrainingDataManager {
    private let userDefaultsKey = "OrbTrainingExamples"
    private let maxExamplesPerOrb = 100
    private let maxTotalExamples = 500

    private var examples: [TrainingExample] = []

    init() {
        loadExamples()
    }

    // MARK: - Public API

    /// Record a new training example
    func recordExample(
        taskText: String,
        orbId: UUID,
        orbName: String,
        wasManualCorrection: Bool = false
    ) {
        let example = TrainingExample(
            taskText: taskText,
            orbId: orbId,
            orbName: orbName,
            wasManualCorrection: wasManualCorrection
        )

        examples.append(example)

        // Trim if needed
        trimExamplesIfNeeded()

        saveExamples()

        DebugLog.log("""
            Recorded training example:
            - Task: '\(taskText)'
            - Orb: \(orbName) (\(orbId))
            - Manual correction: \(wasManualCorrection)
            - Total examples: \(examples.count)
            """, category: .ml)
    }

    /// Get similar examples to the given task text
    func getSimilarExamples(to taskText: String, limit: Int = 5) -> [TrainingExample] {
        let normalized = taskText.lowercased()

        // Calculate similarity scores
        let scored = examples.map { example -> (example: TrainingExample, score: Double) in
            let similarity = calculateSimilarity(normalized, example.taskText.lowercased())
            let recencyBoost = recencyWeight(for: example.timestamp)
            let correctionBoost = example.wasManualCorrection ? 0.2 : 0.0

            let totalScore = similarity + recencyBoost + correctionBoost

            return (example: example, score: totalScore)
        }

        // Sort by score and take top N
        return scored
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.example }
    }

    /// Get all examples for a specific orb
    func getExamples(for orbId: UUID) -> [TrainingExample] {
        return examples.filter { $0.orbId == orbId }
    }

    /// Get count of examples per orb
    func getExampleCounts() -> [UUID: Int] {
        var counts: [UUID: Int] = [:]

        for example in examples {
            counts[example.orbId, default: 0] += 1
        }

        return counts
    }

    /// Get total number of examples
    func getTotalExampleCount() -> Int {
        return examples.count
    }

    /// Clear all examples
    func clearAllExamples() {
        examples.removeAll()
        saveExamples()
        DebugLog.log("Cleared all training examples", category: .ml)
    }

    /// Clear examples for a specific orb
    func clearExamples(for orbId: UUID) {
        examples.removeAll { $0.orbId == orbId }
        saveExamples()
        DebugLog.log("Cleared training examples for orb \(orbId)", category: .ml)
    }

    /// Get training statistics
    func getStatistics() -> TrainingStatistics {
        let totalExamples = examples.count
        let examplesPerOrb = getExampleCounts()
        let manualCorrections = examples.filter { $0.wasManualCorrection }.count
        let oldestExample = examples.min(by: { $0.timestamp < $1.timestamp })?.timestamp
        let newestExample = examples.max(by: { $0.timestamp < $1.timestamp })?.timestamp

        return TrainingStatistics(
            totalExamples: totalExamples,
            examplesPerOrb: examplesPerOrb,
            manualCorrections: manualCorrections,
            oldestExampleDate: oldestExample,
            newestExampleDate: newestExample
        )
    }

    // MARK: - Private Methods

    private func loadExamples() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            DebugLog.log("No training examples found in UserDefaults", category: .ml)
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            examples = try decoder.decode([TrainingExample].self, from: data)
            DebugLog.log("Loaded \(examples.count) training examples", category: .ml)
        } catch {
            DebugLog.log("Failed to load training examples: \(error)", category: .ml)
            examples = []
        }
    }

    private func saveExamples() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(examples)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            DebugLog.log("Saved \(examples.count) training examples", category: .ml)
        } catch {
            DebugLog.log("Failed to save training examples: \(error)", category: .ml)
        }
    }

    private func trimExamplesIfNeeded() {
        // First, ensure we don't exceed the global limit
        if examples.count > maxTotalExamples {
            // Remove oldest examples
            examples.sort { $0.timestamp < $1.timestamp }
            let removeCount = examples.count - maxTotalExamples
            examples.removeFirst(removeCount)
            DebugLog.log("Trimmed \(removeCount) oldest examples to stay under limit", category: .ml)
        }

        // Then, ensure no orb has too many examples
        var orbCounts: [UUID: Int] = [:]

        for (index, example) in examples.enumerated().reversed() {
            orbCounts[example.orbId, default: 0] += 1

            if orbCounts[example.orbId]! > maxExamplesPerOrb {
                examples.remove(at: index)
            }
        }
    }

    private func calculateSimilarity(_ text1: String, _ text2: String) -> Double {
        let tokens1 = Set(tokenize(text1))
        let tokens2 = Set(tokenize(text2))

        let intersection = tokens1.intersection(tokens2)
        let union = tokens1.union(tokens2)

        guard !union.isEmpty else { return 0.0 }

        return Double(intersection.count) / Double(union.count)
    }

    private func tokenize(_ text: String) -> [String] {
        return text.split(whereSeparator: { !$0.isLetter })
            .map { String($0).lowercased() }
            .filter { !$0.isEmpty }
    }

    private func recencyWeight(for timestamp: Date) -> Double {
        let daysSince = Date().timeIntervalSince(timestamp) / 86400.0
        // Exponential decay: examples lose relevance over time
        // After 30 days, weight is ~0.05
        return exp(-daysSince / 30.0) * 0.1
    }
}

/// Statistics about the training data
struct TrainingStatistics {
    let totalExamples: Int
    let examplesPerOrb: [UUID: Int]
    let manualCorrections: Int
    let oldestExampleDate: Date?
    let newestExampleDate: Date?

    var description: String {
        var lines = [String]()
        lines.append("Total Examples: \(totalExamples)")
        lines.append("Manual Corrections: \(manualCorrections)")
        lines.append("Orbs with Examples: \(examplesPerOrb.count)")

        if let oldest = oldestExampleDate {
            lines.append("Oldest Example: \(oldest.formatted())")
        }

        if let newest = newestExampleDate {
            lines.append("Newest Example: \(newest.formatted())")
        }

        return lines.joined(separator: "\n")
    }
}
