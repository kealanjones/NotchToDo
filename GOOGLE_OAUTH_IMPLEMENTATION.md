# Google OAuth & Apple Sign-In Implementation for NotchToDo

## Overview

This document describes the comprehensive authentication improvements made to the NotchToDo macOS app, including Google OAuth 2.0, Apple Sign-In, and enhanced UX features.

---

## What's Been Implemented

### 1. Google OAuth 2.0 Sign-In

**Files Created:**
- `/NotchToDo/NotchToDo/Supabase/SupabaseOAuthHandler.swift`

**Files Modified:**
- `/NotchToDo/NotchToDo/Auth/AuthWindowController.swift`
- `/NotchToDo/NotchToDo/AppDelegate.swift`

**Features:**
- ✅ Google Sign-In button with proper branding
- ✅ OAuth 2.0 flow using Supabase backend
- ✅ Opens Google authentication in default browser
- ✅ Handles OAuth callback via custom URL scheme (`notch://auth-callback`)
- ✅ Secure token storage in macOS Keychain
- ✅ Automatic session management and sync

**How It Works:**
1. User clicks "Continue with Google" button
2. App constructs Supabase OAuth URL: `https://[project].supabase.co/auth/v1/authorize?provider=google&redirect_to=notch://auth-callback`
3. Browser opens for Google authentication
4. User signs in with Google
5. Google redirects to Supabase
6. Supabase redirects to `notch://auth-callback#access_token=...&refresh_token=...`
7. macOS launches NotchToDo with the URL
8. AppDelegate's `handleIncomingURL` catches the callback
9. Tokens are extracted and stored in Keychain
10. User is authenticated, data syncs, onboarding begins

---

### 2. Apple Sign-In Integration

**Files Modified:**
- `/NotchToDo/NotchToDo/Auth/AuthWindowController.swift`

**Features:**
- ✅ Apple Sign-In button with system integration
- ✅ Uses native AuthenticationServices framework
- ✅ Follows Apple's Human Interface Guidelines
- ✅ Retrieves user email and name
- ✅ Handles ID token exchange

**Status:**
- ⚠️ **Partially Implemented** - Apple Sign-In button is functional and retrieves ID tokens, but Supabase integration for token exchange needs to be completed.
- **TODO:** Implement `signInWithIdToken` API call to exchange Apple ID token with Supabase session

---

### 3. Authentication UX Improvements

**Enhanced AuthViewController Features:**

#### a) Password Visibility Toggle
- Eye icon button to show/hide password
- Switches between `NSSecureTextField` (hidden) and `NSTextField` (visible)
- Works for both password and confirm password fields
- Icon changes: `eye` → `eye.slash`

#### b) Forgot Password Link
- "Forgot password?" button (sign-in mode only)
- Shows email input dialog
- **TODO:** Connect to Supabase password reset API

#### c) Input Validation
- **Created:** `/NotchToDo/NotchToDo/Utilities/InputValidator.swift`
- Email validation with RFC 5322 compliance
- Password strength validation (min 6 chars, must have letters + numbers)
- Sanitization to prevent injection attacks
- User-friendly error messages

#### d) Improved UI Design
- Social login buttons at top
- "or" divider separator
- Better spacing and typography
- Larger window (520x720) for better layout
- Social buttons with proper icons and colors:
  - Google: White background, gray border
  - Apple: Black background, white text

#### e) Loading States
- New `oauthLoading` state for OAuth flows
- Spinner indicator during authentication
- Disabled buttons during loading
- Blue info message during OAuth: "Opening Google Sign-In in your browser..."

#### f) Error Handling
- Context-aware error messages
- Red text for errors, blue for info
- Multi-line error label (up to 3 lines)
- Errors cleared when switching between sign-in/sign-up

---

## File Structure

```
NotchToDo/
├── Auth/
│   └── AuthWindowController.swift (redesigned with social login)
├── Supabase/
│   ├── SupabaseAuthManager.swift (existing, handles sessions)
│   ├── SupabaseOAuthHandler.swift (NEW - OAuth flow logic)
│   ├── SupabaseService.swift (existing, API layer)
│   └── SupabaseEnvironment.swift (existing, config)
├── Utilities/
│   ├── KeychainHelper.swift (existing, secure storage)
│   └── InputValidator.swift (NEW - input validation)
└── AppDelegate.swift (updated OAuth callback handling)
```

---

## Architecture & Security

### OAuth Flow Architecture

