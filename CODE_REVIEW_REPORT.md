# 📋 Comprehensive Code Review Report

**Date:** November 26, 2025  
**Scope:** Full codebase review of NotchToDo (macOS, iOS, Android)  
**Status:** ~70-75% Complete per CODEBASE_STOCKTAKE.md

---

## 🔍 Executive Summary

This is a cross-platform to-do application with voice-first interaction on macOS, traditional mobile experiences on iOS/Android, and a shared Supabase backend. The codebase is well-structured with clear separation of concerns, but several optimization opportunities and potential issues have been identified.

---

## 🚨 Critical Issues

### 1. **Code Duplication Between Platforms**

**Location:** `NotchToDo/NotchToDo/Supabase/` vs `NotchToDo-iOS/Shared/Services/`

The `SupabaseService.swift` and `SupabaseAuthManager.swift` are **nearly identical** between macOS and iOS:

```swift
// Both files are 247 lines and 235 lines respectively with identical logic
```

**Impact:** Bug fixes must be applied twice, version drift is inevitable.

**Recommendation:** 
- Create a true shared Swift Package for Supabase services
- Use `#if os(macOS)` / `#if os(iOS)` only for platform-specific code
- Consider using SPM or a monorepo structure with shared targets

---

### 2. **OrbModel.swift Missing `@Published` Wrapper**

**Location:** `NotchToDo-iOS/Shared/Models/OrbModel.swift:18`

```swift
var sortOrder: Double = 0.0  // Missing @Published
var createdAt: Date          // Missing @Published  
var updatedAt: Date?         // Missing @Published
```

**Impact:** UI won't update when these properties change.

**Recommendation:** Add `@Published` or make them `let` constants if they shouldn't change.

---

### 3. **Unreachable Code in toHexString()**

**Location:** `NotchToDo-iOS/Shared/Models/OrbModel.swift:97-104`

```swift
func toHexString() -> String {
    #if os(macOS)
    guard let rgb = usingColorSpace(.extendedSRGB) ?? usingColorSpace(.sRGB) else {
        return "#4F5FFF"
    }
    let r = Int(round(rgb.redComponent * 255.0))
    // ... macOS code
    #else
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    getRed(&r, green: &g, blue: &b, alpha: &a)
    let rInt = Int(round(r * 255.0))
    let gInt = Int(round(g * 255.0))
    let bInt = Int(round(b * 255.0))
    return String(format: "#%02X%02X%02X", rInt, gInt, bInt)  // RETURNS HERE
    #endif
    return String(format: "#%02X%02X%02X", r, g, b)  // UNREACHABLE ON iOS!
}
```

**Impact:** Dead code, potential confusion during maintenance.

**Fix:** Remove the unreachable `return` statement after `#endif`.

---

### 4. **Thread Safety in SupabaseAuthManager**

**Location:** `NotchToDo/NotchToDo/Supabase/SupabaseAuthManager.swift:17-22`

```swift
private(set) var currentSession: Session? {
    didSet {
        guard oldValue?.accessToken != currentSession?.accessToken else { return }
        NotificationCenter.default.post(name: .supabaseAuthSessionChanged, object: currentSession)
    }
}
```

**Issue:** `currentSession` can be accessed from multiple threads but is modified via `queue.async`. The `didSet` observer runs on the modifying queue, but reads from other threads are unprotected.

**Recommendation:**
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

### 5. **Android API Query Parameters Incorrect**

**Location:** `NotchToDo-Android/app/src/main/java/com/notchtodo/data/remote/SupabaseApi.kt:22-26`

```kotlin
@GET("rest/v1/tasks")
suspend fun getTask(
    @Query("id") id: String,
    @Query("eq") eq: String = id,  // WRONG: This sends ?eq=id
    @Query("select") select: String = "*"
): Response<List<TaskDto>>
```

**Issue:** PostgREST expects `?id=eq.{value}`, not separate `id` and `eq` parameters.

**Fix:**
```kotlin
@GET("rest/v1/tasks")
suspend fun getTask(
    @Query("id") filter: String,  // Pass "eq.{uuid}" directly
    @Query("select") select: String = "*"
): Response<List<TaskDto>>

// Usage: api.getTask(filter = "eq.${taskId}")
```

---

## ⚠️ High Priority Improvements

