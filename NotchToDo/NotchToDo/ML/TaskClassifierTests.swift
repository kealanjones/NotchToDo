import Foundation

/// Test suite for TaskClassifier
final class TaskClassifierTests {
    private let classifier = TaskClassifier.shared

    // MARK: - Test Data

    private func createTestOrbs() -> [ProjectOrb] {
        return [
            ProjectOrb(name: "Work", color: .systemBlue),
            ProjectOrb(name: "Personal", color: .systemGreen),
            ProjectOrb(name: "Shopping", color: .systemOrange),
            ProjectOrb(name: "Fitness", color: .systemRed),
            ProjectOrb(name: "Learning", color: .systemPurple)
        ]
    }

    private func seedTrainingData() {
        let examples: [(String, String)] = [
            // Work examples
            ("Prepare presentation for Monday meeting", "Work"),
            ("Email client about project update", "Work"),
            ("Review pull requests", "Work"),
            ("Schedule team standup", "Work"),

            // Personal examples
            ("Call mom this weekend", "Personal"),
            ("Plan vacation for summer", "Personal"),
            ("Update resume", "Personal"),
            ("Pay electricity bill", "Personal"),

            // Shopping examples
            ("Buy groceries for dinner", "Shopping"),
            ("Order new running shoes", "Shopping"),
            ("Get birthday gift for Sarah", "Shopping"),
            ("Purchase printer paper", "Shopping"),

            // Fitness examples
            ("Go for a 5k run", "Fitness"),
            ("Attend yoga class", "Fitness"),
            ("Track daily calories", "Fitness"),
            ("Schedule gym session", "Fitness"),

            // Learning examples
            ("Complete Swift tutorial", "Learning"),
            ("Read chapter 5 of ML book", "Learning"),
            ("Watch CoreML video series", "Learning"),
            ("Practice algorithm problems", "Learning")
        ]

        let orbs = createTestOrbs()

        for (taskText, orbName) in examples {
            if let orb = orbs.first(where: { $0.name == orbName }) {
                classifier.recordFeedback(taskText: taskText, chosenOrb: orb)
            }
        }
    }

    // MARK: - Test Cases

    func runAllTests() -> [String: Bool] {
        var results: [String: Bool] = [:]

        // Clean slate
        classifier.clearTrainingData()

        results["testBasicClassification"] = testBasicClassification()
        results["testExactMatch"] = testExactMatch()
        results["testEmbeddingSimilarity"] = testEmbeddingSimilarity()
        results["testUserFeedbackLearning"] = testUserFeedbackLearning()
        results["testConfidenceScores"] = testConfidenceScores()
        results["testLoadBalancing"] = testLoadBalancing()
        results["testPerformance"] = testPerformance()

        return results
    }

    private func testBasicClassification() -> Bool {
        let orbs = createTestOrbs()
        classifier.refreshOrbCache(orbs: orbs)

        let suggestion = classifier.suggestOrbs(for: "Send work email to boss", orbs: orbs, topN: 3)

        guard let primary = suggestion.primarySuggestion else {
            DebugLog.log("Test failed: No primary suggestion", category: .ml)
            return false
        }

        let passed = suggestion.topMatches.count > 0
        DebugLog.log("""
            testBasicClassification: \(passed ? "PASSED" : "FAILED")
            - Task: 'Send work email to boss'
            - Top suggestion: \(primary.orb.name) (confidence: \(String(format: "%.2f", primary.confidence)))
            """, category: .ml)

        return passed
    }

    private func testExactMatch() -> Bool {
        let orbs = createTestOrbs()
        classifier.refreshOrbCache(orbs: orbs)

        let suggestion = classifier.suggestOrbs(for: "Add to shopping list", orbs: orbs, topN: 1)

        guard let primary = suggestion.primarySuggestion else {
            return false
        }

        let passed = primary.orb.name.lowercased().contains("shopping") && primary.confidence > 0.8

        DebugLog.log("""
            testExactMatch: \(passed ? "PASSED" : "FAILED")
            - Expected: Shopping orb with high confidence
            - Got: \(primary.orb.name) (confidence: \(String(format: "%.2f", primary.confidence)))
            """, category: .ml)

        return passed
    }

    private func testEmbeddingSimilarity() -> Bool {
        let orbs = createTestOrbs()
        classifier.refreshOrbCache(orbs: orbs)

        // Test semantic similarity without exact keyword match
        let suggestion = classifier.suggestOrbs(for: "Exercise at the gym", orbs: orbs, topN: 1)

        guard let primary = suggestion.primarySuggestion else {
            return false
        }

        // Should suggest Fitness orb based on semantic similarity
        let passed = primary.orb.name == "Fitness"

        DebugLog.log("""
            testEmbeddingSimilarity: \(passed ? "PASSED" : "FAILED")
            - Task: 'Exercise at the gym'
            - Expected: Fitness
            - Got: \(primary.orb.name) (method: \(primary.method.rawValue))
            """, category: .ml)

        return passed
    }