```
User Click "Google Sign-In"
         ↓
AuthViewController.signInWithGoogle()
         ↓
SupabaseAuthManager.signInWithOAuth(provider: .google)
         ↓
Build OAuth URL with redirect_to=notch://auth-callback
         ↓
NSWorkspace.open(oauthURL) → Opens browser
         ↓
[User authenticates with Google in browser]
         ↓
Google → Supabase → notch://auth-callback#tokens
         ↓
macOS launches app with URL
         ↓
AppDelegate.handleIncomingURL()
         ↓
SupabaseAuthManager.handleOAuthRedirect(url)
         ↓
Extract & validate tokens
         ↓
KeychainHelper.setString(accessToken, "SupabaseAccessToken")
         ↓
Session established, sync starts
         ↓
Auth window closes, onboarding begins
```

### Security Measures

1. **Secure Token Storage:**
   - Access tokens stored in macOS Keychain (not UserDefaults)
   - KeychainHelper uses `kSecClassGenericPassword`
   - Service identifier: app bundle ID

2. **Input Validation:**
   - Email: RFC 5322 regex, max 320 chars
   - Password: Min 6 chars, requires letters + numbers, max 128 chars
   - Control character sanitization
   - XSS prevention via character filtering

3. **OAuth Security:**
   - Custom URL scheme (`notch://`) only opens NotchToDo
   - Tokens never logged or exposed
   - URL scheme registered in Info.plist
   - Redirect URL validated before processing

4. **Session Management:**
   - Tokens auto-refresh 5 minutes before expiry
   - Session cleared on logout
   - Sync pauses when unauthenticated

---

## Configuration Required

### 1. Supabase Dashboard Setup

You must configure Google OAuth in your Supabase project:

1. Go to: https://supabase.com/dashboard/project/[your-project]/auth/providers
2. Enable **Google** provider
3. Add **Authorized redirect URLs:**
   ```
   notch://auth-callback
   ```
4. Get Google OAuth credentials:
   - Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
   - Create OAuth 2.0 Client ID (type: Web application)
   - Add authorized redirect URI: `https://[your-project-ref].supabase.co/auth/v1/callback`
5. Paste Client ID and Secret into Supabase

### 2. Info.plist (Already Configured)

The custom URL scheme is already set up:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.notchtodo.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>notch</string>
        </array>
    </dict>
</array>
```

### 3. Apple Sign-In Setup (For Full Implementation)

1. **Apple Developer Account:**
   - Enable "Sign in with Apple" capability in Xcode
   - Add capability to app identifier on developer.apple.com

2. **Supabase Configuration:**
   - Enable Apple provider in Supabase dashboard
   - Configure Service ID and private key

3. **Code Completion:**
   - Implement token exchange in `AuthViewController.authorizationController(didCompleteWithAuthorization:)`
   - Replace TODO comment with Supabase API call

---

## Testing Guide

### Test Email/Password Authentication

1. Run the app
2. Click "Create Account"
3. Fill in email and password
4. Click password eye icon - verify password visibility toggle works
5. Submit form
6. Verify account creation succeeds
7. Sign out
8. Click "Sign In"
9. Click "Forgot password?" - verify dialog appears
10. Sign in with credentials

### Test Google OAuth

**Prerequisites:**
- Google provider must be enabled in Supabase dashboard
- Authorized redirect URL configured

**Steps:**
1. Run the app
2. When auth window appears, click "Create Account" or "Sign In"
3. Click "Continue with Google"
4. Verify:
   - Blue message appears: "Opening Google Sign-In in your browser..."
   - Browser opens with Google sign-in page
5. Sign in with Google account
6. Verify:
   - Browser shows "Success" or redirects
   - App returns to foreground
   - Auth window closes
   - Onboarding begins (if first time)
   - Tasks/orbs load
7. Check logs for: "Processed Supabase OAuth callback successfully"

### Test Apple Sign-In

**Prerequisites:**
- Apple Sign-In capability enabled in Xcode
- Signed in to macOS with Apple ID

**Steps:**
1. Run the app
2. Click "Create Account" or "Sign In"
3. Click "Continue with Apple"
4. Verify:
   - Apple Sign-In dialog appears
   - Face ID / Touch ID / Password prompt
5. Authorize
6. Verify:
   - Currently shows "Apple Sign-In integration coming soon!"
   - **After full implementation:** Session created, auth window closes

### Test Input Validation

**Email Validation:**
- Enter invalid email: `notanemail` → Error: "Please enter a valid email address"
- Enter no email → Error: "Email cannot be empty"
- Enter valid email: `test@example.com` → No error

**Password Validation:**
- Enter < 6 chars: `abc12` → Error: "Password must be at least 6 characters"
- Enter only letters: `abcdef` → Error: "Password must be at least 6 characters with a mix of letters and numbers"
- Enter only numbers: `123456` → Error: "Password must be at least 6 characters with a mix of letters and numbers"
- Enter valid: `abc123` → No error

**Password Confirmation:**
- Sign up mode: Enter different passwords → Error: "Passwords do not match"
- Sign up mode: Enter matching passwords → No error

### Test Error Scenarios

1. **No Internet:**
   - Disable network
   - Try Google OAuth → Should show browser error
   - Try email sign-in → Should show Supabase error

2. **Invalid Credentials:**
   - Enter wrong email/password
   - Verify error message displays

3. **OAuth Cancellation:**
   - Click Google button
   - Close browser without signing in
   - App should remain on auth screen

---

## Known Limitations & TODOs

### Implemented ✅
- Google OAuth flow (end-to-end)
- Apple Sign-In UI (ID token retrieval)
- Password visibility toggle
- Input validation
- Forgot password dialog
- Loading states
- Error handling
- OAuth callback handling
- Session management
- Onboarding integration

### Partially Implemented ⚠️
- **Apple Sign-In:** Token retrieved, but Supabase exchange not implemented
- **Password Reset:** Dialog exists, but API call not implemented

### Not Yet Implemented ❌
- Email verification flow
- Multi-factor authentication (MFA)
- Social account linking (merge accounts)
- Session timeout warnings
- Remember me / biometric unlock

---

## Troubleshooting

### Google OAuth Not Working

**Symptom:** Browser opens but shows error
**Solutions:**
1. Check Supabase Dashboard → Auth → Providers → Google is enabled
2. Verify redirect URL includes `notch://auth-callback`
3. Check Google Cloud Console → Credentials → Authorized redirect URIs includes Supabase callback URL
4. Check Xcode console for error logs

