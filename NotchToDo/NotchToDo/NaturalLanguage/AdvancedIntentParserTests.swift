import Foundation

/// Comprehensive test suite for AdvancedIntentParser
/// Run these tests to validate parser functionality
class AdvancedIntentParserTests {

    private let parser = AdvancedIntentParser()
    private let testOrbs = ["Kitchen", "Shopping", "Work", "Personal", "Fitness", "Home"]

    /// Run all tests and return results
    static func runAllTests() -> [TestResult] {
        let tester = AdvancedIntentParserTests()
        var results: [TestResult] = []

        // Test groups
        results.append(contentsOf: tester.testBasicTaskCreation())
        results.append(contentsOf: tester.testComplexCommands())
        results.append(contentsOf: tester.testDateParsing())
        results.append(contentsOf: tester.testPriorityExtraction())
        results.append(contentsOf: tester.testStatusExtraction())
        results.append(contentsOf: tester.testNotesExtraction())
        results.append(contentsOf: tester.testOrbTargeting())
        results.append(contentsOf: tester.testEdgeCases())

        return results
    }

    // MARK: - Test Groups

    func testBasicTaskCreation() -> [TestResult] {
        return [
            test(
                name: "Simple task creation",
                input: "add buy milk",
                expectedTitle: "Buy milk",
                expectedAction: .create
            ),
            test(
                name: "Create with 'new' keyword",
                input: "create new task call mom",
                expectedTitle: "Call mom",
                expectedAction: .create
            ),
            test(
                name: "Make a task",
                input: "make a task finish report",
                expectedTitle: "Finish report",
                expectedAction: .create
            )
        ]
    }

    func testComplexCommands() -> [TestResult] {
        return [
            test(
                name: "Complex command from requirement #1",
                input: "Add Create Lasagna to Kitchen orb, due on Friday and make sure that you add tomatoes and pasta to the notes",
                expectedTitle: "Create Lasagna",
                expectedOrb: "Kitchen",
                expectedAction: .create,
                expectedNotes: "add tomatoes and pasta",
                checkDueDate: true
            ),
            test(
                name: "Complex command from requirement #2",
                input: "Create a task called Buy groceries in Shopping orb with high priority due tomorrow at 3pm",
                expectedTitle: "Buy groceries",
                expectedOrb: "Shopping",
                expectedPriority: 3,
                expectedAction: .create,
                checkDueDate: true
            ),
            test(
                name: "Complex command from requirement #3",
                input: "Add Fix the sink to Home orb, in progress status, notes call plumber and buy new faucet",
                expectedTitle: "Fix the sink",
                expectedOrb: "Home",
                expectedStatus: 2,
                expectedNotes: "call plumber and buy new faucet",
                expectedAction: .create
            )
        ]
    }

    func testDateParsing() -> [TestResult] {
        return [
            test(
                name: "Due tomorrow",
                input: "add task buy milk due tomorrow",
                expectedTitle: "Buy milk",
                checkDueDate: true
            ),
            test(
                name: "Due next Friday",
                input: "add review PR due next Friday",
                expectedTitle: "Review PR",
                checkDueDate: true
            ),
            test(
                name: "Due in 3 days",
                input: "add call dentist due in 3 days",
                expectedTitle: "Call dentist",
                checkDueDate: true
            ),
            test(
                name: "Due with time",
                input: "add meeting due tomorrow at 3pm",
                expectedTitle: "Meeting",
                checkDueDate: true,
                checkDueTime: true
            )
        ]
    }

    func testPriorityExtraction() -> [TestResult] {
        return [
            test(
                name: "High priority with 'urgent'",
                input: "add urgent task fix server",
                expectedTitle: "Fix server",
                expectedPriority: 3
            ),
            test(
                name: "High priority with 'important'",
                input: "add important task review code",
                expectedTitle: "Review code",
                expectedPriority: 3
            ),
            test(
                name: "Low priority",
                input: "add low priority task organize desk",
                expectedTitle: "Organize desk",
                expectedPriority: 1
            ),
            test(
                name: "ASAP priority",
                input: "add asap fix bug",
                expectedTitle: "Fix bug",
                expectedPriority: 3
            )
        ]
    }

    func testStatusExtraction() -> [TestResult] {
        return [
            test(
                name: "In progress status",
                input: "add task working on report, in progress",
                expectedTitle: "Working on report",
                expectedStatus: 2
            ),
            test(
                name: "Complete status",
                input: "add task submit form, status complete",
                expectedTitle: "Submit form",
                expectedStatus: 3
            ),
            test(
                name: "Outstanding status (explicit)",
                input: "add outstanding task review document",
                expectedTitle: "Review document",
                expectedStatus: 1
            )
        ]
    }

    func testNotesExtraction() -> [TestResult] {
        return [
            test(
                name: "Notes with 'notes' keyword",
                input: "add task buy gift notes flowers or chocolates",
                expectedTitle: "Buy gift",
                expectedNotes: "flowers or chocolates"
            ),
            test(
                name: "Notes with 'make sure'",
                input: "add pack bags and make sure to include passport",
                expectedTitle: "Pack bags",
                expectedNotes: "include passport"
            ),
            test(
                name: "Notes with 'remember to'",
                input: "add call mom remember to ask about birthday",
                expectedTitle: "Call mom",
                expectedNotes: "ask about birthday"
            ),
            test(
                name: "Notes after 'and'",
                input: "add buy groceries and get extra milk",
                expectedTitle: "Buy groceries",
                expectedNotes: "get extra milk"
            )
        ]
    }

