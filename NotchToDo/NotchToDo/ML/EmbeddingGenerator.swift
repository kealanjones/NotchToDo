import Foundation
import NaturalLanguage

/// Generates semantic embeddings for text using Apple's NLEmbedding
final class EmbeddingGenerator {
    private let embedding: NLEmbedding?
    private let stopWords: Set<String>
    private var embeddingCache: [String: [Double]] = [:]

    init(embedding: NLEmbedding?, stopWords: Set<String>) {
        self.embedding = embedding
        self.stopWords = stopWords
    }

    /// Generate an embedding vector for the given text
    func generateEmbedding(for text: String, filterStopWords: Bool = false) -> [Double]? {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check cache first
        let cacheKey = "\(normalized):\(filterStopWords)"
        if let cached = embeddingCache[cacheKey] {
            return cached
        }

        guard let embedding = embedding else {
            DebugLog.log("NLEmbedding not available", category: .ml)
            return nil
        }

        // Tokenize the text
        let rawTokens = tokenize(text: normalized)

        // Filter stop words if requested
        let tokens = filterStopWords ? rawTokens.filter { !stopWords.contains($0) } : rawTokens

        guard !tokens.isEmpty else {
            return nil
        }

        // Generate embeddings for each token and average them
        var vectorSum: [Double] = []
        var validTokenCount = 0

        for token in tokens {
            guard let tokenVector = embedding.vector(for: token) else {
                continue
            }

            if vectorSum.isEmpty {
                vectorSum = tokenVector
            } else if vectorSum.count == tokenVector.count {
                for i in 0..<vectorSum.count {
                    vectorSum[i] += tokenVector[i]
                }
            } else {
                continue
            }

            validTokenCount += 1
        }

        guard validTokenCount > 0 else {
            return nil
        }

        // Average the vectors
        let averagedVector = vectorSum.map { $0 / Double(validTokenCount) }

        // Cache the result
        embeddingCache[cacheKey] = averagedVector

        return averagedVector
    }

    /// Tokenize text into words
    private func tokenize(text: String) -> [String] {
        return text.split(whereSeparator: { !$0.isLetter })
            .map { String($0).lowercased() }
            .filter { !$0.isEmpty }
    }

    /// Clear the embedding cache
    func clearCache() {
        embeddingCache.removeAll()
    }

    /// Get cache statistics
    func getCacheStats() -> (count: Int, size: Int) {
        let count = embeddingCache.count
        let size = embeddingCache.values.reduce(0) { $0 + $1.count * MemoryLayout<Double>.size }
        return (count: count, size: size)
    }
}
