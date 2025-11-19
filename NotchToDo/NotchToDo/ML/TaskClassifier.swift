import Foundation
import NaturalLanguage
import CoreData

/// Result of orb classification with confidence scores
struct OrbClassificationResult {
    let orb: ProjectOrb
    let confidence: Double
    let method: ClassificationMethod

    enum ClassificationMethod: String {
        case exactMatch = "Exact Match"
        case embedding = "Semantic Similarity"
        case keyword = "Keyword Match"
        case taskCount = "Load Balancing"
        case userFeedback = "User Preference"
    }
}

/// Suggestion for orb assignment with multiple candidates
struct OrbSuggestion {
    let topMatches: [OrbClassificationResult]
    let taskText: String
    let timestamp: Date

    var primarySuggestion: OrbClassificationResult? {
        topMatches.first
    }

    var hasHighConfidence: Bool {
        guard let primary = primarySuggestion else { return false }
        return primary.confidence > 0.7
    }
}

/// Main task classification service using ML embeddings and user feedback
final class TaskClassifier {
    static let shared = TaskClassifier()

    // MARK: - Configuration
    private let minimumConfidenceThreshold: Double = 0.15
    private let highConfidenceThreshold: Double = 0.7
    private let exactMatchBoost: Double = 0.95
    private let userFeedbackWeight: Double = 0.25
    private let embeddingWeight: Double = 0.50
    private let keywordWeight: Double = 0.15
    private let taskCountWeight: Double = 0.10

    // MARK: - Dependencies
    private let embedding: NLEmbedding?
    private let stopWords: Set<String>
    private var trainingDataManager: OrbTrainingDataManager
    private let embeddingGenerator: EmbeddingGenerator

    // MARK: - Cache
    private var orbEmbeddingCache: [UUID: [Double]] = [:]
    private var lastCacheUpdate: Date?
    private let cacheInvalidationInterval: TimeInterval = 300 // 5 minutes

    // MARK: - Initialization

    private init() {
        self.embedding = NLEmbedding.wordEmbedding(for: .english)
        self.stopWords = Set([
            "the", "a", "an", "to", "into", "my", "for", "and", "please", "could", "you",
            "me", "can", "would", "notch", "hey", "ok", "okay", "add", "create", "make",
            "start", "new", "task", "todo", "reminder", "item"
        ])
        self.trainingDataManager = OrbTrainingDataManager()
        self.embeddingGenerator = EmbeddingGenerator(
            embedding: embedding,
            stopWords: stopWords
        )

        DebugLog.log("TaskClassifier initialized with embedding: \(embedding != nil)", category: .ml)
    }

    // MARK: - Public API

    /// Classify a task and suggest the top N orbs
    func suggestOrbs(for taskText: String, orbs: [ProjectOrb], topN: Int = 3) -> OrbSuggestion {
        guard !orbs.isEmpty else {
            return OrbSuggestion(topMatches: [], taskText: taskText, timestamp: Date())
        }

        let normalized = taskText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var results: [OrbClassificationResult] = []

        // Refresh cache if needed
        refreshCacheIfNeeded(orbs: orbs)

        // 1. Check for exact orb name match
        if let exactMatch = findExactMatch(taskText: normalized, orbs: orbs) {
            results.append(exactMatch)
            DebugLog.log("Found exact match for '\(taskText)': \(exactMatch.orb.name)", category: .ml)
        }

        // 2. Check user feedback history
        let feedbackResults = classifyByUserFeedback(taskText: normalized, orbs: orbs)
        results.append(contentsOf: feedbackResults)

        // 3. Use embedding-based semantic similarity
        if let embeddingResults = classifyByEmbedding(taskText: normalized, orbs: orbs) {
            results.append(contentsOf: embeddingResults)
        }

        // 4. Keyword matching
        let keywordResults = classifyByKeywords(taskText: normalized, orbs: orbs)
        results.append(contentsOf: keywordResults)

        // 5. Load balancing (prefer orbs with fewer tasks)
        let balancingResults = classifyByTaskCount(orbs: orbs)
        results.append(contentsOf: balancingResults)

        // Combine and rank results
        let rankedResults = combineAndRankResults(results, orbs: orbs)
        let topMatches = Array(rankedResults.prefix(topN))

        DebugLog.log("""
            Task classification for '\(taskText)':
            - Total candidates: \(results.count)
            - Top match: \(topMatches.first?.orb.name ?? "none") (confidence: \(String(format: "%.2f", topMatches.first?.confidence ?? 0)))
            - Method: \(topMatches.first?.method.rawValue ?? "none")
            """, category: .ml)

        return OrbSuggestion(
            topMatches: topMatches,
            taskText: taskText,
            timestamp: Date()
        )
    }