    private func testUserFeedbackLearning() -> Bool {
        let orbs = createTestOrbs()
        classifier.clearTrainingData()
        seedTrainingData()

        // Test if the classifier learns from examples
        let suggestion = classifier.suggestOrbs(for: "Prepare slides for client presentation", orbs: orbs, topN: 1)

        guard let primary = suggestion.primarySuggestion else {
            return false
        }

        let passed = primary.orb.name == "Work"

        DebugLog.log("""
            testUserFeedbackLearning: \(passed ? "PASSED" : "FAILED")
            - Task: 'Prepare slides for client presentation'
            - Expected: Work (learned from training data)
            - Got: \(primary.orb.name) (confidence: \(String(format: "%.2f", primary.confidence)))
            """, category: .ml)

        return passed
    }

    private func testConfidenceScores() -> Bool {
        let orbs = createTestOrbs()
        seedTrainingData()

        let suggestion = classifier.suggestOrbs(for: "Buy milk", orbs: orbs, topN: 3)

        guard let primary = suggestion.primarySuggestion else {
            return false
        }

        // Confidence should be between 0 and 1
        let validConfidence = primary.confidence >= 0.0 && primary.confidence <= 1.0

        // Top matches should be sorted by confidence
        var sortedByConfidence = true
        for i in 0..<(suggestion.topMatches.count - 1) {
            if suggestion.topMatches[i].confidence < suggestion.topMatches[i + 1].confidence {
                sortedByConfidence = false
                break
            }
        }

        let passed = validConfidence && sortedByConfidence

        DebugLog.log("""
            testConfidenceScores: \(passed ? "PASSED" : "FAILED")
            - Valid confidence range: \(validConfidence)
            - Sorted by confidence: \(sortedByConfidence)
            - Top 3: \(suggestion.topMatches.map { "\($0.orb.name)(\(String(format: "%.2f", $0.confidence)))" }.joined(separator: ", "))
            """, category: .ml)

        return passed
    }

    private func testLoadBalancing() -> Bool {
        var orbs = createTestOrbs()

        // Make one orb have many more tasks
        orbs[0].taskCount = 20
        orbs[1].taskCount = 2
        orbs[2].taskCount = 2
        orbs[3].taskCount = 2
        orbs[4].taskCount = 2

        let suggestion = classifier.suggestOrbs(for: "Random task", orbs: orbs, topN: 5)

        // The orb with fewer tasks should get some boost
        let orbsWithFewerTasks = suggestion.topMatches.filter { $0.orb.taskCount < 5 }

        let passed = !orbsWithFewerTasks.isEmpty

        DebugLog.log("""
            testLoadBalancing: \(passed ? "PASSED" : "FAILED")
            - Orbs with load balancing boost: \(orbsWithFewerTasks.count)
            - Task counts: \(orbs.map { "\($0.name)(\($0.taskCount))" }.joined(separator: ", "))
            """, category: .ml)

        return passed
    }

    private func testPerformance() -> Bool {
        let orbs = createTestOrbs()
        classifier.refreshOrbCache(orbs: orbs)
        seedTrainingData()

        let testTasks = [
            "Send email",
            "Buy groceries",
            "Go for a run",
            "Read a book",
            "Fix bug in code"
        ]

        let startTime = Date()

        for task in testTasks {
            _ = classifier.suggestOrbs(for: task, orbs: orbs, topN: 3)
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let avgLatency = (duration / Double(testTasks.count)) * 1000 // in milliseconds

        // Should be under 100ms per classification
        let passed = avgLatency < 100

        DebugLog.log("""
            testPerformance: \(passed ? "PASSED" : "FAILED")
            - Tasks classified: \(testTasks.count)
            - Total time: \(String(format: "%.2f", duration * 1000))ms
            - Average latency: \(String(format: "%.2f", avgLatency))ms
            - Target: <100ms
            """, category: .ml)

        return passed
    }

    // MARK: - Public Test Runner

    static func runTests() -> String {
        let tests = TaskClassifierTests()
        let results = tests.runAllTests()

        let passed = results.values.filter { $0 }.count
        let total = results.count

        var report = "Task Classifier Test Results\n"
        report += "============================\n\n"

        for (testName, result) in results.sorted(by: { $0.key < $1.key }) {
            let status = result ? "✓ PASSED" : "✗ FAILED"
            report += "\(status): \(testName)\n"
        }

        report += "\n"
        report += "Total: \(passed)/\(total) tests passed\n"

        if passed == total {
            report += "All tests passed!\n"
        } else {
            report += "Some tests failed. Check debug logs for details.\n"
        }

        return report
    }
}
