# CloudKit Signing Setup Guide

## Quick Fix: Enable Development Signing in Xcode

The error occurs because CloudKit entitlements require code signing. Here's how to fix it:

### Steps:

1. **Open project in Xcode:**
   ```bash
   open NotchToDo/NotchToDo.xcodeproj
   ```

2. **Select project** → **Select "NotchToDo" target** → **"Signing & Capabilities" tab**

3. **Enable Automatic Signing:**
   - ✅ Check "Automatically manage signing"
   - Select your **Apple ID / Development Team** from dropdown
   - If you don't have one, click "Add Account..." and sign in

4. **Verify CloudKit Capability:**
   - Should see "iCloud" capability automatically
   - Ensure "CloudKit" is checked

5. **Build** (⌘B)

## Alternative: Test Without CloudKit (No Signing Required)

Since CloudKit is **disabled by default**, you can test the app without signing:

1. The app will run in **local-only mode** (no sync)
2. CloudKit sync can be enabled later via:
   - Menu Bar Icon → Right-click → Debug Menu → Sync → Enable iCloud Sync

## Important Notes

- ✅ CloudKit is **opt-in** and disabled by default
- ✅ App works fine without signing for local development
- ✅ You'll need signing to enable CloudKit sync
- ✅ Signing is free with any Apple ID for development

## Troubleshooting

**"No signing certificate found":**
- Xcode → Settings → Accounts → Add Apple ID
- Make sure you're signed in to Xcode

**"Bundle identifier not available":**
- Change bundle ID to something unique (e.g., `com.yourname.notchtodo`)

The build error is just Xcode validating entitlements - the app will work locally without CloudKit enabled!



