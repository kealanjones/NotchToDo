import XCTest
@testable import SharedKit

final class DataSnapshotsTests: XCTestCase {
    
    // MARK: - OrbSnapshot Tests
    
    func testOrbSnapshotInit() {
        let id = UUID()
        let now = Date()
        
        let snapshot = OrbSnapshot(
            id: id,
            name: "Work",
            colorHex: "#FF5733",
            sortOrder: 1.0,
            createdAt: now,
            updatedAt: now
        )
        
        XCTAssertEqual(snapshot.id, id)
        XCTAssertEqual(snapshot.name, "Work")
        XCTAssertEqual(snapshot.colorHex, "#FF5733")
        XCTAssertEqual(snapshot.sortOrder, 1.0)
        XCTAssertEqual(snapshot.createdAt, now)
        XCTAssertEqual(snapshot.updatedAt, now)
    }
    
    func testOrbSnapshotEquatable() {
        let id = UUID()
        let now = Date()
        
        let snapshot1 = OrbSnapshot(
            id: id,
            name: "Work",
            colorHex: "#FF5733",
            sortOrder: 1.0,
            createdAt: now,
            updatedAt: now
        )
        
        let snapshot2 = OrbSnapshot(
            id: id,
            name: "Work",
            colorHex: "#FF5733",
            sortOrder: 1.0,
            createdAt: now,
            updatedAt: now
        )
        
        XCTAssertEqual(snapshot1, snapshot2)
    }
    
    func testOrbSnapshotCodable() throws {
        let id = UUID()
        let now = Date()
        
        let snapshot = OrbSnapshot(
            id: id,
            name: "Work",
            colorHex: "#FF5733",
            sortOrder: 1.0,
            createdAt: now,
            updatedAt: now
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(snapshot)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(OrbSnapshot.self, from: data)
        
        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.name, "Work")
        XCTAssertEqual(decoded.colorHex, "#FF5733")
    }
    
    // MARK: - TaskSnapshot Tests
    
    func testTaskSnapshotInit() {
        let id = UUID()
        let orbId = UUID()
        let now = Date()
        let deadline = Date().addingTimeInterval(86400)
        
        let snapshot = TaskSnapshot(
            id: id,
            orbId: orbId,
            title: "Complete report",
            details: "Finish the quarterly report",
            priority: 3,
            status: 2,
            deadline: deadline,
            sortOrder: 0.0,
            isCompleted: false,
            createdAt: now,
            updatedAt: now
        )
        
        XCTAssertEqual(snapshot.id, id)
        XCTAssertEqual(snapshot.orbId, orbId)
        XCTAssertEqual(snapshot.title, "Complete report")
        XCTAssertEqual(snapshot.details, "Finish the quarterly report")
        XCTAssertEqual(snapshot.priority, 3)
        XCTAssertEqual(snapshot.status, 2)
        XCTAssertEqual(snapshot.deadline, deadline)
        XCTAssertEqual(snapshot.sortOrder, 0.0)
        XCTAssertFalse(snapshot.isCompleted)
    }
    
    func testTaskSnapshotMinimalInit() {
        let id = UUID()
        let orbId = UUID()
        let now = Date()
        
        let snapshot = TaskSnapshot(
            id: id,
            orbId: orbId,
            title: "Simple task",
            details: nil,
            priority: 1,
            status: 1,
            deadline: nil,
            sortOrder: 0.0,
            isCompleted: false,
            createdAt: now,
            updatedAt: now
        )
        
        XCTAssertNil(snapshot.details)
        XCTAssertNil(snapshot.deadline)
    }
    
    func testTaskSnapshotEquatable() {
        let id = UUID()
        let orbId = UUID()
        let now = Date()
        
        let snapshot1 = TaskSnapshot(
            id: id,
            orbId: orbId,
            title: "Task",
            details: nil,
            priority: 1,
            status: 1,
            deadline: nil,
            sortOrder: 0.0,
            isCompleted: false,
            createdAt: now,
            updatedAt: now
        )
        
        let snapshot2 = TaskSnapshot(
            id: id,
            orbId: orbId,
            title: "Task",
            details: nil,
            priority: 1,
            status: 1,
            deadline: nil,
            sortOrder: 0.0,
            isCompleted: false,
            createdAt: now,
            updatedAt: now
        )
        
        XCTAssertEqual(snapshot1, snapshot2)
    }
    
    func testTaskSnapshotCodable() throws {
        let id = UUID()
        let orbId = UUID()
        let now = Date()
        
        let snapshot = TaskSnapshot(
            id: id,
            orbId: orbId,
            title: "Task",
            details: "Details here",
            priority: 2,
            status: 1,
            deadline: nil,
            sortOrder: 1.5,
            isCompleted: false,
            createdAt: now,
            updatedAt: now
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(snapshot)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TaskSnapshot.self, from: data)
        
        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.orbId, orbId)
        XCTAssertEqual(decoded.title, "Task")
        XCTAssertEqual(decoded.details, "Details here")
        XCTAssertEqual(decoded.priority, 2)
    }
    
    // MARK: - Identifiable Tests
    
    func testOrbSnapshotIdentifiable() {
        let id = UUID()
        let snapshot = OrbSnapshot(
            id: id,
            name: "Test",
            colorHex: "#000000",
            sortOrder: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        XCTAssertEqual(snapshot.id, id)
    }
    
    func testTaskSnapshotIdentifiable() {
        let id = UUID()
        let snapshot = TaskSnapshot(
            id: id,
            orbId: UUID(),
            title: "Test",
            details: nil,
            priority: 1,
            status: 1,
            deadline: nil,
            sortOrder: 0,
            isCompleted: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        XCTAssertEqual(snapshot.id, id)
    }
}
