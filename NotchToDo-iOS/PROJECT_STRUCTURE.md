# NotchToDo iOS - Project Structure

Complete file tree and component overview.

## Directory Tree

```
NotchToDo-iOS/
│
├── NotchToDo-iOS/                          # iOS-specific code
│   ├── App/
│   │   └── NotchToDoApp.swift              # Main app entry point, handles auth routing
│   │
│   ├── Views/                              # SwiftUI Views
│   │   ├── AuthView.swift                  # Sign in/up screen with email/password
│   │   ├── MainTabView.swift               # Tab bar container (Tasks/Orbs/Settings)
│   │   ├── TasksView.swift                 # Task list with search and status grouping
│   │   ├── TaskDetailView.swift            # Task view/edit with status picker
│   │   ├── OrbsView.swift                  # Orb list and orb detail views
│   │   ├── CreateTaskView.swift            # Task creation form with voice input
│   │   ├── VoiceInputView.swift            # Speech recognition UI
│   │   └── SettingsView.swift              # Settings, account, sync info
│   │
│   ├── Services/                           # iOS-specific services
│   │   ├── PersistenceController.swift     # Core Data stack management
│   │   └── DataManager.swift               # Central data coordinator (Singleton)
│   │
│   └── Resources/
│       └── Info.plist                       # App configuration, Supabase credentials
│
├── Shared/                                  # Cross-platform code (iOS + macOS)
│   ├── Models/
│   │   ├── TaskModel.swift                 # Task ObservableObject with status enum
│   │   ├── OrbModel.swift                  # Orb ObservableObject with color palette
│   │   └── DataSnapshots.swift             # Core Data ↔ View Model bridge
│   │
│   ├── Services/
│   │   ├── SupabaseService.swift           # REST API client (from macOS)
│   │   ├── SupabaseAuthManager.swift       # Auth & session management (from macOS)
│   │   ├── SupabaseNotifications.swift     # Notification names for sync events
│   │   └── SupabaseOutboxPayloads.swift    # Sync payload structs
│   │
│   ├── Utilities/
│   │   ├── DebugLog.swift                  # Categorized logging system
│   │   └── KeychainHelper.swift            # Secure token storage
│   │
│   └── NotchDataModel.xcdatamodeld/        # Core Data schema (from macOS)
│       └── NotchDataModel.xcdatamodel/
│           └── contents                     # OrbEntity, TaskEntity, SyncOutboxItem
│
└── Documentation/
    ├── README.md                            # Full setup & usage guide
    ├── IMPLEMENTATION_REPORT.md             # Architecture & implementation details
    ├── QUICK_START_GUIDE.md                 # 5-minute quick start
    └── PROJECT_STRUCTURE.md                 # This file
```

## File Descriptions

### App Entry Point

| File | Lines | Purpose |
|------|-------|---------|
| `NotchToDoApp.swift` | 15 | Main app, routes to AuthView or MainTabView based on auth state |

### Views (SwiftUI)

| File | Lines | Purpose | Key Features |
|------|-------|---------|--------------|
| `AuthView.swift` | 120 | Sign in/up screen | Email/password, error handling, loading state |
| `MainTabView.swift` | 25 | Tab bar container | 3 tabs: Tasks, Orbs, Settings |
| `TasksView.swift` | 150 | Task list | Search, status grouping, navigation |
| `TaskDetailView.swift` | 180 | Task details | Edit mode, status picker, delete |
| `OrbsView.swift` | 220 | Orb management | List, create, detail views |
| `CreateTaskView.swift` | 180 | Task creation | Form, voice input trigger, date picker |
| `VoiceInputView.swift` | 200 | Voice recording | Speech recognition, real-time transcription |
| `SettingsView.swift` | 150 | Settings | Account info, sync, sign out |

**Total Views**: ~1,225 LOC

### Services

