# 🔧 NotchToDo Fix Task List

**Total Estimated Time:** 40-60 hours  
**Priority Levels:** P0 (Critical), P1 (High), P2 (Medium), P3 (Low)

---

## Phase 1: Critical Fixes (P0) - ~12 hours

### Task 1.1: Fix Android API Query Parameters
**Priority:** P0 | **Time:** 2 hours | **Risk:** High (broken functionality)

**Files to modify:**
- `NotchToDo-Android/app/src/main/java/com/notchtodo/data/remote/SupabaseApi.kt`

**Steps:**
1. [ ] Open `SupabaseApi.kt`
2. [ ] Fix `getTask()` method - change from separate `@Query("id")` and `@Query("eq")` to single filter parameter
3. [ ] Fix `getOrb()` method - same issue
4. [ ] Fix `getTasksByOrb()` method - same issue
5. [ ] Update all callers in `TaskRepository.kt` to pass `"eq.${id}"` format
6. [ ] Update all callers in `OrbRepository.kt` to pass `"eq.${id}"` format
7. [ ] Test API calls work correctly

**Code change:**
```kotlin
// Before:
@GET("rest/v1/tasks")
suspend fun getTask(
    @Query("id") id: String,
    @Query("eq") eq: String = id,
    @Query("select") select: String = "*"
): Response<List<TaskDto>>

// After:
@GET("rest/v1/tasks")
suspend fun getTask(
    @Query("id") idFilter: String,  // Pass "eq.{uuid}"
    @Query("select") select: String = "*"
): Response<List<TaskDto>>
```

---

### Task 1.2: Fix Thread Safety in SupabaseAuthManager
**Priority:** P0 | **Time:** 2 hours | **Risk:** High (race conditions)

**Files to modify:**
- `NotchToDo/NotchToDo/Supabase/SupabaseAuthManager.swift`
- `NotchToDo-iOS/Shared/Services/SupabaseAuthManager.swift`

**Steps:**
1. [ ] Add `NSLock` property for thread-safe session access
2. [ ] Create private backing storage `_currentSession`
3. [ ] Implement thread-safe getter with lock
4. [ ] Implement thread-safe setter with lock
5. [ ] Ensure notification is posted on main thread
6. [ ] Apply same fix to iOS version
7. [ ] Test concurrent access scenarios

**Code change:**
```swift
private let sessionLock = NSLock()
private var _currentSession: Session?

private(set) var currentSession: Session? {
    get {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        return _currentSession
    }
    set {
        sessionLock.lock()
        let oldValue = _currentSession
        _currentSession = newValue
        sessionLock.unlock()
        
        guard oldValue?.accessToken != newValue?.accessToken else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .supabaseAuthSessionChanged, object: newValue)
        }
    }
}
```

---

### Task 1.3: Fix Unreachable Code in iOS OrbModel
**Priority:** P0 | **Time:** 30 min | **Risk:** Low (dead code)

**Files to modify:**
- `NotchToDo-iOS/Shared/Models/OrbModel.swift`

**Steps:**
1. [ ] Open `OrbModel.swift`
2. [ ] Locate `toHexString()` function (line ~88-104)
3. [ ] Remove the unreachable `return` statement after `#endif`
4. [ ] Verify the `#if os(macOS)` block has its own return
5. [ ] Verify the `#else` block has its own return
6. [ ] Build and test on both platforms

**Code change:**
```swift
// Before (line 104):
    #endif
    return String(format: "#%02X%02X%02X", r, g, b)  // DELETE THIS LINE
}

// After:
    #endif
}
```

---

### Task 1.4: Add Missing @Published Wrappers in iOS OrbModel
**Priority:** P0 | **Time:** 1 hour | **Risk:** Medium (UI not updating)

**Files to modify:**
- `NotchToDo-iOS/Shared/Models/OrbModel.swift`

**Steps:**
1. [ ] Open `OrbModel.swift`
2. [ ] Add `@Published` to `sortOrder` property (line 18)
3. [ ] Evaluate if `createdAt` should change - if yes, add `@Published`; if no, make it `let`
4. [ ] Evaluate if `updatedAt` should change - if yes, add `@Published`
5. [ ] Build and verify no compile errors
6. [ ] Test that UI updates when these properties change

**Code change:**
```swift
// Before:
var sortOrder: Double = 0.0
var createdAt: Date
var updatedAt: Date?

// After:
@Published var sortOrder: Double = 0.0
let createdAt: Date  // Or @Published if it changes
@Published var updatedAt: Date?
```

---

### Task 1.5: Eliminate Code Duplication (Create Shared Package)
**Priority:** P0 | **Time:** 6 hours | **Risk:** Medium (refactoring)