**Symptom:** Browser redirects but app doesn't respond
**Solutions:**
1. Verify Info.plist has `notch` URL scheme registered
2. Check AppDelegate → `setupURLHandling()` is called in `applicationDidFinishLaunching`
3. Check Xcode console for "Processed Supabase OAuth callback" message
4. Verify `handleIncomingURL` method is called (add breakpoint)

### Password Toggle Not Working

**Symptom:** Eye button doesn't show password
**Solutions:**
1. Verify both `passwordField` and `passwordTextField` are initialized
2. Check `togglePasswordVisibility()` method is connected to button
3. Ensure `isPasswordVisible` state is updating

### Apple Sign-In Shows "Coming Soon"

This is expected! The ID token retrieval works, but Supabase integration is incomplete.

**To complete:**
1. Implement Supabase `signInWithIdToken` API
2. Replace TODO comment in `authorizationController(didCompleteWithAuthorization:)`
3. Handle session creation and sync

---

## Code Snippets

### Accessing Supabase Auth Manager from AuthViewController

```swift
guard let authManager = (NSApp.delegate as? AppDelegate)?.supabaseAuthManager else {
    showError("Authentication not available")
    return
}

authManager.signInWithOAuth(provider: .google)
```

### Building OAuth URL Manually

```swift
let config = SupabaseEnvironment.configuration()
let url = URL(string: "\(config.projectURL)/auth/v1/authorize?provider=google&redirect_to=notch://auth-callback")
```

### Validating User Input

```swift
import InputValidator

do {
    let email = try InputValidator.validateEmail(emailField.stringValue)
    let password = try InputValidator.validatePassword(passwordField.stringValue)
    // Proceed with authentication
} catch {
    showError(error.localizedDescription)
}
```

---

## Recommended Next Steps

1. **Complete Apple Sign-In:**
   - Research Supabase Apple ID token API
   - Implement token exchange
   - Test end-to-end flow

2. **Implement Password Reset:**
   - Use Supabase password recovery API
   - Send email with reset link
   - Handle reset confirmation

3. **Add Email Verification:**
   - Require email confirmation for new accounts
   - Show "Check your email" screen
   - Handle verification link

4. **Enhanced Security:**
   - Add rate limiting for failed login attempts
   - Implement session timeout warnings
   - Add biometric authentication option (Touch ID / Face ID)

5. **Testing:**
   - Write unit tests for InputValidator
   - Write integration tests for OAuth flow
   - Test with multiple Google accounts
   - Test account creation, sign in, sign out, re-sign in

6. **User Experience:**
   - Add "Remember me" checkbox
   - Add loading skeleton while checking session
   - Add smooth transitions between auth states
   - Add success animations

---

## References

- [Supabase OAuth Documentation](https://supabase.com/docs/guides/auth/social-login)
- [Apple Sign-In Documentation](https://developer.apple.com/documentation/authenticationservices)
- [Google OAuth 2.0 Documentation](https://developers.google.com/identity/protocols/oauth2)
- [macOS URL Schemes](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)

---

## Support

For issues or questions:
1. Check Xcode console logs (`DebugLog` category: `.sync`)
2. Verify Supabase dashboard configuration
3. Test OAuth flow in browser manually
4. Check this documentation for troubleshooting steps

---

**Last Updated:** January 2025
**Version:** 1.0
**Status:** Production Ready (Google OAuth), Apple Sign-In Pending Completion
