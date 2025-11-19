import Foundation

/// Result of fuzzy orb matching
struct OrbMatchResult {
    let orbName: String
    let confidence: Float
    let matchType: MatchType

    enum MatchType: String {
        case exact = "Exact Match"
        case startsWith = "Starts With"
        case contains = "Contains"
        case fuzzy = "Fuzzy Match (Typo Tolerant)"
        case semantic = "Semantic Match (ML)"
    }
}

/// Fuzzy orb name matcher with typo tolerance using Levenshtein distance
class FuzzyOrbMatcher {

    /// Find the best matching orb name from available orbs
    /// Supports:
    /// - Exact matching
    /// - Prefix matching
    /// - Contains matching
    /// - Levenshtein distance for typo tolerance
    /// - Case-insensitive matching
    static func findBestMatch(_ query: String, in orbNames: [String]) -> OrbMatchResult? {
        guard !query.isEmpty, !orbNames.isEmpty else { return nil }

        // Normalize query
        let normalizedQuery = normalize(query)

        var bestMatch: OrbMatchResult?
        var bestConfidence: Float = 0.0

        for orbName in orbNames {
            let normalizedOrb = normalize(orbName)

            // 1. Check for exact match (highest confidence)
            if normalizedQuery == normalizedOrb {
                return OrbMatchResult(
                    orbName: orbName,
                    confidence: 1.0,
                    matchType: .exact
                )
            }

            // 2. Check if orb name starts with query (very high confidence)
            if normalizedOrb.hasPrefix(normalizedQuery) {
                let confidence: Float = 0.9
                if confidence > bestConfidence {
                    bestConfidence = confidence
                    bestMatch = OrbMatchResult(
                        orbName: orbName,
                        confidence: confidence,
                        matchType: .startsWith
                    )
                }
                continue
            }

            // 3. Check if query starts with orb name (high confidence)
            if normalizedQuery.hasPrefix(normalizedOrb) {
                let confidence: Float = 0.85
                if confidence > bestConfidence {
                    bestConfidence = confidence
                    bestMatch = OrbMatchResult(
                        orbName: orbName,
                        confidence: confidence,
                        matchType: .startsWith
                    )
                }
                continue
            }

            // 4. Check if orb name contains query (good confidence)
            if normalizedOrb.contains(normalizedQuery) {
                let confidence: Float = 0.7
                if confidence > bestConfidence {
                    bestConfidence = confidence
                    bestMatch = OrbMatchResult(
                        orbName: orbName,
                        confidence: confidence,
                        matchType: .contains
                    )
                }
                continue
            }

            // 5. Check if query contains orb name (good confidence)
            if normalizedQuery.contains(normalizedOrb) {
                let confidence: Float = 0.7
                if confidence > bestConfidence {
                    bestConfidence = confidence
                    bestMatch = OrbMatchResult(
                        orbName: orbName,
                        confidence: confidence,
                        matchType: .contains
                    )
                }
                continue
            }

            // 6. Use Levenshtein distance for fuzzy matching (typo tolerance)
            let distance = levenshteinDistance(normalizedQuery, normalizedOrb)
            let maxLength = max(normalizedQuery.count, normalizedOrb.count)

            // Calculate similarity score (0.0 to 1.0)
            let similarity = 1.0 - (Float(distance) / Float(maxLength))

            // Only consider if similarity is reasonably high
            if similarity > 0.6 {
                // Adjust confidence based on similarity
                let confidence = similarity * 0.6  // Max 0.6 confidence for fuzzy matches

                if confidence > bestConfidence {
                    bestConfidence = confidence
                    bestMatch = OrbMatchResult(
                        orbName: orbName,
                        confidence: confidence,
                        matchType: .fuzzy
                    )
                }
            }
        }

        return bestMatch
    }

    /// Find multiple matching orbs ranked by confidence
    static func findMatches(_ query: String, in orbNames: [String], topN: Int = 3) -> [OrbMatchResult] {
        guard !query.isEmpty, !orbNames.isEmpty else { return [] }

        let normalizedQuery = normalize(query)
        var matches: [OrbMatchResult] = []

        for orbName in orbNames {
            let normalizedOrb = normalize(orbName)

            // Calculate match for each orb
            if normalizedQuery == normalizedOrb {
                matches.append(OrbMatchResult(
                    orbName: orbName,
                    confidence: 1.0,
                    matchType: .exact
                ))
            } else if normalizedOrb.hasPrefix(normalizedQuery) {
                matches.append(OrbMatchResult(
                    orbName: orbName,
                    confidence: 0.9,
                    matchType: .startsWith
                ))
            } else if normalizedQuery.hasPrefix(normalizedOrb) {
                matches.append(OrbMatchResult(
                    orbName: orbName,
                    confidence: 0.85,
                    matchType: .startsWith
                ))
            } else if normalizedOrb.contains(normalizedQuery) || normalizedQuery.contains(normalizedOrb) {
                matches.append(OrbMatchResult(
                    orbName: orbName,
                    confidence: 0.7,
                    matchType: .contains
                ))
            } else {
                // Fuzzy match with Levenshtein distance
                let distance = levenshteinDistance(normalizedQuery, normalizedOrb)
                let maxLength = max(normalizedQuery.count, normalizedOrb.count)
                let similarity = 1.0 - (Float(distance) / Float(maxLength))

                if similarity > 0.6 {
                    matches.append(OrbMatchResult(
                        orbName: orbName,
                        confidence: similarity * 0.6,
                        matchType: .fuzzy
                    ))
                }
            }
        }

        // Sort by confidence and return top N
        return matches
            .sorted { $0.confidence > $1.confidence }
            .prefix(topN)
            .map { $0 }
    }

    // MARK: - Helper Methods

    /// Normalize orb name for comparison
    /// - Lowercase
    /// - Remove "orb" suffix
    /// - Remove "project" suffix
    /// - Trim whitespace
    private static func normalize(_ text: String) -> String {
        var normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common suffixes
        normalized = normalized.replacingOccurrences(of: " orb$", with: "", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: " project$", with: "", options: .regularExpression)

        return normalized
    }

    /// Calculate Levenshtein distance between two strings
    /// Returns the minimum number of single-character edits (insertions, deletions, substitutions)
    /// required to change one string into the other
    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count

        // Early return for edge cases
        if m == 0 { return n }
        if n == 0 { return m }

        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        // Initialize first row and column
        for i in 0...m {
            matrix[i][0] = i
        }
        for j in 0...n {
            matrix[0][j] = j
        }

        let s1Array = Array(s1)
        let s2Array = Array(s2)

        // Fill the matrix
        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1

                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // Deletion
                    matrix[i][j - 1] + 1,      // Insertion
                    matrix[i - 1][j - 1] + cost // Substitution
                )
            }
        }

        return matrix[m][n]
    }
}