### 6. **Missing Data Validation/Sanitization**

**Location:** `NotchToDo/NotchToDo/Security/InputValidator.swift` exists but not used consistently.

Task titles and notes accept arbitrary user input without validation:

```swift
// OrbModels.swift:154
func addTask(title: String) {
    let task = Task(title: title, sortOrder: Double(tasks.count))
    addTask(task)
}
```

**Recommendation:** 
- Validate and sanitize all user input before storage
- Limit title/notes lengths
- Strip potentially dangerous characters for export features

---

### 7. **Inefficient Task Reindexing**

**Location:** `NotchToDo/NotchToDo/Models/OrbModels.swift:246-253`

```swift
private func reindexTasks() {
    for (index, task) in tasks.enumerated() {
        let order = Double(index)
        if task.sortOrder != order {
            task.sortOrder = order  // Triggers didSet -> notifyChange()
        }
    }
}
```

**Issue:** Called on every add/remove operation. Each `sortOrder` change triggers `notifyChange()` → persistence save.

**Recommendation:**
```swift
private func reindexTasks(silent: Bool = false) {
    let previousHandler = silent ? { tasks.forEach { $0.onChange = nil } } : nil
    previousHandler?()
    
    for (index, task) in tasks.enumerated() {
        task.sortOrder = Double(index)
    }
    
    if silent {
        tasks.forEach { attachChangeHandler(to: $0) }
    }
}
```

---

### 8. **Sync Manager Uses Blocking Dispatch**

**Location:** `NotchToDo/NotchToDo/Supabase/SupabaseSyncManager.swift:467-481`

```swift
private func awaitResult<T>(_ body: (@escaping (T?, Error?) -> Void) -> Void) throws -> T {
    var result: Result<T, Error>!
    let group = DispatchGroup()
    group.enter()
    body { value, error in
        // ...
        group.leave()
    }
    group.wait()  // BLOCKING!
    // ...
}
```

**Issue:** `group.wait()` blocks the calling thread. If called from the main thread, this causes UI freezes.

**Recommendation:** Refactor to use async/await throughout:
```swift
private func fetchRemote(userID: UUID, since: Date?, accessToken: String) async throws {
    let orbQuery = buildOrbQuery(userID: userID, since: since)
    let remoteOrbs = try await service.perform(orbRequest, decode: [OrbFetchRecord].self)
    // ...
}
```

---

### 9. **Missing Index for Soft Deletes**

**Location:** `supabase/schema.sql`

The `deleted_at` column is used for soft deletes but has no index:

```sql
create table if not exists public.tasks (
    -- ...
    deleted_at timestamptz  -- NO INDEX!
);
```

**Impact:** Queries filtering `WHERE deleted_at IS NULL` will be slow at scale.

**Fix:**
```sql
CREATE INDEX CONCURRENTLY idx_tasks_deleted_at ON public.tasks(deleted_at) 
WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY idx_orbs_deleted_at ON public.orbs(deleted_at)
WHERE deleted_at IS NULL;
```

---

### 10. **Timer-Based Physics Animation**

**Location:** `NotchToDo/NotchToDo/Models/OrbModels.swift:850-864`

```swift
private func animateOrbGrowth(orb: ProjectOrb, duration: Double) {
    let startTime = CACurrentMediaTime()
    Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in
        // Animation logic
    }
}
```

**Issue:** `Timer` is not synchronized with display refresh rate, causing potential stuttering.

**Recommendation:** Use `CADisplayLink` for smoother animations:
```swift
private var displayLink: CADisplayLink?

private func startAnimation() {
    displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
    displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
    displayLink?.add(to: .main, forMode: .common)
}
```

---

## 📊 Medium Priority Improvements

### 11. **Hardcoded Magic Numbers**

**Location:** Multiple files

```swift
// OrbModels.swift
var physicsDamping: Double = 0.92
var physicsStiffness: Double = 0.68
var physicsMass: Double = 0.14
var maxDisplacement: Double = 22.0

// SupabaseSyncManager.swift
timer.schedule(deadline: .now() + 10, repeating: 10, leeway: .seconds(1))
```

