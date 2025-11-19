# NotchToDo iOS - Quick Start Guide

Get up and running with NotchToDo iOS in 5 minutes.

## Prerequisites

- Mac with Xcode 15.0 or later
- iOS 16.0+ device or simulator
- Supabase account (free tier works)

## Step 1: Get Supabase Credentials (2 minutes)

1. Go to [supabase.com](https://supabase.com) and sign in
2. Create a new project or select existing one
3. Go to **Settings → API**
4. Copy these two values:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon/public key**: `eyJhbGc...` (long string)

## Step 2: Configure the App (1 minute)

1. Open `NotchToDo-iOS/NotchToDo-iOS/Resources/Info.plist`
2. Find these lines and replace with your credentials:

```xml
<key>SupabaseURL</key>
<string>YOUR_SUPABASE_PROJECT_URL</string>
<key>SupabaseAnonKey</key>
<string>YOUR_SUPABASE_ANON_KEY</string>
```

**Example**:
```xml
<key>SupabaseURL</key>
<string>https://abcdefgh.supabase.co</string>
<key>SupabaseAnonKey</key>
<string>eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...</string>
```

## Step 3: Build & Run (2 minutes)

1. Open `NotchToDo-iOS.xcodeproj` in Xcode
2. Select a simulator (iPhone 15 Pro recommended)
3. Press **⌘R** to build and run
4. Wait for build to complete (~30 seconds first time)

## Step 4: Create Account & First Task

### Sign Up
1. App opens to sign-up screen
2. Enter email and password
3. Tap **Sign Up**
4. You're in!

### Create Your First Task
1. Tap the **+** button in top-right
2. Enter a task title: "Buy groceries"
3. Select or create an orb: "Personal"
4. Tap **Create**
5. Done! Your task appears in the list

### Try Voice Input (Optional)
1. Tap **+** to create task
2. Tap the **microphone icon** next to title field
3. Grant permissions if prompted
4. Tap **Start Recording**
5. Say: "Call dentist tomorrow"
6. Tap **Stop Recording**
7. Review text, then tap **Done**
8. Fill in details and create task

## Step 5: Test Sync with macOS (Optional)

If you have the macOS app:

1. **macOS**: Sign in with same email/password
2. **macOS**: Create a task called "Test from Mac"
3. **iOS**: Pull down to refresh
4. You should see "Test from Mac" appear!

## Troubleshooting

### "Supabase configuration missing"
- Double-check Info.plist has correct URL and key
- Ensure no extra spaces or line breaks
- Clean build folder: **⌘⇧K**

### Voice input not working
- Grant microphone permission in Settings app
- Restart the app after granting permission
- Try on a real device (simulator has no mic)

### Sync not working
- Check internet connection
- Verify Supabase credentials
- Check Supabase dashboard for errors

## What's Next?

- Read the full [README.md](README.md) for detailed documentation
- Check [IMPLEMENTATION_REPORT.md](IMPLEMENTATION_REPORT.md) for architecture details
- Join our [Discord](https://discord.gg/notchtodo) for support

## Quick Tips

- **Search**: Pull down on Tasks tab to reveal search bar
- **Edit Task**: Tap any task, then tap **Edit**
- **Change Status**: Use segmented control in task details
- **Delete Task**: Edit task, scroll down, tap **Delete Task**
- **Sync Now**: Go to Settings → Tap **Sync Now**

---

**Need Help?**
- Email: support@notchtodo.com
- Issues: [GitHub Issues](https://github.com/yourusername/NotchToDo/issues)
- Docs: [docs.notchtodo.com](https://docs.notchtodo.com)
