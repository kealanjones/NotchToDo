import Foundation

/// Extension to integrate ML-powered classification with OrbManager
extension OrbManager {
    /// Move a task to a different orb and record the feedback for ML training
    func moveTask(_ task: Task, from sourceOrb: ProjectOrb, to destinationOrb: ProjectOrb) {
        // Remove from source
        sourceOrb.deleteTask(task)

        // Add to destination via snapshot (addTask(_:Task) is private)
        let snapshot = TaskSnapshot(
            id: task.id,
            title: task.title,
            notes: task.details,
            isCompleted: task.isCompleted,
            priority: task.priority,
            status: task.status,
            createdAt: task.createdAt,
            dueDate: task.deadline,
            sortOrder: task.sortOrder
        )
        destinationOrb.addTask(from: snapshot)

        // Record feedback for ML training
        TaskClassifier.shared.recordFeedback(
            taskText: task.title,
            chosenOrb: destinationOrb,
            rejectedOrbs: [sourceOrb]
        )

        DebugLog.log("""
            Task moved with ML feedback:
            - Task: '\(task.title)'
            - From: \(sourceOrb.name)
            - To: \(destinationOrb.name)
            """, category: .ml)
    }

    /// Suggest orbs for a new task
    func suggestOrbs(for taskTitle: String, topN: Int = 3) -> OrbSuggestion {
        return TaskClassifier.shared.suggestOrbs(for: taskTitle, orbs: orbs, topN: topN)
    }

    /// Add a task with automatic orb selection
    func addTaskWithClassification(_ taskTitle: String) -> (orb: ProjectOrb, wasAutoAssigned: Bool) {
        let suggestion = suggestOrbs(for: taskTitle, topN: 1)

        if let primaryOrb = suggestion.primarySuggestion?.orb {
            primaryOrb.addTask(title: taskTitle)
            TaskClassifier.shared.recordFeedback(taskText: taskTitle, chosenOrb: primaryOrb)

            DebugLog.log("""
                Task auto-classified:
                - Task: '\(taskTitle)'
                - Orb: \(primaryOrb.name)
                - Confidence: \(String(format: "%.2f", suggestion.primarySuggestion?.confidence ?? 0))
                """, category: .ml)

            return (orb: primaryOrb, wasAutoAssigned: true)
        }

        // Fallback: use dedicated "Captured Tasks" orb for uncategorized tasks
        let fallbackOrb = findOrCreateCapturedTasksOrb()
        fallbackOrb.addTask(title: taskTitle)
        TaskClassifier.shared.recordFeedback(taskText: taskTitle, chosenOrb: fallbackOrb)

        DebugLog.log("""
            Task assigned to fallback orb:
            - Task: '\(taskTitle)'
            - Orb: \(fallbackOrb.name)
            """, category: .ml)

        return (orb: fallbackOrb, wasAutoAssigned: false)
    }

    /// Refresh ML embeddings cache when orbs change
    func refreshMLCache() {
        TaskClassifier.shared.refreshOrbCache(orbs: orbs)
    }

    /// Get ML training statistics
    func getMLStatistics() -> TrainingStatistics {
        let manager = OrbTrainingDataManager()
        return manager.getStatistics()
    }
}
