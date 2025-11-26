import XCTest
@testable import SharedKit

final class SharedKitTests: XCTestCase {
    
    func testTaskModelCreation() {
        let task = TaskModel(
            title: "Test Task",
            isCompleted: false,
            details: "Test details",
            priority: 2
        )
        
        XCTAssertEqual(task.title, "Test Task")
        XCTAssertFalse(task.isCompleted)
        XCTAssertEqual(task.priority, 2)
        XCTAssertEqual(task.statusEnum, .outstanding)
    }
    
    func testTaskStatusEnum() {
        let task = TaskModel(title: "Test", status: 2)
        XCTAssertEqual(task.statusEnum, .inProgress)
        
        task.statusEnum = .complete
        XCTAssertEqual(task.status, 3)
    }
    
    func testOrbModelCreation() {
        let orb = OrbModel(
            name: "Test Orb",
            color: OrbColorPalette.colors[0]
        )
        
        XCTAssertEqual(orb.name, "Test Orb")
        XCTAssertEqual(orb.taskCount, 0)
        XCTAssert(orb.tasks.isEmpty)
    }
    
    func testOrbTaskManagement() {
        let orb = OrbModel(name: "Test Orb", color: OrbColorPalette.colors[0])
        let task1 = TaskModel(title: "Task 1")
        let task2 = TaskModel(title: "Task 2")
        
        orb.addTask(task1)
        XCTAssertEqual(orb.taskCount, 1)
        XCTAssertEqual(task1.sortOrder, 0.0)
        
        orb.addTask(task2)
        XCTAssertEqual(orb.taskCount, 2)
        XCTAssertEqual(task2.sortOrder, 1.0)
        
        _ = orb.removeTask(task1)
        XCTAssertEqual(orb.taskCount, 1)
        XCTAssertEqual(task2.sortOrder, 0.0)  // Should be reindexed
    }
    
    func testColorPalette() {
        let color = OrbColorPalette.getColor(for: 0)
        XCTAssertNotNil(color)
        
        // Test wrap-around
        let wrappedColor = OrbColorPalette.getColor(for: 100)
        XCTAssertNotNil(wrappedColor)
    }
    
    func testColorHexConversion() {
        let color = OrbColorPalette.colors[0]
        let hex = color.toHexString()
        XCTAssert(hex.hasPrefix("#"))
        XCTAssertEqual(hex.count, 7)
        
        let roundTrip = PlatformColor.fromHexString(hex)
        XCTAssertNotNil(roundTrip)
    }
    
    func testDebugLogCategory() {
        XCTAssertEqual(DebugCategory.app.tag, "APP")
        XCTAssertEqual(DebugCategory.sync.tag, "SYNC")
        XCTAssertEqual(DebugCategory.persistence.tag, "DATA")
    }
    
    func testSyncOutboxOperation() {
        XCTAssertEqual(SyncOutboxOperation.insert.name, "INSERT")
        XCTAssertEqual(SyncOutboxOperation.update.name, "UPDATE")
        XCTAssertEqual(SyncOutboxOperation.delete.name, "DELETE")
    }
}
