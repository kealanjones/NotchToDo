# SharedKit Migration Guide

This guide documents the migration of shared code to the SharedKit Swift package and the removal of duplicate files.

## What Was Done

### Files Deleted from iOS (`NotchToDo-iOS/Shared/`)

The following files were removed as they are now provided by SharedKit:

| Removed File | SharedKit Replacement |
|--------------|----------------------|
| `Models/DataSnapshots.swift` | `SharedKit/Models/DataSnapshots.swift` |
| `Models/OrbModel.swift` | `SharedKit/Models/OrbModel.swift` |
| `Models/TaskModel.swift` | `SharedKit/Models/TaskModel.swift` |
| `Services/SupabaseAuthManager.swift` | `SharedKit/Services/SupabaseAuthManager.swift` |
| `Services/SupabaseNotifications.swift` | `SharedKit/Services/SupabaseNotifications.swift` |
| `Services/SupabaseOutboxPayloads.swift` | `SharedKit/Services/SupabaseOutboxPayloads.swift` |
| `Services/SupabaseService.swift` | `SharedKit/Services/SupabaseService.swift` |
| `Utilities/DebugLog.swift` | `SharedKit/Utilities/DebugLog.swift` |
| `Utilities/KeychainHelper.swift` | `SharedKit/Utilities/KeychainHelper.swift` |

### Files Deleted from macOS (`NotchToDo/NotchToDo/`)

| Removed File | SharedKit Replacement |
|--------------|----------------------|
| `Supabase/SupabaseNotifications.swift` | `SharedKit/Services/SupabaseNotifications.swift` |
| `Supabase/SupabaseOutboxPayloads.swift` | `SharedKit/Services/SupabaseOutboxPayloads.swift` |
| `Utilities/KeychainHelper.swift` | `SharedKit/Utilities/KeychainHelper.swift` |

### Files Kept (Platform-Specific Implementations)

The following files were **NOT** deleted because they contain platform-specific logic:

- `NotchToDo/NotchToDo/DebugLogger.swift` - Has macOS-specific categories like `.physics`, `.ml`, `.speech`
- `NotchToDo/NotchToDo/Supabase/SupabaseService.swift` - Has macOS-specific integration with sync manager
- `NotchToDo/NotchToDo/Supabase/SupabaseAuthManager.swift` - Has macOS-specific session management

## Xcode Project Setup Required

### For NotchToDo-iOS

1. **Remove deleted file references from Xcode project:**
   - Open `NotchToDo-iOS.xcodeproj`
   - In the Project Navigator, locate and remove references to deleted files (they will appear in red)

2. **Add SharedKit as a local package dependency:**
   - File → Add Package Dependencies
   - Click "Add Local..." and select `/workspace/SharedKit`
   - Or manually add to `Package.swift` if using SPM:
     ```swift
     .package(path: "../SharedKit")
     ```

3. **Import SharedKit in source files:**
   ```swift
   import SharedKit
   ```

### For NotchToDo (macOS)

1. **Remove deleted file references from Xcode project:**
   - Open `NotchToDo.xcodeproj`
   - Remove references to:
     - `Supabase/SupabaseNotifications.swift`
     - `Supabase/SupabaseOutboxPayloads.swift`
     - `Utilities/KeychainHelper.swift`

2. **Add SharedKit as a local package dependency:**
   - File → Add Package Dependencies
   - Click "Add Local..." and select `/workspace/SharedKit`

3. **Update imports in affected files:**
   ```swift
   import SharedKit
   
   // Now use:
   // - Notification.Name.supabaseOutboxDidChange
   // - Notification.Name.supabaseAuthSessionChanged
   // - OrbOutboxPayload, TaskOutboxPayload, DeletionOutboxPayload
   // - KeychainHelper
   ```

4. **Optional: Migrate from DebugLogger to SharedKit's DebugLog:**
   
   The macOS `DebugLogger.swift` can be replaced by SharedKit's version, which includes all categories. If you prefer to keep the macOS version for backward compatibility, no action needed.

## New Utilities Available

SharedKit now provides these new utilities for both iOS and macOS:

| Utility | Description |
|---------|-------------|
| `Cache` | Thread-safe generic caching with TTL and eviction |
| `ComputedCache` | Single-value computed property caching |
| `InputValidation` | Task and Orb input validation with error messages |
| `UserFacingError` | Maps system errors to user-friendly messages |
| `PaginatedLoader` | Offset-based pagination for SwiftUI lists |
| `CursorPaginatedLoader` | Cursor-based pagination |
| `PerformanceMonitor` | Timing and metrics for operations |
| `NetworkMonitor` | Connectivity status and network type |

### Usage Examples

```swift
import SharedKit

// Caching
let cache = Cache<String, User>()
let user = cache.getOrCompute("user_123") { await fetchUser(id: "123") }

// Input Validation
let title = try InputValidation.validateTaskTitle(userInput)

// Error Display
catch {
    let displayable = UserFacingError.from(error)
    showAlert(title: displayable.title, message: displayable.message)
}

// Pagination
@StateObject var loader = PaginatedLoader<Task>(pageSize: 20)

// Performance
let result = measurePerformance("fetchTasks") { 
    await api.getTasks() 
}

// Network
if NetworkMonitor.shared.isConnected {
    await sync()
}
```

## Testing

SharedKit includes comprehensive unit tests. Run them with:

```bash
cd SharedKit
swift test
```

Note: Swift compiler required (not available in all environments).

## Directory Structure After Migration

```
/workspace/
├── SharedKit/                    # ✅ New shared Swift package
│   ├── Package.swift
│   ├── Sources/SharedKit/
│   │   ├── Models/
│   │   ├── Services/
│   │   └── Utilities/
│   └── Tests/SharedKitTests/
│
├── NotchToDo/                    # macOS app
│   └── NotchToDo/
│       ├── Supabase/
│       │   ├── SupabaseService.swift      # Platform-specific (kept)
│       │   ├── SupabaseAuthManager.swift  # Platform-specific (kept)
│       │   └── SupabaseSyncManager.swift
│       ├── DebugLogger.swift              # Platform-specific (kept)
│       └── Utilities/
│           └── InputValidator.swift        # Different from InputValidation
│
├── NotchToDo-iOS/
│   ├── NotchToDo-iOS/
│   │   └── ...
│   └── Shared/
│       └── NotchDataModel.xcdatamodeld/   # Core Data model (kept)
│
└── NotchToDo-Android/            # Android app (separate utilities)
    └── app/src/main/java/com/notchtodo/util/
        ├── Cache.kt
        ├── InputValidation.kt
        ├── UserFacingError.kt
        ├── PaginatedLoader.kt
        ├── PerformanceMonitor.kt
        ├── NetworkMonitor.kt
        └── ...
```

## Verification Checklist

- [ ] All deleted file references removed from Xcode projects
- [ ] SharedKit added as dependency to iOS project
- [ ] SharedKit added as dependency to macOS project
- [ ] `import SharedKit` added to files that use shared types
- [ ] iOS project builds successfully
- [ ] macOS project builds successfully
- [ ] All tests pass