**Steps:**
1. [ ] Create new directory `SharedKit/` at workspace root
2. [ ] Create `Package.swift` for Swift Package
3. [ ] Move shared models:
   - [ ] Create `SharedKit/Sources/SharedKit/Models/`
   - [ ] Move `TaskModel.swift` (merge iOS/macOS versions)
   - [ ] Move `OrbModel.swift` (merge iOS/macOS versions)
   - [ ] Move `DataSnapshots.swift`
4. [ ] Move shared services:
   - [ ] Create `SharedKit/Sources/SharedKit/Services/`
   - [ ] Move `SupabaseService.swift` (merge iOS/macOS versions)
   - [ ] Move `SupabaseAuthManager.swift` (merge iOS/macOS versions)
5. [ ] Move shared utilities:
   - [ ] Create `SharedKit/Sources/SharedKit/Utilities/`
   - [ ] Move `KeychainHelper.swift`
   - [ ] Move `DebugLog.swift`
6. [ ] Update Xcode projects to use SharedKit package
7. [ ] Remove duplicate files from individual targets
8. [ ] Build and test both platforms

**Package.swift template:**
```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SharedKit",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "SharedKit", targets: ["SharedKit"]),
    ],
    targets: [
        .target(name: "SharedKit", dependencies: []),
        .testTarget(name: "SharedKitTests", dependencies: ["SharedKit"]),
    ]
)
```

---

## Phase 2: High Priority Fixes (P1) - ~10 hours

### Task 2.1: Add Input Validation
**Priority:** P1 | **Time:** 2 hours | **Risk:** Medium (security)

**Files to modify:**
- `NotchToDo/NotchToDo/Security/InputValidator.swift` (expand)
- `NotchToDo/NotchToDo/Models/OrbModels.swift`

**Steps:**
1. [ ] Expand `InputValidator.swift` with validation methods:
   - [ ] `validateTaskTitle(_ title: String) -> String`
   - [ ] `validateOrbName(_ name: String) -> String`
   - [ ] `validateNotes(_ notes: String) -> String`
   - [ ] `sanitizeForExport(_ text: String) -> String`
2. [ ] Add max length constants (e.g., title: 500, notes: 10000)
3. [ ] Update `ProjectOrb.addTask(title:)` to validate input
4. [ ] Update `OrbManager.createOrb(name:)` to validate input
5. [ ] Update task detail view to validate before save
6. [ ] Add unit tests for validation edge cases

---

### Task 2.2: Fix Inefficient Task Reindexing
**Priority:** P1 | **Time:** 1.5 hours | **Risk:** Low

**Files to modify:**
- `NotchToDo/NotchToDo/Models/OrbModels.swift`

**Steps:**
1. [ ] Add `silent` parameter to `reindexTasks(silent: Bool = false)`
2. [ ] When `silent=true`, temporarily remove onChange handlers
3. [ ] Update `addTask()` to call `reindexTasks(silent: true)`
4. [ ] Update `removeTask()` to call `reindexTasks(silent: true)`
5. [ ] Update `insertTask()` to call `reindexTasks(silent: true)`
6. [ ] Call `notifyChange()` only once after reindexing
7. [ ] Test that persistence still saves correctly

---

### Task 2.3: Replace Blocking Dispatch with Async/Await
**Priority:** P1 | **Time:** 3 hours | **Risk:** Medium

**Files to modify:**
- `NotchToDo/NotchToDo/Supabase/SupabaseSyncManager.swift`

**Steps:**
1. [ ] Remove `awaitResult()` helper function
2. [ ] Convert `fetchAndMergeRemote()` to async function
3. [ ] Update `pullRemoteChanges()` to use Task { } for async calls
4. [ ] Convert `processOutboxBatch()` to not block
5. [ ] Ensure state updates happen on appropriate queues
6. [ ] Test sync operations don't freeze UI
7. [ ] Add timeout handling for long operations

---

### Task 2.4: Add Database Indices for Soft Deletes
**Priority:** P1 | **Time:** 1 hour | **Risk:** Low

**Files to create/modify:**
- `supabase/migrations/YYYYMMDD_add_soft_delete_indices.sql`

**Steps:**
1. [ ] Create new migration file
2. [ ] Add partial index for tasks: `CREATE INDEX idx_tasks_active ON public.tasks(user_id) WHERE deleted_at IS NULL;`
3. [ ] Add partial index for orbs: `CREATE INDEX idx_orbs_active ON public.orbs(user_id) WHERE deleted_at IS NULL;`
4. [ ] Add index for deleted_at column for cleanup queries
5. [ ] Run migration locally and test
6. [ ] Deploy to staging/production

**Migration content:**
```sql
-- Add indices for soft delete queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_active 
ON public.tasks(user_id, sort_order) 
WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orbs_active 
ON public.orbs(user_id, sort_order) 
WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_deleted_at 
ON public.tasks(deleted_at) 
WHERE deleted_at IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orbs_deleted_at 
ON public.orbs(deleted_at) 
WHERE deleted_at IS NOT NULL;
```

