# NotchToDo iOS

The iOS companion app for NotchToDo, a voice-first task manager that syncs seamlessly with the macOS app via Supabase.

## Features

### Core Features (v1.0)
- ✅ **Task Management**: Create, edit, complete, and delete tasks
- ✅ **Orb System**: Organize tasks into color-coded orbs (folders)
- ✅ **Three-State Status**: Outstanding → In Progress → Complete
- ✅ **Voice Input**: Create tasks using Speech Recognition
- ✅ **Real-time Sync**: Bidirectional sync with macOS via Supabase
- ✅ **Offline Support**: Works offline with automatic sync when online
- ✅ **Authentication**: Email/password and OAuth support
- ✅ **Search**: Full-text search across all tasks

### iOS-Specific Features
- 📱 **Native SwiftUI**: Modern, responsive iOS interface
- 🎤 **Voice Input**: Tap-to-speak task creation
- 🔄 **Pull to Refresh**: Manual sync trigger
- 🌓 **Dark Mode**: Full dark mode support
- ♿ **Accessibility**: VoiceOver and Dynamic Type support

### Planned Features
- 🔔 **Widgets**: Home screen widget with today's tasks
- 🤖 **Siri Shortcuts**: "Add task to NotchToDo"
- ↗️ **Share Extension**: Add tasks from other apps
- ⌚ **Apple Watch**: Companion watch app

## Architecture

### Project Structure
```
NotchToDo-iOS/
├── NotchToDo-iOS/          # iOS-specific code
│   ├── App/                # App entry point
│   ├── Views/              # SwiftUI views
│   ├── ViewModels/         # (Future use)
│   ├── Services/           # iOS-specific services
│   └── Resources/          # Assets, Info.plist
│
└── Shared/                 # Shared with macOS
    ├── Models/             # Task & Orb models
    ├── Services/           # Supabase, Auth
    ├── Utilities/          # Keychain, DebugLog
    └── NotchDataModel.xcdatamodeld  # Core Data schema
```

### Technology Stack
- **UI Framework**: SwiftUI
- **Architecture**: MVVM with ObservableObject
- **Local Storage**: Core Data
- **Remote Backend**: Supabase (PostgreSQL + REST API)
- **Authentication**: Supabase Auth (Email/Password, OAuth)
- **Voice Input**: Speech Framework (SFSpeechRecognizer)
- **Sync Strategy**: Outbox pattern with bidirectional sync

### Data Flow
```
┌──────────────┐
│  SwiftUI     │
│  Views       │
└──────┬───────┘
       │
       ↓
┌──────────────┐
│ DataManager  │ (ObservableObject)
└──────┬───────┘
       │
       ├─────────→ ┌──────────────────┐
       │           │ PersistenceController │ → Core Data
       │           └──────────────────┘
       │
       └─────────→ ┌──────────────────┐
                   │ SupabaseService  │ → Supabase API
                   └──────────────────┘
```

## Setup Instructions

### Prerequisites
1. Xcode 15.0 or later
2. iOS 16.0+ deployment target
3. Supabase account and project
4. macOS NotchToDo app (optional, for testing sync)

### Installation Steps

#### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/NotchToDo.git
cd NotchToDo/NotchToDo-iOS
```

#### 2. Configure Supabase
1. Open `NotchToDo-iOS/Resources/Info.plist`
2. Replace the following placeholders:
   ```xml
   <key>SupabaseURL</key>
   <string>https://your-project.supabase.co</string>
   <key>SupabaseAnonKey</key>
   <string>your-anon-key-here</string>
   ```

3. Get your Supabase credentials:
   - Go to [Supabase Dashboard](https://app.supabase.com)
   - Select your project
   - Go to **Settings > API**
   - Copy **Project URL** and **anon/public key**

#### 3. Open in Xcode
```bash
open NotchToDo-iOS.xcodeproj
```

#### 4. Configure Signing & Capabilities
1. Select the **NotchToDo-iOS** target
2. Go to **Signing & Capabilities**
3. Select your development team
4. Update the bundle identifier if needed: `com.yourcompany.NotchToDo-iOS`

#### 5. Add Required Capabilities
Ensure these capabilities are enabled:
- ✅ **Background Modes**: Background fetch (for sync)
- ✅ **Keychain Sharing**: (Optional, for shared credentials)
- ✅ **Push Notifications**: (Future feature)

#### 6. Build and Run
1. Select a simulator or device
2. Press **⌘R** to build and run
3. Sign up or sign in with your Supabase account

## Usage Guide

### Creating Tasks

#### Via Keyboard
1. Tap the **+** button in the Tasks tab
2. Enter task title
3. Select an orb (folder)
4. Choose status (Outstanding/In Progress/Complete)
5. Add optional due date and notes
6. Tap **Create**

#### Via Voice
1. Tap the **+** button in the Tasks tab
2. Tap the **microphone icon** next to the title field
3. Grant microphone permission if prompted
4. Tap **Start Recording** and speak your task
5. Tap **Stop Recording** when done
6. Review and edit the transcribed text
7. Tap **Done** to use it

### Managing Orbs
1. Go to the **Orbs** tab
2. Tap **+** to create a new orb
3. Enter a name (e.g., "Work", "Personal", "Home")
4. Each orb gets a unique color automatically
5. Tap an orb to view its tasks
6. Swipe left to delete an orb (and all its tasks)

### Task Status System
Tasks have three states:
- **⚪ Outstanding**: Not started yet
- **◐ In Progress**: Currently working on
- **✓ Complete**: Finished

Change status by:
1. Opening task details
2. Tapping **Edit**
3. Selecting a new status in the segmented control

### Syncing with macOS
1. Ensure both apps are signed in to the same account
2. Sync happens automatically every 10 seconds
3. Manual sync: Pull down to refresh or tap **Sync Now** in Settings
4. Offline changes sync automatically when back online

### Search
1. Go to the **Tasks** tab
2. Pull down to reveal the search bar
3. Type to search across all task titles
4. Results update in real-time

## Development Guide

### Adding New Views
1. Create a new SwiftUI file in `Views/`
2. Use `@EnvironmentObject var dataManager: DataManager` to access data
3. Add navigation in `MainTabView.swift` or existing views

### Modifying Data Models
1. Edit models in `Shared/Models/`
2. Update Core Data schema in `Shared/NotchDataModel.xcdatamodeld`
3. Update `PersistenceController.swift` if needed
4. Increment schema version in `PersistenceController` (if breaking changes)

### Adding Sync Payloads
1. Update `SupabaseOutboxPayloads.swift` with new fields
2. Update `PersistenceController` to encode new fields
3. Test sync with macOS app

### Debugging
- Enable debug logging categories in `DebugLog.swift`
- Use Xcode's View Hierarchy Debugger
- Check Console for `[SYNC]`, `[DATA]`, `[SPEECH]` logs
- Use Network Link Conditioner to test offline mode

## Testing

### Manual Testing Checklist
- [ ] Create task via keyboard
- [ ] Create task via voice
- [ ] Edit task details
- [ ] Change task status
- [ ] Delete task
- [ ] Create orb
- [ ] Delete orb
- [ ] Search tasks
- [ ] Sign in/out
- [ ] Test offline mode
- [ ] Test sync with macOS
- [ ] Test on iPhone and iPad
- [ ] Test dark mode
- [ ] Test VoiceOver

### Sync Testing
1. **Setup**: Run both iOS and macOS apps with same account
2. **Create on iOS**: Add a task on iOS
3. **Verify on macOS**: Wait 10s, check it appears on macOS
4. **Edit on macOS**: Change task title on macOS
5. **Verify on iOS**: Pull to refresh, check changes
6. **Offline test**: Turn off Wi-Fi, make changes, reconnect
7. **Conflict test**: Edit same task offline on both platforms

## Troubleshooting

### Sync Not Working
1. Check Supabase credentials in `Info.plist`
2. Verify network connection
3. Check Console for `[SYNC]` errors
4. Sign out and sign back in
5. Check Supabase dashboard for API errors

### Voice Input Not Working
1. Grant microphone permission in Settings app
2. Grant speech recognition permission
3. Check device microphone hardware
4. Try restarting the app

### Core Data Errors
1. Delete and reinstall the app (clears database)
2. Check schema version compatibility
3. Review Console for `[DATA]` errors

### Build Errors
1. Clean build folder: **⌘⇧K**
2. Delete derived data: `~/Library/Developer/Xcode/DerivedData`
3. Update Xcode to latest version
4. Check Swift version compatibility

## Performance

### Optimization Strategies
- **Lazy Loading**: Tasks loaded on-demand per orb
- **Background Sync**: Sync runs on background queue
- **Debouncing**: Text input debounced to avoid excessive saves
- **Core Data Batch Operations**: Use batch fetch and save
- **Image Caching**: (Future) Cache orb colors for performance

### Memory Management
- Use `@StateObject` for data managers
- Use `@ObservedObject` for passed-in models
- Avoid retain cycles with `[weak self]` in closures
- Release unused resources in `onDisappear`

## Security

### Data Protection
- ✅ Keychain storage for auth tokens
- ✅ Core Data encryption (when device locked)
- ✅ HTTPS for all API calls
- ✅ OAuth token refresh
- ⚠️ No sensitive data in logs

### Privacy
- Microphone access only when explicitly requested
- Speech recognition happens on-device
- No analytics or tracking
- User data stored in their own Supabase project

## Deployment

### App Store Submission
1. Update version and build number
2. Create App Store screenshots
3. Write App Store description (see `AppStoreDescription.md`)
4. Configure App Store Connect
5. Submit for review

### TestFlight Beta
1. Archive app in Xcode: **Product > Archive**
2. Upload to App Store Connect
3. Add beta testers
4. Send test invitation

## Contributing
See main repository README for contribution guidelines.

## License
MIT License - see LICENSE file

## Support
- Report issues: [GitHub Issues](https://github.com/yourusername/NotchToDo/issues)
- Email: support@notchtodo.com
- Documentation: [docs.notchtodo.com](https://docs.notchtodo.com)

## Changelog

### Version 1.0.0 (2025-01-XX)
- Initial iOS release
- Core task management features
- Supabase sync with macOS
- Voice input support
- Authentication (email/password)
- Three-state task status
- Search functionality
- Offline support

## Credits
- Built with SwiftUI and Supabase
- Inspired by the macOS NotchToDo app
- Speech recognition powered by Apple's Speech Framework