    /// Record user feedback when they manually assign/move a task
    func recordFeedback(taskText: String, chosenOrb: ProjectOrb, rejectedOrbs: [ProjectOrb] = []) {
        trainingDataManager.recordExample(
            taskText: taskText,
            orbId: chosenOrb.id,
            orbName: chosenOrb.name,
            wasManualCorrection: !rejectedOrbs.isEmpty
        )

        DebugLog.log("""
            Recorded training example:
            - Task: '\(taskText)'
            - Chosen orb: \(chosenOrb.name)
            - Was correction: \(!rejectedOrbs.isEmpty)
            """, category: .ml)
    }

    /// Refresh the orb embedding cache
    func refreshOrbCache(orbs: [ProjectOrb]) {
        orbEmbeddingCache.removeAll()

        for orb in orbs {
            if let vector = embeddingGenerator.generateEmbedding(for: orb.name) {
                orbEmbeddingCache[orb.id] = vector
            }
        }

        lastCacheUpdate = Date()
        DebugLog.log("Refreshed orb embedding cache for \(orbs.count) orbs", category: .ml)
    }

    /// Prime cache for a single orb
    func primeCache(for orb: ProjectOrb) {
        if let vector = embeddingGenerator.generateEmbedding(for: orb.name) {
            orbEmbeddingCache[orb.id] = vector
        }
    }

    /// Clear all training data (for testing/reset)
    func clearTrainingData() {
        trainingDataManager.clearAllExamples()
        DebugLog.log("Cleared all training data", category: .ml)
    }

    /// Get training statistics
    func getTrainingStats() -> [UUID: Int] {
        return trainingDataManager.getExampleCounts()
    }

    // MARK: - Private Classification Methods

    private func findExactMatch(taskText: String, orbs: [ProjectOrb]) -> OrbClassificationResult? {
        for orb in orbs {
            let orbName = orb.name.lowercased()

            // Check if task text contains the full orb name
            if taskText.contains(orbName) {
                return OrbClassificationResult(
                    orb: orb,
                    confidence: exactMatchBoost,
                    method: .exactMatch
                )
            }
        }
        return nil
    }

    private func classifyByUserFeedback(taskText: String, orbs: [ProjectOrb]) -> [OrbClassificationResult] {
        let examples = trainingDataManager.getSimilarExamples(to: taskText, limit: 5)
        var orbScores: [UUID: (count: Int, totalSimilarity: Double)] = [:]

        for example in examples {
            guard let orb = orbs.first(where: { $0.id == example.orbId }) else { continue }

            let similarity = calculateTextSimilarity(taskText, example.taskText)

            if var existing = orbScores[orb.id] {
                existing.count += 1
                existing.totalSimilarity += similarity
                orbScores[orb.id] = existing
            } else {
                orbScores[orb.id] = (count: 1, totalSimilarity: similarity)
            }
        }

        return orbScores.compactMap { orbId, stats in
            guard let orb = orbs.first(where: { $0.id == orbId }) else { return nil }

            let avgSimilarity = stats.totalSimilarity / Double(stats.count)
            let frequencyBoost = min(0.2, Double(stats.count) * 0.05)
            let confidence = (avgSimilarity + frequencyBoost) * userFeedbackWeight

            return OrbClassificationResult(
                orb: orb,
                confidence: confidence,
                method: .userFeedback
            )
        }
    }

    private func classifyByEmbedding(taskText: String, orbs: [ProjectOrb]) -> [OrbClassificationResult]? {
        guard let taskEmbedding = embeddingGenerator.generateEmbedding(for: taskText, filterStopWords: true) else {
            return nil
        }

        var results: [OrbClassificationResult] = []

        for orb in orbs {
            guard let orbEmbedding = getOrbEmbedding(orb) else { continue }

            guard let similarity = cosineSimilarity(taskEmbedding, orbEmbedding) else { continue }

            // Boost score based on orb's task count (prefer orbs with more tasks, slightly)
            let taskCountBoost = min(0.05, log(Double(max(orb.taskCount, 1))) * 0.02)
            let confidence = (similarity + taskCountBoost) * embeddingWeight

            if confidence > minimumConfidenceThreshold {
                results.append(OrbClassificationResult(
                    orb: orb,
                    confidence: confidence,
                    method: .embedding
                ))
            }
        }

        return results.isEmpty ? nil : results
    }