---

### Task 2.5: Replace Timer with CADisplayLink for Animations
**Priority:** P1 | **Time:** 2.5 hours | **Risk:** Medium

**Files to modify:**
- `NotchToDo/NotchToDo/Models/OrbModels.swift`

**Steps:**
1. [ ] Add `CADisplayLink` property to `OrbManager`
2. [ ] Create `startAnimationLoop()` method
3. [ ] Create `stopAnimationLoop()` method
4. [ ] Replace all `Timer.scheduledTimer` calls with display link callbacks
5. [ ] Update `animateOrbGrowth()` to use display link
6. [ ] Update `animateOrbRepositioning()` to use display link
7. [ ] Ensure proper cleanup in `deinit`
8. [ ] Test animation smoothness

---

## Phase 3: Medium Priority Fixes (P2) - ~8 hours

### Task 3.1: Extract Magic Numbers to Configuration
**Priority:** P2 | **Time:** 1.5 hours | **Risk:** Low

**Files to modify:**
- Create `NotchToDo/NotchToDo/Config/PhysicsConfig.swift`
- Create `NotchToDo/NotchToDo/Config/SyncConfig.swift`
- Update `OrbModels.swift`
- Update `SupabaseSyncManager.swift`

**Steps:**
1. [ ] Create `PhysicsConfig.swift` with constants
2. [ ] Create `SyncConfig.swift` with constants
3. [ ] Replace hardcoded values in `OrbModels.swift`
4. [ ] Replace hardcoded values in `SupabaseSyncManager.swift`
5. [ ] Document each constant's purpose

---

### Task 3.2: Consolidate Duplicate formatISO8601 in Android
**Priority:** P2 | **Time:** 1 hour | **Risk:** Low

**Files to modify:**
- Create `NotchToDo-Android/app/src/main/java/com/notchtodo/util/DateUtils.kt`
- Update `TaskRepository.kt`
- Update `OrbRepository.kt`

**Steps:**
1. [ ] Create `DateUtils.kt` with shared date formatting
2. [ ] Move `formatISO8601()` to `DateUtils`
3. [ ] Update `TaskRepository` to use `DateUtils.formatISO8601()`
4. [ ] Update `OrbRepository` to use `DateUtils.formatISO8601()`
5. [ ] Add `parseISO8601()` for parsing dates from API
6. [ ] Add unit tests

---

### Task 3.3: Optimize noteCount Calculation with Caching
**Priority:** P2 | **Time:** 1 hour | **Risk:** Low

**Files to modify:**
- `NotchToDo-iOS/Shared/Models/TaskModel.swift`
- `NotchToDo/NotchToDo/Models/OrbModels.swift`

**Steps:**
1. [ ] Add private `_cachedNoteCount: Int?` property
2. [ ] Invalidate cache when `details` changes
3. [ ] Return cached value if available
4. [ ] Calculate and cache on first access
5. [ ] Apply to both iOS and macOS versions
6. [ ] Test performance improvement

---

### Task 3.4: Add Retry Logic to Android Sync
**Priority:** P2 | **Time:** 2 hours | **Risk:** Medium

**Files to modify:**
- `NotchToDo-Android/app/src/main/java/com/notchtodo/data/repository/TaskRepository.kt`
- `NotchToDo-Android/app/src/main/java/com/notchtodo/data/repository/OrbRepository.kt`

**Steps:**
1. [ ] Create `RetryPolicy` data class with max attempts, delays
2. [ ] Create `withRetry()` suspend function wrapper
3. [ ] Update `syncTaskToRemote()` to use retry
4. [ ] Update `syncOrbToRemote()` to use retry
5. [ ] Add exponential backoff (1s, 2s, 4s)
6. [ ] Log retry attempts
7. [ ] Test with network failures

---

### Task 3.5: Fix Memory Leak in Timer Closures
**Priority:** P2 | **Time:** 1.5 hours | **Risk:** Medium

**Files to modify:**
- `NotchToDo/NotchToDo/Models/OrbModels.swift`

**Steps:**
1. [ ] Search for all `Timer.scheduledTimer` usages
2. [ ] Add `[weak self]` to all timer closures
3. [ ] Add guard for nil self with timer invalidation
4. [ ] Review other closure-based APIs for same issue
5. [ ] Test that orbs deallocate properly
6. [ ] Use Instruments to verify no leaks

---

### Task 3.6: Add Additional Database Indices
**Priority:** P2 | **Time:** 1 hour | **Risk:** Low

**Files to create:**
- `supabase/migrations/YYYYMMDD_add_query_indices.sql`

