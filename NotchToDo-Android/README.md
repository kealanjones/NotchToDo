# NotchToDo Android

The native Android companion app for NotchToDo, a voice-first task manager that syncs seamlessly with macOS and iOS apps via Supabase.

## Overview

NotchToDo Android is a modern, Material Design 3 application built with Jetpack Compose, following clean architecture principles and best practices for Android development.

### Key Features

**Core Functionality (v1.0)**
- Task Management: Create, edit, complete, and delete tasks
- Orb System: Organize tasks into color-coded orbs (folders)
- Three-State Status: Outstanding → In Progress → Complete
- Real-time Sync: Bidirectional sync with macOS/iOS via Supabase
- Offline Support: Works offline with automatic sync when online
- Authentication: Email/password and Google Sign-In support
- Search: Full-text search across all tasks

**Android-Specific Features**
- Material Design 3: Dynamic theming with Material You
- Share Target: Add tasks from other apps
- Background Sync: Automatic sync via WorkManager
- Adaptive Icons: Follows Android icon guidelines
- Dark Theme: Full dark mode support

**Planned Features**
- Home Screen Widget: Today's tasks widget
- Voice Input: Create tasks using Speech Recognition
- Push Notifications: Task reminders for due dates
- Widget: Glance-based home screen widget

## Architecture

### Technology Stack

- **Language**: Kotlin
- **UI Framework**: Jetpack Compose with Material Design 3
- **Architecture**: MVVM with Clean Architecture
- **DI**: Hilt (Dagger)
- **Local Database**: Room
- **Remote Backend**: Supabase (PostgreSQL + REST API)
- **Networking**: Retrofit + OkHttp
- **Async**: Kotlin Coroutines + Flow
- **Background Work**: WorkManager
- **Security**: EncryptedSharedPreferences

### Project Structure

```
NotchToDo-Android/
├── app/
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/com/notchtodo/
│   │   │   │   ├── NotchToDoApplication.kt       # Application class
│   │   │   │   ├── ui/                           # Compose UI layer
│   │   │   │   │   ├── MainActivity.kt
│   │   │   │   │   ├── theme/                    # Material Design theme
│   │   │   │   │   ├── navigation/               # Navigation setup
│   │   │   │   │   ├── auth/                     # Authentication screens
│   │   │   │   │   ├── tasks/                    # Task screens & ViewModels
│   │   │   │   │   ├── orbs/                     # Orb screens & ViewModels
│   │   │   │   │   ├── settings/                 # Settings screen
│   │   │   │   │   └── ShareActivity.kt          # Share target
│   │   │   │   ├── data/                         # Data layer
│   │   │   │   │   ├── local/                    # Room database
│   │   │   │   │   │   ├── NotchToDoDatabase.kt
│   │   │   │   │   │   ├── dao/                  # Data Access Objects
│   │   │   │   │   │   └── entities/             # Room entities
│   │   │   │   │   ├── remote/                   # Supabase API
│   │   │   │   │   │   ├── SupabaseApi.kt
│   │   │   │   │   │   ├── SupabaseAuthInterceptor.kt
│   │   │   │   │   │   └── dto/                  # Data Transfer Objects
│   │   │   │   │   └── repository/               # Repository pattern
│   │   │   │   │       ├── AuthRepository.kt
│   │   │   │   │       ├── TaskRepository.kt
│   │   │   │   │       └── OrbRepository.kt
│   │   │   │   ├── domain/                       # Business logic
│   │   │   │   │   └── model/                    # Domain models
│   │   │   │   │       ├── Task.kt
│   │   │   │   │       ├── Orb.kt
│   │   │   │   │       └── AuthSession.kt
│   │   │   │   ├── di/                           # Dependency injection
│   │   │   │   │   └── AppModule.kt
│   │   │   │   ├── util/                         # Utilities
│   │   │   │   │   ├── DebugLog.kt
│   │   │   │   │   └── SecurePreferences.kt
│   │   │   │   ├── workers/                      # Background workers
│   │   │   │   │   └── SyncWorker.kt
│   │   │   │   └── widget/                       # Home screen widget
│   │   │   │       └── TaskWidgetReceiver.kt
│   │   │   ├── res/                              # Resources
│   │   │   │   ├── values/                       # Strings, colors, themes
│   │   │   │   ├── layout/                       # XML layouts (widget)
│   │   │   │   └── xml/                          # Config files
│   │   │   └── AndroidManifest.xml
│   │   └── test/                                 # Unit tests
│   ├── build.gradle.kts                          # App-level Gradle
│   └── proguard-rules.pro                        # ProGuard rules
├── gradle/                                        # Gradle wrapper
├── build.gradle.kts                              # Project-level Gradle
├── settings.gradle.kts                           # Gradle settings
├── gradle.properties                             # Gradle properties
└── README.md                                     # This file
```