**Recommendation:** Move to a configuration struct:
```swift
struct PhysicsConfig {
    static let damping: Double = 0.92
    static let stiffness: Double = 0.68
    static let mass: Double = 0.14
    static let maxDisplacement: Double = 22.0
}

struct SyncConfig {
    static let pullInterval: TimeInterval = 10
    static let debounceDelay: TimeInterval = 0.15
}
```

---

### 12. **Duplicate `formatISO8601` Functions**

**Location:** 
- `NotchToDo-Android/.../TaskRepository.kt:240-244`
- `NotchToDo-Android/.../OrbRepository.kt:193-197`

```kotlin
private fun formatISO8601(date: Date): String {
    val formatter = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'", java.util.Locale.US)
    formatter.timeZone = java.util.TimeZone.getTimeZone("UTC")
    return formatter.format(date)
}
```

**Recommendation:** Extract to a utility class:
```kotlin
// util/DateUtils.kt
object DateUtils {
    private val iso8601Formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }
    
    fun formatISO8601(date: Date): String = iso8601Formatter.format(date)
}
```

---

### 13. **TaskModel noteCount Calculation Inefficient**

**Location:** `NotchToDo-iOS/Shared/Models/TaskModel.swift:43-54`

```swift
private static func calculateNoteCount(from details: String) -> Int {
    guard !details.isEmpty else { return 0 }
    if let data = details.data(using: .utf8),
       let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
        return array.count
    }
    // Falls back to line counting
}
```

**Issue:** JSON parsing on every note change is expensive.

**Recommendation:** Cache the note count and only recalculate when `details` changes:
```swift
@Published var details: String = "" {
    didSet {
        if details != oldValue {
            _cachedNoteCount = nil
        }
    }
}

private var _cachedNoteCount: Int?
var noteCount: Int {
    if let cached = _cachedNoteCount { return cached }
    let count = Self.calculateNoteCount(from: details)
    _cachedNoteCount = count
    return count
}
```

---

### 14. **Missing Error Handling in Android Sync**

**Location:** `NotchToDo-Android/.../TaskRepository.kt:206-238`

```kotlin
private suspend fun syncTaskToRemote(task: Task) {
    val userId = authRepository.getUserId() ?: return  // Silent failure!
    
    try {
        // ...
    } catch (e: Exception) {
        DebugLog.error("Failed to sync task to remote", e)
        // No retry logic, no user notification
    }
}
```

**Recommendation:** Implement exponential backoff retry:
```kotlin
private suspend fun syncTaskToRemote(task: Task, attempt: Int = 0) {
    val maxAttempts = 3
    try {
        // sync logic
    } catch (e: Exception) {
        if (attempt < maxAttempts) {
            delay((2.0.pow(attempt) * 1000).toLong())
            syncTaskToRemote(task, attempt + 1)
        } else {
            // Queue for later retry or notify user
        }
    }
}
```

---

### 15. **Potential Memory Leak in OrbManager**

**Location:** `NotchToDo/NotchToDo/Models/OrbModels.swift:603-660`

```swift
private func animateOrbRepositioning(newOrb: ProjectOrb) {
    Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in
        // Captures self strongly in closure
        for orb in self.orbs {  // ← Strong reference to self
            // ...
        }
    }
}
```

**Issue:** Timer captures `self` strongly, preventing deallocation until timer invalidates.

**Fix:**
```swift
Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] timer in
    guard let self = self else {
        timer.invalidate()
        return
    }
    // ...
}
```

---

## 💡 Optimization Suggestions

### 16. **Batch Core Data Operations**

**Location:** `NotchToDo/NotchToDo/Persistence/OrbPersistenceStore.swift`

Currently, each entity is saved individually. For bulk operations:

```swift
// Instead of:
for snapshot in snapshots {
    entity.setValue(snapshot.name, forKey: Keys.name)
    // ...
}
try context.save()

// Consider:
context.perform {
    for snapshot in snapshots {
        // batch all changes
    }
    try context.save()
}
```

---

### 17. **Use Batch Delete for Logout**

**Location:** `OrbPersistenceStore.swift:48-68`

```swift
func deleteAllData() throws {
    let taskRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Keys.taskEntity)
    let taskDeleteRequest = NSBatchDeleteRequest(fetchRequest: taskRequest)
    try viewContext.persistentStoreCoordinator?.execute(taskDeleteRequest, with: viewContext)
}
```