**Steps:**
1. [ ] Create migration file
2. [ ] Add index for `is_completed`
3. [ ] Add index for `priority`
4. [ ] Add index for `due_date`
5. [ ] Add composite index for common query patterns
6. [ ] Run migration and test query performance

---

## Phase 4: Optimization Tasks (P3) - ~10 hours

### Task 4.1: Batch Core Data Operations
**Priority:** P3 | **Time:** 2 hours | **Risk:** Low

**Files to modify:**
- `NotchToDo/NotchToDo/Persistence/OrbPersistenceStore.swift`

**Steps:**
1. [ ] Wrap all entity updates in single `performAndWait` block
2. [ ] Move `context.save()` to end of batch
3. [ ] Add batch size limits for very large syncs
4. [ ] Test with large data sets

---

### Task 4.2: Implement Lazy Loading in iOS TasksView
**Priority:** P3 | **Time:** 2 hours | **Risk:** Low

**Files to modify:**
- `NotchToDo-iOS/NotchToDo-iOS/Views/TasksView.swift`

**Steps:**
1. [ ] Replace computed `allTasks` with `@State` property
2. [ ] Add task observer to refresh when data changes
3. [ ] Implement pagination for large lists
4. [ ] Add loading indicator
5. [ ] Test scroll performance

---

### Task 4.3: Configure Android Connection Pooling
**Priority:** P3 | **Time:** 1 hour | **Risk:** Low

**Files to modify:**
- `NotchToDo-Android/app/src/main/java/com/notchtodo/di/AppModule.kt`

**Steps:**
1. [ ] Add ConnectionPool to OkHttpClient builder
2. [ ] Configure pool size (5 connections, 5 min keepalive)
3. [ ] Add connection timeout settings
4. [ ] Test network performance

---

### Task 4.4: Add Unit Tests for Critical Components
**Priority:** P3 | **Time:** 5 hours | **Risk:** Low

**Files to create:**
- `NotchToDo/NotchToDo/Tests/SupabaseSyncManagerTests.swift`
- `NotchToDo/NotchToDo/Tests/OrbPersistenceStoreTests.swift`
- `NotchToDo/NotchToDo/Tests/InputValidatorTests.swift`

**Steps:**
1. [ ] Create test target if not exists
2. [ ] Write tests for `SupabaseSyncManager`:
   - [ ] Test token extraction from JWT
   - [ ] Test outbox processing order
   - [ ] Test conflict resolution
3. [ ] Write tests for `OrbPersistenceStore`:
   - [ ] Test save/load roundtrip
   - [ ] Test delete all data
   - [ ] Test concurrent access
4. [ ] Write tests for `InputValidator`:
   - [ ] Test title validation
   - [ ] Test length limits
   - [ ] Test sanitization

---

## 📋 Progress Tracking

### Phase 1 Progress: [ ] / 5 tasks
- [ ] 1.1 Fix Android API Query Parameters
- [ ] 1.2 Fix Thread Safety in SupabaseAuthManager
- [ ] 1.3 Fix Unreachable Code in iOS OrbModel
- [ ] 1.4 Add Missing @Published Wrappers
- [ ] 1.5 Create Shared Swift Package

### Phase 2 Progress: [ ] / 5 tasks
- [ ] 2.1 Add Input Validation
- [ ] 2.2 Fix Inefficient Task Reindexing
- [ ] 2.3 Replace Blocking Dispatch with Async/Await
- [ ] 2.4 Add Database Indices for Soft Deletes
- [ ] 2.5 Replace Timer with CADisplayLink

### Phase 3 Progress: [ ] / 6 tasks
- [ ] 3.1 Extract Magic Numbers to Configuration
- [ ] 3.2 Consolidate Duplicate formatISO8601
- [ ] 3.3 Optimize noteCount Calculation
- [ ] 3.4 Add Retry Logic to Android Sync
- [ ] 3.5 Fix Memory Leak in Timer Closures
- [ ] 3.6 Add Additional Database Indices

### Phase 4 Progress: [ ] / 4 tasks
- [ ] 4.1 Batch Core Data Operations
- [ ] 4.2 Implement Lazy Loading in iOS
- [ ] 4.3 Configure Android Connection Pooling
- [ ] 4.4 Add Unit Tests

---

## 🎯 Recommended Order of Execution

**Week 1:** Phase 1 (Critical) - All P0 items
**Week 2:** Phase 2 (High Priority) - All P1 items  
**Week 3:** Phase 3 (Medium Priority) - All P2 items
**Week 4:** Phase 4 (Optimization) - All P3 items

**Dependencies:**
- Task 1.5 (Shared Package) should be done before any other Swift code changes to avoid merge conflicts
- Task 2.4 (DB Indices) can be done in parallel with code changes
- Task 4.4 (Tests) should follow completion of the features being tested