### Data Flow

```
┌──────────────────┐
│  Compose UI      │ (StateFlow)
│  (Screen)        │
└────────┬─────────┘
         │
         ↓
┌──────────────────┐
│  ViewModel       │ (Hilt injected)
└────────┬─────────┘
         │
         ↓
┌──────────────────┐
│  Repository      │ (Offline-first)
└────────┬─────────┘
         │
         ├────────────→ ┌──────────────────┐
         │              │  Room Database   │ (Local cache)
         │              └──────────────────┘
         │
         └────────────→ ┌──────────────────┐
                        │  Supabase API    │ (Remote sync)
                        └──────────────────┘
```

## Setup Instructions

### Prerequisites

1. **Android Studio**: Hedgehog (2023.1.1) or later
2. **Android SDK**: API 26+ (Android 8.0 Oreo)
3. **Kotlin**: 1.9.20+
4. **Supabase Account**: With existing NotchToDo project

### Installation Steps

#### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/NotchToDo.git
cd NotchToDo/NotchToDo-Android
```

#### 2. Configure Supabase

Edit `app/build.gradle.kts` and replace the Supabase configuration:

```kotlin
buildConfigField("String", "SUPABASE_URL", "\"https://your-project.supabase.co\"")
buildConfigField("String", "SUPABASE_ANON_KEY", "\"your-anon-key-here\"")
```

Get your Supabase credentials:
- Go to [Supabase Dashboard](https://app.supabase.com)
- Select your NotchToDo project
- Navigate to **Settings > API**
- Copy **Project URL** and **anon/public key**

#### 3. Open in Android Studio

```bash
# Open Android Studio
# File > Open > Select NotchToDo-Android folder
```

#### 4. Sync Gradle

Android Studio will automatically sync Gradle files. If not:
- Click "Sync Now" in the notification bar
- Or: File > Sync Project with Gradle Files

#### 5. Build and Run

1. Connect an Android device or start an emulator (API 26+)
2. Click the **Run** button (▶) or press **Shift+F10**
3. Sign in with your Supabase account

## Development Guide

### Building the App

#### Debug Build
```bash
./gradlew assembleDebug
```

#### Release Build
```bash
./gradlew assembleRelease
```

### Running Tests

#### Unit Tests
```bash
./gradlew test
```

#### Instrumented Tests
```bash
./gradlew connectedAndroidTest
```

### Code Quality

#### Lint
```bash
./gradlew lint
```

### Adding New Features

#### 1. Creating a New Screen

```kotlin
// 1. Create domain model (if needed)
data class MyData(...)

// 2. Add repository method
suspend fun getMyData(): Flow<List<MyData>>

// 3. Create ViewModel
@HiltViewModel
class MyViewModel @Inject constructor(
    private val repository: MyRepository
) : ViewModel() {
    val data = repository.getMyData()
        .stateIn(viewModelScope, SharingStarted.Lazily, emptyList())
}

// 4. Create Composable screen
@Composable
fun MyScreen(viewModel: MyViewModel = hiltViewModel()) {
    val data by viewModel.data.collectAsState()
    // ... UI implementation
}

// 5. Add to navigation
composable("my_screen") { MyScreen() }
```

#### 2. Adding a New Supabase Table

```kotlin
// 1. Create Room entity
@Entity(tableName = "my_table")
data class MyEntity(...)

