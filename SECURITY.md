# Security Documentation

## Overview

NotchToDo implements comprehensive security measures to protect user data and prevent common vulnerabilities. This document outlines our security architecture, best practices, and threat mitigations.

---

## Table of Contents

1. [Token Storage](#token-storage)
2. [Input Validation](#input-validation)
3. [Data Encryption](#data-encryption)
4. [Authentication](#authentication)
5. [Audit Logging](#audit-logging)
6. [Security Best Practices](#security-best-practices)
7. [Vulnerability Reporting](#vulnerability-reporting)

---

## Token Storage

### Implementation: macOS Keychain

All authentication tokens are stored in the macOS Keychain, leveraging Apple's secure credential storage system.

**Location**: `NotchToDo/Utilities/KeychainHelper.swift`

### Token Types Stored

- **Access Token**: Supabase JWT access token
  - Key: `SupabaseAccessToken`
  - Stored in: Keychain
  - Accessibility: `kSecAttrAccessibleAfterFirstUnlock`

- **Refresh Token**: Supabase refresh token
  - Key: `SupabaseRefreshToken`
  - Stored in: Keychain
  - Accessibility: `kSecAttrAccessibleAfterFirstUnlock`

- **Token Expiry**: Timestamp of token expiration
  - Key: `SupabaseAccessTokenExpiry`
  - Stored in: UserDefaults (non-sensitive timestamp)

### KeychainHelper Features

- **Secure Attributes**:
  - `kSecAttrAccessibleAfterFirstUnlock`: Balances security with usability
  - Service identifier: App bundle ID
  - Account identifier: Unique key per credential

- **Error Handling**: Comprehensive status code handling for all Keychain operations
- **Audit Logging**: All operations logged (without exposing token values)
- **Automatic Cleanup**: Tokens cleared on logout

### Security Properties

✅ **Encrypted at rest** - Keychain uses hardware encryption
✅ **Per-user isolation** - Each macOS user has separate Keychain
✅ **Sandboxed** - Only NotchToDo can access its Keychain items
✅ **No plaintext storage** - Tokens never written to UserDefaults or files

### Token Lifecycle

```swift
// Sign In Flow
1. User authenticates → SupabaseAuthManager
2. Tokens received from Supabase
3. KeychainHelper.setString() stores tokens
4. SupabaseSyncManager activated with access token

// Token Refresh
1. SupabaseAuthManager checks expiry (5 min before expiration)
2. Refresh token used to obtain new access token
3. New tokens stored in Keychain
4. Old tokens overwritten

// Sign Out Flow
1. User logs out → AppDelegate.handleSupabaseSignOut()
2. KeychainHelper.setString(nil, ...) deletes tokens
3. UserDefaults expiry timestamp cleared
4. Local Core Data cleared
5. Sync manager paused
```

---

## Input Validation

### Implementation: InputValidator

All user input is validated and sanitized to prevent injection attacks and ensure data integrity.

**Location**: `NotchToDo/Security/InputValidator.swift`

### Validation Rules

#### Email Addresses
- **Max Length**: 254 characters (RFC 5321)
- **Format**: RFC 5322 compliant regex
- **Malicious Pattern Detection**: Checks for XSS, SQL injection attempts
- **Example**:
  ```swift
  let email = try InputValidator.validateEmail("user@example.com")
  ```

#### Passwords
- **Min Length**: 8 characters
- **Max Length**: 128 characters
- **Requirements**:
  - At least one uppercase letter
  - At least one lowercase letter
  - At least one number
  - At least one special character (!@#$%^&* etc.)
- **Checks**:
  - Rejects common passwords (password, 123456, etc.)
  - Rejects sequential characters (abc, 123)
- **Sign Up**: Full validation enforced
- **Sign In**: Only minimum length checked (user already has account)

#### Task Titles
- **Min Length**: 1 character
- **Max Length**: 500 characters
- **Sanitization**: Control characters removed, emojis preserved
- **Malicious Content**: XSS, SQL injection pattern detection

#### Task Notes
- **Max Length**: 10,000 characters
- **Sanitization**: Control characters removed
- **Optional**: Can be null/empty

#### Orb (Project) Names
- **Min Length**: 1 character
- **Max Length**: 100 characters
- **Sanitization**: Control characters removed
- **Malicious Content**: Pattern detection

#### Voice Commands
- **Max Length**: 1,000 characters
- **Sanitization**: Control characters removed
- **Critical**: Voice input is especially vulnerable to exploitation

### Malicious Pattern Detection

The validator checks for:

**SQL Injection**:
```
drop table, delete from, insert into, update, union select,
exec(, execute(, --, /*, xp_, ;--
```

**XSS (Cross-Site Scripting)**:
```
<script, </script, javascript:, onerror=, onload=, onclick=,
<iframe, eval(, expression(, vbscript:, data:text/html
```

**Command Injection**:
```
$(, `, |, &&, ||, ;, newlines
```

### Integration Points

Input validation is enforced at:

1. **Authentication** (`AuthViewController.swift`)
   - Email validation on sign in/sign up
   - Password strength validation on sign up

2. **Task Creation** (`NotchOverlayController.swift`)
   - Task title validation
   - Task notes validation

3. **Project Creation** (`NotchOverlayController.swift`)
   - Orb name validation

4. **Voice Commands** (`IntentRouter.swift`)
   - Transcript sanitization
   - Command validation

---

## Data Encryption

### Current State

**Core Data**: ⚠️ Not encrypted at rest (planned enhancement)

### Local Data Storage

- **Location**: `~/Library/Application Support/com.notchtodo.app/NotchDataModel.sqlite`
- **Protection**: macOS file permissions (user-only access)
- **Entities**: TaskEntity, OrbEntity, SyncOutboxItem

### Encryption Recommendations (Future)

Two approaches for encrypting Core Data:

#### Option 1: NSPersistentStoreDescription Encryption
```swift
let description = NSPersistentStoreDescription(url: storeURL)
description.setOption(FileProtectionType.complete as NSObject,
                      forKey: NSPersistentStoreFileProtectionKey)
```

#### Option 2: Selective Field Encryption
```swift
// Encrypt task.notes before saving
let encrypted = encryptString(task.notes, key: userKey)
task.encryptedNotes = encrypted
```

**Recommendation**: Implement Option 1 for simplicity and complete protection.

---

## Authentication

### Supabase Integration

**Location**: `NotchToDo/Supabase/SupabaseAuthManager.swift`

### Authentication Flows

#### Sign Up
1. User provides email + password
2. InputValidator validates credentials
3. Supabase `/auth/signup` called
4. Response contains access token + refresh token
5. Tokens stored in Keychain
6. User data sync initiated

#### Sign In
1. User provides email + password
2. InputValidator validates email format
3. Supabase `/auth/token?grant_type=password` called
4. Response contains tokens
5. Tokens stored in Keychain
6. Sync initiated

#### OAuth (Planned)
- Redirect URL: `notch://auth-callback`
- Handler: `AppDelegate.handleIncomingURL`
- Tokens extracted from URL fragment

#### Token Refresh
- **Trigger**: Token expires in < 5 minutes
- **Automatic**: Background refresh via `SupabaseAuthManager.refreshSessionIfNeeded()`
- **Retry**: On 401 Unauthorized responses from API

#### Logout
- Clear Keychain tokens
- Clear UserDefaults expiry
- Clear Core Data (optional, based on user choice)
- Stop sync manager

### Session Management

- **Session Object**: `SupabaseAuthManager.Session`
  - accessToken: String
  - refreshToken: String?
  - expiresAt: Date?

- **Notification**: `.supabaseAuthSessionChanged`
  - Posted when session changes
  - SyncManager observes and updates token

---

## Audit Logging

### Security Events Logged

All security-critical operations are logged via `DebugLog`:

#### Keychain Operations
```
🔐 Keychain: Storing value for key 'SupabaseAccessToken'
🔐 Keychain: Retrieved value for 'SupabaseRefreshToken'
🔐 Keychain: Deleted item for 'SupabaseAccessToken'
⚠️ Keychain: Update failed for 'key' with status -25300
```

#### Authentication
```
Attempting sign in for user
Authentication successful
Authentication failed: Invalid credentials
Email validation passed
⚠️ Validation error: Password is too weak
```

#### Input Validation
```
❌ Validation error: Task title must not exceed 500 characters
❌ Validation error: Email is invalid: Must be a valid email address
⚠️ Malicious content detected in Task title: pattern '<script'
```

#### Sync Operations
```
Supabase sync idle
Supabase sync running
Supabase 401 unauthorized — attempting token refresh
JWT refresh after 401
```

### Logging Categories

- `.sync` - Authentication, Keychain, Supabase operations
- `.app` - General app events, validation errors
- `.persistence` - Core Data operations
- `.speech` - Voice command processing

### Production Considerations

- **Never log sensitive data** (passwords, tokens, PII)
- **Log security events** (auth attempts, validation failures)
- **Configurable verbosity** via DebugLogger categories
- **User-facing errors** sanitized to prevent information leakage

---

## Security Best Practices

### For Contributors

#### 1. Never Commit Secrets
❌ **Bad**:
```swift
let apiKey = "sk_live_1234567890abcdef" // NEVER DO THIS
```

✅ **Good**:
```swift
// Store in Info.plist (excluded from git)
let apiKey = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String
```

#### 2. Always Validate Input
❌ **Bad**:
```swift
func addTask(_ title: String) {
    task.title = title // Direct assignment, no validation!
}
```

✅ **Good**:
```swift
func addTask(_ title: String) {
    do {
        let validatedTitle = try InputValidator.validateTaskTitle(title)
        task.title = validatedTitle
    } catch {
        DebugLog.logValidationError(error, category: .app)
        showError(error.localizedDescription)
    }
}
```

#### 3. Use Keychain for Sensitive Data
❌ **Bad**:
```swift
UserDefaults.standard.set(accessToken, forKey: "token") // Plaintext!
```

✅ **Good**:
```swift
KeychainHelper.setString(accessToken, for: "SupabaseAccessToken")
```

#### 4. Sanitize User-Facing Errors
❌ **Bad**:
```swift
catch {
    showError(error.debugDescription) // May leak sensitive info!
}
```

✅ **Good**:
```swift
catch {
    DebugLog.log("Auth failed: \(error)", category: .sync)
    showError("Authentication failed. Please try again.") // Generic message
}
```

#### 5. Never Log Sensitive Data
❌ **Bad**:
```swift
DebugLog.log("User logged in with password: \(password)", category: .sync)
```

✅ **Good**:
```swift
DebugLog.log("User authentication successful", category: .sync)
```

---

## Threat Mitigation

### SQL Injection
**Risk**: ❌ None
**Reason**: Supabase uses parameterized queries; Core Data is not SQL-injectable

### XSS (Cross-Site Scripting)
**Risk**: ❌ None
**Reason**: Native macOS app, no web views; InputValidator detects XSS patterns

### Command Injection
**Risk**: ⚠️ Low
**Mitigation**: InputValidator detects shell metacharacters; voice commands sanitized

### Man-in-the-Middle (MITM)
**Risk**: ⚠️ Low
**Mitigation**:
- HTTPS enforced for Supabase (TLS 1.2+)
- Certificate pinning not implemented (relies on system trust)

### Token Theft
**Risk**: ⚠️ Low
**Mitigation**:
- Tokens in Keychain (encrypted)
- No token logging
- Auto-refresh on expiry
- Cleared on logout

### Malicious Voice Commands
**Risk**: ⚠️ Medium
**Mitigation**:
- Voice input validated via InputValidator
- Length limits enforced
- Malicious patterns detected
- Control characters stripped

---

## Known Limitations

1. **Core Data Not Encrypted**
   - Local SQLite database is unencrypted
   - Protected by macOS file permissions only
   - **Planned**: Add `FileProtectionType.complete`

2. **No Certificate Pinning**
   - Relies on macOS system trust for TLS
   - **Risk**: MITM if system compromised
   - **Mitigation**: Consider pinning Supabase certificate

3. **No Rate Limiting**
   - No client-side rate limiting for auth attempts
   - **Reliance**: Supabase server-side rate limits
   - **Planned**: Add exponential backoff for failed auth

4. **No Biometric Authentication**
   - App does not require Touch ID / Face ID to launch
   - **Planned**: Optional biometric unlock

5. **No Session Timeout**
   - App remains authenticated indefinitely
   - **Planned**: Auto-logout after N hours of inactivity

---

## Vulnerability Reporting

If you discover a security vulnerability in NotchToDo:

### ⚠️ DO NOT
- Open a public GitHub issue
- Disclose the vulnerability publicly before it's fixed

### ✅ DO
1. **Email**: Send details to [security@notchtodo.app] (replace with actual contact)
2. **Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (optional)
3. **Response Time**: We aim to respond within 48 hours
4. **Disclosure**: We'll work with you on responsible disclosure after a fix is deployed

---

## Security Checklist for PRs

Before submitting code, verify:

- [ ] No hardcoded secrets or tokens
- [ ] All user input validated via InputValidator
- [ ] Sensitive data stored in Keychain (not UserDefaults or files)
- [ ] No sensitive data logged (passwords, tokens, PII)
- [ ] Error messages sanitized (no debug info exposed to users)
- [ ] Network requests use HTTPS
- [ ] File permissions appropriate (user-only access)
- [ ] Unit tests cover validation logic
- [ ] Security implications documented

---

## Version History

- **v1.0** (2025-01-19): Initial security documentation
  - Keychain token storage
  - InputValidator implementation
  - Comprehensive validation rules
  - Audit logging

---

## References

- [Apple Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Supabase Auth Docs](https://supabase.com/docs/guides/auth)
- [macOS App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)

---

**Last Updated**: 2025-01-19
**Maintained By**: NotchToDo Security Team