| File | Lines | Purpose | Key Features |
|------|-------|---------|--------------|
| `DataManager.swift` | 200 | Data coordinator | ObservableObject, CRUD operations, auth |
| `PersistenceController.swift` | 250 | Core Data | Fetch/save orbs, snapshot conversion |
| `SupabaseService.swift` | 250 | API client | REST calls, JSON encoding/decoding |
| `SupabaseAuthManager.swift` | 235 | Auth manager | Sign in/up, token refresh, Keychain |

**Total Services**: ~935 LOC

### Models

| File | Lines | Purpose | Key Features |
|------|-------|---------|--------------|
| `TaskModel.swift` | 100 | Task view model | ObservableObject, status enum, note count |
| `OrbModel.swift` | 150 | Orb view model | ObservableObject, color palette, task array |
| `DataSnapshots.swift` | 30 | Core Data bridge | Struct snapshots for serialization |

**Total Models**: ~280 LOC

### Utilities

| File | Lines | Purpose | Key Features |
|------|-------|---------|--------------|
| `DebugLog.swift` | 84 | Logging | Categorized logs, enable/disable per category |
| `KeychainHelper.swift` | 60 | Keychain | Secure string storage for tokens |
| `SupabaseNotifications.swift` | 8 | Constants | Notification names for sync events |
| `SupabaseOutboxPayloads.swift` | 37 | Payloads | Codable structs for sync data |

**Total Utilities**: ~189 LOC

## Component Relationships

### View Hierarchy

```
NotchToDoApp
    ├─ if authenticated
    │   └─ MainTabView
    │       ├─ TasksView (Tab 1)
    │       │   ├─ TaskDetailView (Push)
    │       │   └─ CreateTaskView (Sheet)
    │       │       └─ VoiceInputView (Sheet)
    │       │
    │       ├─ OrbsView (Tab 2)
    │       │   ├─ OrbDetailView (Push)
    │       │   ├─ CreateOrbView (Sheet)
    │       │   └─ CreateTaskView (Sheet)
    │       │
    │       └─ SettingsView (Tab 3)
    │           └─ SyncInfoView (Sheet)
    │
    └─ else
        └─ AuthView
```

### Data Flow

```
SwiftUI View
    ↓
@EnvironmentObject DataManager
    ↓
┌───────────────┴─────────────┐
│                             │
↓                             ↓
PersistenceController    SupabaseService
↓                             ↓
Core Data                 Supabase API
```

### Service Dependencies

```
DataManager
    ├─ depends on → PersistenceController
    └─ depends on → SupabaseAuthManager
                        ├─ depends on → SupabaseService
                        └─ depends on → KeychainHelper

PersistenceController
    ├─ depends on → Core Data Model
    └─ uses → DebugLog

All services use → DebugLog
```

## Code Metrics

### Lines of Code (Approximate)

| Category | iOS-Specific | Shared | Total |
|----------|--------------|--------|-------|
| **Views** | 1,225 | 0 | 1,225 |
| **Services** | 450 | 485 | 935 |
| **Models** | 0 | 280 | 280 |
| **Utilities** | 0 | 189 | 189 |
| **Total** | 1,675 | 954 | 2,629 |

**Code Reuse**: 36% of code is shared with macOS

### File Count

| Type | Count |
|------|-------|
| Swift Files | 20 |
| SwiftUI Views | 10 |
| Services | 4 |
| Models | 3 |
| Utilities | 4 |
| Core Data Models | 1 |
| Documentation | 4 |
| Configuration | 1 (Info.plist) |

## Shared vs iOS-Specific

### Shared with macOS (36%)
- ✅ All models (Task, Orb, Snapshots)
- ✅ Supabase service layer
- ✅ Auth manager
- ✅ Utilities (Keychain, DebugLog)
- ✅ Core Data schema
- ✅ Sync payloads

### iOS-Specific (64%)
- All SwiftUI views
- DataManager (uses shared services)
- PersistenceController (iOS-specific Core Data setup)
- Info.plist

## Build Configuration

### Targets

1. **NotchToDo-iOS** (Main App)
   - Deployment Target: iOS 16.0
   - Bundle ID: `com.yourcompany.NotchToDo-iOS`
   - Capabilities: Speech Recognition, Microphone