// 2. Create DAO
@Dao
interface MyDao { ... }

// 3. Create DTO for API
data class MyDto(...)

// 4. Add API endpoint
@GET("rest/v1/my_table")
suspend fun getMyData(): Response<List<MyDto>>

// 5. Create repository
class MyRepository @Inject constructor(
    private val dao: MyDao,
    private val api: SupabaseApi
) { ... }
```

### Debugging

#### Enable Verbose Logging

```kotlin
// In Application onCreate()
if (BuildConfig.DEBUG) {
    DebugLog.enableAll()
}
```

#### View Logs by Category

```bash
# Auth logs
adb logcat -s NotchToDo | grep "\[AUTH\]"

# Sync logs
adb logcat -s NotchToDo | grep "\[SYNC\]"

# Network logs
adb logcat -s NotchToDo | grep "\[NETWORK\]"
```

#### Inspect Database

```bash
# Pull database from device
adb pull /data/data/com.notchtodo/databases/notchtodo_database

# Open with SQLite browser
sqlite3 notchtodo_database
```

## Sync Strategy

### Offline-First Architecture

1. **Local-First Operations**: All CRUD operations write to Room database first
2. **Background Sync**: WorkManager syncs every 15 minutes when online
3. **Manual Sync**: Pull-to-refresh or "Sync Now" in settings
4. **Conflict Resolution**: Server version wins (last-write-wins with version field)

### Sync Flow

```
User Action (Create/Update Task)
         ↓
Write to Room Database (immediate)
         ↓
Mark as sync_pending = true
         ↓
Attempt Remote Sync (background)
         ↓
On Success: sync_pending = false
On Failure: Retry later via WorkManager
```

### Handling Conflicts

- Each record has a `version` field (auto-incremented on server)
- During sync, compare local vs remote version
- If remote.version > local.version, use remote data
- If local has changes (sync_pending), push to server

## Authentication

### Supported Methods

1. **Email/Password**: Direct Supabase authentication
2. **Google Sign-In**: OAuth via Supabase (planned)

### Session Management

- Access token stored in EncryptedSharedPreferences
- Refresh token used to renew expired sessions
- Automatic token refresh before expiry (5 min buffer)
- Session persisted across app restarts

### Implementation

```kotlin
// Sign in
authRepository.signIn(email, password)

// Sign up
authRepository.signUp(email, password)

// Sign out
authRepository.signOut()

// Check auth state
authRepository.authState.collectAsState()
```

## Testing

### Manual Testing Checklist

**Authentication**
- [ ] Sign up with new account
- [ ] Sign in with existing account
- [ ] Sign out
- [ ] Session persists after app restart

**Tasks**
- [ ] Create task
- [ ] Edit task
- [ ] Change task status
- [ ] Delete task
- [ ] Search tasks
- [ ] Sync with macOS/iOS

**Orbs**
- [ ] Create orb
- [ ] Edit orb name
- [ ] View tasks in orb
- [ ] Delete orb
- [ ] Sync with macOS/iOS

**Offline Mode**
- [ ] Disable network
- [ ] Create/edit tasks offline
- [ ] Enable network
- [ ] Verify sync works

**Dark Theme**
- [ ] Enable dark theme in system settings
- [ ] Verify app updates theme
- [ ] Check all screens render correctly

### Automated Tests

#### Unit Tests
- Repository tests with mocked DAO and API
- ViewModel tests with test coroutines
- Data model conversion tests

#### Integration Tests
- Room database tests
- API client tests with MockWebServer

#### UI Tests (Planned)
- Compose UI tests with ComposeTestRule
- Navigation flow tests
- End-to-end user scenarios

## Performance

### Optimization Strategies

1. **Lazy Loading**: Tasks loaded on-demand
2. **Flow-Based UI**: Reactive UI updates with StateFlow
3. **Background Processing**: Heavy operations in WorkManager
4. **Efficient Queries**: Indexed database columns
5. **Image Optimization**: Vector drawables for all icons
6. **ProGuard**: Code shrinking and obfuscation in release

### Memory Management

- Use `viewModelScope` for coroutines (auto-cleanup)
- Lifecycle-aware components
- Avoid memory leaks with proper cleanup
- Use `collectAsState()` for Flow in Compose

## Security

### Data Protection

- Secure token storage with EncryptedSharedPreferences
- HTTPS for all network requests
- Room database encrypted when device locked
- No sensitive data in logs (release builds)
- ProGuard obfuscation for release APK

### Permissions

- **INTERNET**: Required for Supabase sync
- **ACCESS_NETWORK_STATE**: Check connectivity before sync
- **RECORD_AUDIO**: Voice input (planned)
- **POST_NOTIFICATIONS**: Task reminders (Android 13+)

### Best Practices

- Row Level Security (RLS) on Supabase
- User can only access their own data
- No hardcoded secrets (use BuildConfig)
- Validate all user inputs
- Sanitize data before display

## Deployment

### Building Release APK

```bash
# 1. Update version in build.gradle.kts
versionCode = 2
versionName = "1.1.0"