    private func classifyByKeywords(taskText: String, orbs: [ProjectOrb]) -> [OrbClassificationResult] {
        var results: [OrbClassificationResult] = []

        for orb in orbs {
            let orbName = orb.name.lowercased()
            let orbTokens = orbName.split { !$0.isLetter }.map { String($0) }

            var score: Double = 0

            for token in orbTokens {
                if taskText.contains(token) {
                    score += 1.0
                } else if token.count >= 4 {
                    let prefix = String(token.prefix(3))
                    if taskText.contains(prefix) {
                        score += 0.3
                    }
                }
            }

            if score > 0 {
                let confidence = min(score / Double(orbTokens.count), 1.0) * keywordWeight
                results.append(OrbClassificationResult(
                    orb: orb,
                    confidence: confidence,
                    method: .keyword
                ))
            }
        }

        return results
    }

    private func classifyByTaskCount(orbs: [ProjectOrb]) -> [OrbClassificationResult] {
        guard !orbs.isEmpty else { return [] }

        let maxTasks = orbs.map { $0.taskCount }.max() ?? 1

        return orbs.map { orb in
            // Prefer orbs with fewer tasks (load balancing)
            let normalizedCount = Double(orb.taskCount) / Double(maxTasks)
            let confidence = (1.0 - normalizedCount) * taskCountWeight

            return OrbClassificationResult(
                orb: orb,
                confidence: confidence,
                method: .taskCount
            )
        }
    }

    private func combineAndRankResults(_ results: [OrbClassificationResult], orbs: [ProjectOrb]) -> [OrbClassificationResult] {
        // Group results by orb
        var orbScores: [UUID: [OrbClassificationResult]] = [:]

        for result in results {
            if orbScores[result.orb.id] != nil {
                orbScores[result.orb.id]?.append(result)
            } else {
                orbScores[result.orb.id] = [result]
            }
        }

        // Combine scores for each orb
        let combinedResults = orbScores.compactMap { orbId, orbResults -> OrbClassificationResult? in
            guard let orb = orbs.first(where: { $0.id == orbId }) else { return nil }

            // Sum all confidence scores
            let totalConfidence = orbResults.reduce(0.0) { $0 + $1.confidence }

            // Prefer the highest-confidence method
            let primaryMethod = orbResults.max(by: { $0.confidence < $1.confidence })?.method ?? .taskCount

            return OrbClassificationResult(
                orb: orb,
                confidence: min(totalConfidence, 1.0),
                method: primaryMethod
            )
        }

        // Sort by confidence
        return combinedResults.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Helper Methods

    private func getOrbEmbedding(_ orb: ProjectOrb) -> [Double]? {
        if let cached = orbEmbeddingCache[orb.id] {
            return cached
        }

        if let generated = embeddingGenerator.generateEmbedding(for: orb.name) {
            orbEmbeddingCache[orb.id] = generated
            return generated
        }

        return nil
    }

    private func refreshCacheIfNeeded(orbs: [ProjectOrb]) {
        guard let lastUpdate = lastCacheUpdate else {
            refreshOrbCache(orbs: orbs)
            return
        }

        if Date().timeIntervalSince(lastUpdate) > cacheInvalidationInterval {
            refreshOrbCache(orbs: orbs)
        }
    }

    private func calculateTextSimilarity(_ text1: String, _ text2: String) -> Double {
        let tokens1 = Set(text1.split { !$0.isLetter }.map { String($0) })
        let tokens2 = Set(text2.split { !$0.isLetter }.map { String($0) })

        let intersection = tokens1.intersection(tokens2)
        let union = tokens1.union(tokens2)

        guard !union.isEmpty else { return 0.0 }
        return Double(intersection.count) / Double(union.count)
    }

    private func cosineSimilarity(_ vec1: [Double], _ vec2: [Double]) -> Double? {
        guard vec1.count == vec2.count else { return nil }

        var dotProduct: Double = 0
        var magnitude1: Double = 0
        var magnitude2: Double = 0

        for i in 0..<vec1.count {
            dotProduct += vec1[i] * vec2[i]
            magnitude1 += vec1[i] * vec1[i]
            magnitude2 += vec2[i] * vec2[i]
        }

        let denominator = sqrt(magnitude1) * sqrt(magnitude2)
        guard denominator > 0.0001 else { return nil }

        return dotProduct / denominator
    }
}