    func testOrbTargeting() -> [TestResult] {
        return [
            test(
                name: "Target orb with 'to'",
                input: "add task buy vegetables to Shopping",
                expectedTitle: "Buy vegetables",
                expectedOrb: "Shopping"
            ),
            test(
                name: "Target orb with 'in'",
                input: "add workout in Fitness orb",
                expectedTitle: "Workout",
                expectedOrb: "Fitness"
            ),
            test(
                name: "Target orb with 'for'",
                input: "add task review PR for Work",
                expectedTitle: "Review PR",
                expectedOrb: "Work"
            ),
            test(
                name: "Orb with suffix 'orb'",
                input: "add email boss to Work orb",
                expectedTitle: "Email boss",
                expectedOrb: "Work"
            )
        ]
    }

    func testEdgeCases() -> [TestResult] {
        return [
            test(
                name: "Title with 'and' in it",
                input: "add buy bread and butter",
                expectedTitle: "Buy bread and butter"
            ),
            test(
                name: "Multiple commas",
                input: "add task review code, fix bugs, deploy",
                expectedTitle: "Review code"
            ),
            test(
                name: "Empty after keyword",
                input: "add",
                shouldFail: true
            ),
            test(
                name: "Only action keyword",
                input: "create",
                shouldFail: true
            )
        ]
    }

    // MARK: - Test Execution

    private func test(
        name: String,
        input: String,
        expectedTitle: String? = nil,
        expectedOrb: String? = nil,
        expectedPriority: Int? = nil,
        expectedStatus: Int16? = nil,
        expectedNotes: String? = nil,
        expectedAction: TaskAction = .create,
        checkDueDate: Bool = false,
        checkDueTime: Bool = false,
        shouldFail: Bool = false
    ) -> TestResult {

        let result = parser.parse(input, availableOrbs: testOrbs)

        // Check if parsing should fail
        if shouldFail {
            return TestResult(
                name: name,
                input: input,
                passed: result == nil,
                details: result == nil ? "Correctly failed to parse" : "Should have failed but got: \(result!.title)"
            )
        }

        guard let intent = result else {
            return TestResult(
                name: name,
                input: input,
                passed: false,
                details: "Failed to parse (returned nil)"
            )
        }

        var failureReasons: [String] = []

        // Check title
        if let expectedTitle = expectedTitle {
            if intent.title != expectedTitle {
                failureReasons.append("Title mismatch: expected '\(expectedTitle)', got '\(intent.title)'")
            }
        }

        // Check orb
        if let expectedOrb = expectedOrb {
            if intent.targetOrb != expectedOrb {
                failureReasons.append("Orb mismatch: expected '\(expectedOrb)', got '\(intent.targetOrb ?? "nil")'")
            }
        }

        // Check priority
        if let expectedPriority = expectedPriority {
            if intent.priority != expectedPriority {
                failureReasons.append("Priority mismatch: expected \(expectedPriority), got \(intent.priority ?? 0)")
            }
        }

        // Check status
        if let expectedStatus = expectedStatus {
            if intent.status != expectedStatus {
                failureReasons.append("Status mismatch: expected \(expectedStatus), got \(intent.status ?? 0)")
            }
        }

        // Check notes
        if let expectedNotes = expectedNotes {
            if let actualNotes = intent.notes {
                if !actualNotes.lowercased().contains(expectedNotes.lowercased()) {
                    failureReasons.append("Notes mismatch: expected '\(expectedNotes)', got '\(actualNotes)'")
                }
            } else {
                failureReasons.append("Notes missing: expected '\(expectedNotes)', got nil")
            }
        }

        // Check action
        if intent.action != expectedAction {
            failureReasons.append("Action mismatch: expected \(expectedAction), got \(intent.action)")
        }

        // Check due date presence
        if checkDueDate && intent.dueDate == nil {
            failureReasons.append("Due date missing")
        }

        // Check due time presence
        if checkDueTime && intent.dueTime == nil {
            failureReasons.append("Due time missing")
        }

        let passed = failureReasons.isEmpty

        var details = "Title: '\(intent.title)'"
        if let orb = intent.targetOrb {
            details += ", Orb: \(orb)"
        }
        if let priority = intent.priority {
            details += ", Priority: \(priority)"
        }
        if let status = intent.status {
            details += ", Status: \(status)"
        }
        if let notes = intent.notes {
            details += ", Notes: '\(notes)'"
        }
        if intent.dueDate != nil {
            details += ", Has due date: Yes"
        }
        if !failureReasons.isEmpty {
            details += "\nFailures: \(failureReasons.joined(separator: "; "))"
        }

        return TestResult(
            name: name,
            input: input,
            passed: passed,
            details: details
        )
    }
}

// MARK: - Test Result

struct TestResult {
    let name: String
    let input: String
    let passed: Bool
    let details: String

    var description: String {
        let status = passed ? "✅ PASS" : "❌ FAIL"
        return "\(status) - \(name)\n   Input: '\(input)'\n   \(details)"
    }
}

// MARK: - Test Runner Extension

extension AdvancedIntentParserTests {
    static func printTestResults() {
        let results = runAllTests()

        let totalTests = results.count
        let passedTests = results.filter { $0.passed }.count
        let failedTests = totalTests - passedTests

        print("\n" + "=".repeating(80))
        print("ADVANCED INTENT PARSER TEST RESULTS")
        print("=".repeating(80) + "\n")

        for result in results {
            print(result.description)
            print("")
        }

        print("=".repeating(80))
        print("Summary: \(passedTests)/\(totalTests) passed, \(failedTests) failed")
        print("Pass rate: \(String(format: "%.1f", Float(passedTests) / Float(totalTests) * 100))%")
        print("=".repeating(80) + "\n")
    }
}