# 2. Generate release keystore (first time only)
keytool -genkey -v -keystore notchtodo-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias notchtodo

# 3. Build release APK
./gradlew assembleRelease

# 4. APK location
app/build/outputs/apk/release/app-release.apk
```

### Publishing to Google Play

1. **Create App Listing**: Google Play Console
2. **Upload APK/AAB**: Use Android App Bundle (AAB)
3. **Configure Store Listing**: Description, screenshots, etc.
4. **Set Pricing**: Free
5. **Content Rating**: PEGI 3 / Everyone
6. **Submit for Review**

### App Bundle (Recommended)

```bash
# Build app bundle
./gradlew bundleRelease

# Output location
app/build/outputs/bundle/release/app-release.aab
```

## Troubleshooting

### Common Issues

#### Build Fails

```bash
# Clean and rebuild
./gradlew clean
./gradlew build
```

#### Sync Not Working

1. Check Supabase credentials in `build.gradle.kts`
2. Verify network connection
3. Check logs: `adb logcat -s NotchToDo | grep "\[SYNC\]"`
4. Manually trigger sync in Settings

#### Database Errors

```bash
# Clear app data
adb shell pm clear com.notchtodo

# Or uninstall and reinstall
```

#### Hilt Injection Errors

- Ensure all classes are properly annotated with `@Inject`
- Verify `@HiltAndroidApp` on Application class
- Check `@AndroidEntryPoint` on Activities/Fragments

## Contributing

### Code Style

- Follow [Kotlin Coding Conventions](https://kotlinlang.org/docs/coding-conventions.html)
- Use meaningful variable names
- Add KDoc comments for public APIs
- Keep functions small and focused
- Use Compose best practices

### Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit changes: `git commit -am 'Add my feature'`
4. Push to branch: `git push origin feature/my-feature`
5. Submit pull request

### Reporting Issues

- Use GitHub Issues
- Include Android version, device model
- Provide logcat output if applicable
- Describe steps to reproduce

## Roadmap

### Version 1.1 (Next Release)
- [ ] Voice input for task creation
- [ ] Rich text notes editor
- [ ] Due date reminders
- [ ] Task attachments

### Version 1.2
- [ ] Glance-based home screen widget
- [ ] Wear OS companion app
- [ ] Recurring tasks
- [ ] Task templates

### Version 2.0
- [ ] Advanced search with filters
- [ ] Task analytics
- [ ] Collaboration features
- [ ] Custom themes

## License

MIT License - See LICENSE file in root repository

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/NotchToDo/issues)
- **Email**: support@notchtodo.com
- **Documentation**: [docs.notchtodo.com](https://docs.notchtodo.com)

## Credits

- Built with Jetpack Compose and Material Design 3
- Powered by Supabase
- Syncs with macOS and iOS NotchToDo apps
- Developed by the NotchToDo team

## Changelog

### Version 1.0.0 (2025-01-XX)
- Initial Android release
- Core task management features
- Supabase sync with macOS/iOS
- Material Design 3 UI
- Email/password authentication
- Offline support
- Background sync
- Share target integration