**This is already correct!** ✅ Batch delete is being used properly.

---

### 18. **Lazy Loading for Task Lists**

**Location:** iOS `TasksView.swift`

```swift
var allTasks: [(orb: OrbModel, task: TaskModel)] {
    dataManager.orbs.flatMap { orb in
        orb.tasks.map { (orb: orb, task: $0) }  // Computed every render
    }
}
```

**Recommendation:** Memoize with `@State` or use pagination:
```swift
@State private var cachedTasks: [(orb: OrbModel, task: TaskModel)]?

var allTasks: [(orb: OrbModel, task: TaskModel)] {
    if let cached = cachedTasks { return cached }
    let tasks = dataManager.orbs.flatMap { orb in
        orb.tasks.map { (orb: orb, task: $0) }
    }
    DispatchQueue.main.async { cachedTasks = tasks }
    return tasks
}
```

---

### 19. **Add Database Indices for Common Queries**

**Location:** `supabase/schema.sql`

Current indices are minimal. Add:

```sql
-- For filtering tasks by completion status
CREATE INDEX idx_tasks_completed ON public.tasks(is_completed) WHERE deleted_at IS NULL;

-- For sorting by priority
CREATE INDEX idx_tasks_priority ON public.tasks(priority) WHERE deleted_at IS NULL;

-- For due date queries
CREATE INDEX idx_tasks_due_date ON public.tasks(due_date) WHERE due_date IS NOT NULL AND deleted_at IS NULL;

-- Composite index for common query pattern
CREATE INDEX idx_tasks_user_orb_sort ON public.tasks(user_id, orb_id, sort_order) WHERE deleted_at IS NULL;
```

---

### 20. **Connection Pooling for Android**

**Location:** `NotchToDo-Android/.../SupabaseApi.kt`

OkHttp should be configured with connection pooling:

```kotlin
// In AppModule.kt
@Provides
@Singleton
fun provideOkHttpClient(): OkHttpClient {
    return OkHttpClient.Builder()
        .connectionPool(ConnectionPool(5, 5, TimeUnit.MINUTES))
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .addInterceptor(SupabaseAuthInterceptor(...))
        .build()
}
```

---

## 🧪 Testing Gaps

Based on `CODEBASE_STOCKTAKE.md`:

1. **Only 1 test file exists** (`IntentRouterTests.swift`)
2. **Missing test coverage:**
   - Sync manager conflict resolution
   - Offline mode behavior
   - Authentication flows
   - Data migration paths
   - UI snapshot tests

**Recommendation:** Prioritize tests for:
1. `SupabaseSyncManager` - Most complex, highest risk
2. `OrbPersistenceStore` - Data integrity critical
3. `IntentRouter` - User-facing voice commands
4. Authentication flows - Security critical

---

## 📈 Performance Recommendations

### Immediate Wins:
1. Add missing database indices (5-10x query improvement)
2. Fix Timer → DisplayLink for animations
3. Batch Core Data saves
4. Memoize computed properties in SwiftUI views

### Medium-term:
1. Implement proper sync conflict resolution
2. Add offline queue with retry logic
3. Lazy load task lists with pagination
4. Profile and optimize physics calculations

### Long-term:
1. Consider GraphQL for efficient data fetching
2. Implement delta sync instead of full pulls
3. Add client-side caching layer
4. Consider SQLCipher for encrypted local storage

---

## 🔒 Security Review Notes

### Positives:
- ✅ Keychain used for token storage
- ✅ RLS policies in Supabase
- ✅ User ID validation in sync manager
- ✅ Input validation infrastructure exists

### Concerns:
- ⚠️ Access token expiry handling could be more robust
- ⚠️ No rate limiting on client side
- ⚠️ OAuth redirect handling should validate state parameter
- ⚠️ Debug logging may expose sensitive data in production

---

## 📝 Summary

| Category | Count |
|----------|-------|
| Critical Issues | 5 |
| High Priority | 5 |
| Medium Priority | 5 |
| Optimization Suggestions | 5 |

**Top 3 Actions:**
1. **Fix Android API query parameters** - Currently broken
2. **Add thread safety to AuthManager** - Race condition risk
3. **Fix unreachable code in iOS OrbModel** - Clean up dead code

**Estimated Technical Debt:** ~40-60 hours to address all issues