2. **NotchToDo-iOS Widget** (Future)
   - Home screen widget
   - Bundle ID: `com.yourcompany.NotchToDo-iOS.Widget`

3. **NotchToDo-iOS ShareExtension** (Future)
   - Share extension for adding tasks
   - Bundle ID: `com.yourcompany.NotchToDo-iOS.ShareExtension`

### Dependencies

| Dependency | Source | Purpose |
|------------|--------|---------|
| Core Data | System | Local storage |
| Speech | System | Voice recognition |
| SwiftUI | System | UI framework |
| Combine | System | Reactive programming |
| Foundation | System | Core utilities |

**No external packages** - All code is native Swift/SwiftUI

## API Surface

### Public APIs (DataManager)

```swift
class DataManager: ObservableObject {
    // Properties
    @Published var orbs: [OrbModel]
    @Published var isLoading: Bool
    @Published var error: Error?

    // Orb Operations
    func loadOrbs()
    func createOrb(name: String)
    func deleteOrb(_ orb: OrbModel)
    func saveOrb(_ orb: OrbModel)

    // Task Operations
    func createTask(in orb: OrbModel, title: String)
    func deleteTask(_ task: TaskModel, from orb: OrbModel)
    func updateTask(_ task: TaskModel, in orb: OrbModel)

    // Auth Operations
    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String) async throws
    func signOut()
    var isAuthenticated: Bool { get }
}
```

### View Access Pattern

All views use:
```swift
@EnvironmentObject var dataManager: DataManager
```

This provides:
- Centralized data access
- Automatic UI updates via `@Published`
- No direct Core Data or Supabase calls from views

## Extension Points

### Adding New Views
1. Create new SwiftUI file in `Views/`
2. Add `@EnvironmentObject var dataManager: DataManager`
3. Use `dataManager.orbs` and CRUD methods
4. Add navigation in existing views

### Adding New Data Fields
1. Update `TaskModel` or `OrbModel` in `Shared/Models/`
2. Update Core Data schema in `.xcdatamodeld`
3. Update `PersistenceController` snapshot conversion
4. Update `SupabaseOutboxPayloads` for sync
5. Test sync with macOS

### Adding New Features
1. Widgets: Add new target, use DataManager
2. Shortcuts: Create intent definition, use DataManager
3. Share Extension: Add target, create task via DataManager

## Testing Structure (Future)

```
NotchToDo-iOSTests/
├── ModelTests/
│   ├── TaskModelTests.swift
│   └── OrbModelTests.swift
├── ServiceTests/
│   ├── DataManagerTests.swift
│   ├── PersistenceControllerTests.swift
│   └── SupabaseServiceTests.swift
└── ViewTests/
    ├── AuthViewTests.swift
    ├── TasksViewTests.swift
    └── CreateTaskViewTests.swift

NotchToDo-iOSUITests/
├── AuthFlowTests.swift
├── TaskCRUDTests.swift
└── SyncTests.swift
```

## Version Control

### Git Structure
```
NotchToDo/
├── NotchToDo/              # macOS app
├── NotchToDo-iOS/          # iOS app (this folder)
├── supabase/               # Database migrations
├── .gitignore
└── README.md
```

### Ignored Files (.gitignore)
```
# Xcode
*.xcuserdata
*.xcworkspace
DerivedData/
Build/

# Secrets
Info.plist (with real credentials)
*.env
```

## Documentation Files

| File | Purpose | Audience |
|------|---------|----------|
| README.md | Full setup & usage guide | Developers, users |
| IMPLEMENTATION_REPORT.md | Architecture & decisions | Technical team, stakeholders |
| QUICK_START_GUIDE.md | 5-minute setup | New developers |
| PROJECT_STRUCTURE.md | This file - code organization | Developers |

---

**Last Updated**: January 2025
**iOS Version**: 1.0.0-beta
**macOS Compatibility**: Full sync support
