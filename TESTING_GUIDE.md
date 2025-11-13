# Authentication & Data Isolation Testing Guide

**Date:** November 4, 2025
**Purpose:** Verify RLS fixes and multi-account data isolation

---

## 🎯 Testing Objectives

1. ✅ Verify sign up/sign in/sign out flows work correctly
2. ✅ Verify data syncs properly to Supabase
3. ✅ Verify logout clears all local data
4. ✅ **CRITICAL:** Verify users cannot see each other's data
5. ✅ Verify authentication state prevents data display when logged out

---

## 🚀 Step 1: Build & Run the App

### Open the project:
```bash
open /Users/kealanjones/Desktop/Notch/NotchToDo/NotchToDo.xcodeproj
```

### Build settings to verify:
- Target: NotchToDo (macOS)
- Scheme: NotchToDo
- Destination: My Mac

### Run the app:
- Press `⌘R` or click the Run button
- App should launch and show status bar icon

---

## 🧪 Test Suite

### TEST 1: Clean State & Sign Up

**Goal:** Verify sign up flow and initial data creation

**Steps:**
1. If app is running, quit it
2. Clear existing data (optional but recommended):
   ```bash
   rm -rf ~/Library/Application\ Support/com.notchtodo.app/
   rm -rf ~/Library/Caches/com.notchtodo.app/
   defaults delete com.notchtodo.app
   ```
3. Launch app (should show auth window automatically)
4. Click "Sign Up" (or create account option)
5. Enter test email: `test1@example.com`
6. Enter password: `password123`
7. Click "Sign Up"

**Expected Results:**
- ✅ Auth window closes
- ✅ App shows empty state (no orbs)
- ✅ No errors in console

**Debug Logging:**
- Open debug menu (status bar icon → Debug)
- Enable "Sync" logging category
- Watch console for:
  - ✅ "Supabase sync running"
  - ✅ "Pulled 0 orbs, 0 tasks" (first sync)

---

### TEST 2: Create Data & Verify Sync

**Goal:** Verify data creation and push to Supabase

**Steps:**
1. Press `⇧⌘N` to create a new orb/project
2. Type: "Test Project A"
3. Press Enter
4. Click the orb or press `⌘1` to open it
5. Press `⌘N` to add a task
6. Type: "Task from Account 1"
7. Press Enter
8. Wait 5-10 seconds for sync

**Expected Results:**
- ✅ Orb appears with correct color
- ✅ Task appears in orb
- ✅ Console shows: "Supabase sync running"
- ✅ Console shows: "Processing outbox item: insert OrbEntity"
- ✅ Console shows: "Processing outbox item: insert TaskEntity"

**Verify in Supabase Dashboard:**
1. Go to: https://plvsgllkvttlnzqkqfnp.supabase.co/project/_/editor
2. Click "orbs" table
3. You should see 1 row with:
   - name: "Test Project A"
   - user_id: (some UUID)
4. Click "tasks" table
5. You should see 1 row with:
   - title: "Task from Account 1"
   - user_id: (same UUID as orb)

---

### TEST 3: Sign Out & Verify Data Cleared

**Goal:** Verify logout completely clears local state

**Steps:**
1. Click status bar icon → Debug → Sign Out (Supabase)
2. Click "OK" on the confirmation

**Expected Results:**
- ✅ Console shows: "✅ Signed out: cleared session, sync state, and local data"
- ✅ All orbs disappear from UI
- ✅ Semi-circle overlay is empty
- ✅ Auth window appears after 0.5 seconds
- ✅ Console shows: "Skipping initial sync: no authenticated session"

**Critical Check:**
- With auth window showing, no orbs or tasks should be visible anywhere in the UI
- If you can see data while logged out → BUG (report immediately)

---

### TEST 4: Sign In & Verify Data Loads

**Goal:** Verify sign in reloads user's data

**Steps:**
1. In auth window, enter: `test1@example.com`
2. Enter password: `password123`
3. Click "Sign In"

**Expected Results:**
- ✅ Auth window closes
- ✅ Console shows: "Supabase sync running"
- ✅ Console shows: "Pulled 1 orbs, 1 tasks"
- ✅ "Test Project A" orb reappears
- ✅ "Task from Account 1" task reappears
- ✅ All data matches what was created earlier

---

### TEST 5: Multi-Account Isolation (CRITICAL)

**Goal:** Verify users CANNOT see each other's data

**Steps:**

#### 5A: Create Second Account
1. Sign out (Debug → Sign Out)
2. In auth window, click "Sign Up"
3. Enter: `test2@example.com`
4. Password: `password123`
5. Sign up

**Expected Results:**
- ✅ Auth window closes
- ✅ **NO orbs or tasks visible** (fresh account)
- ✅ Console shows: "Pulled 0 orbs, 0 tasks"

#### 5B: Create Data in Second Account
1. Press `⇧⌘N` to create orb
2. Type: "Test Project B"
3. Press Enter
4. Click orb, add task: "Task from Account 2"
5. Wait for sync

**Expected Results:**
- ✅ Only "Test Project B" visible
- ✅ Only "Task from Account 2" visible
- ✅ **NO data from Account 1 visible**

#### 5C: Verify in Database
1. Open Supabase Dashboard → Table Editor
2. Click "orbs" table
3. You should see 2 rows:
   - "Test Project A" with user_id for test1@example.com
   - "Test Project B" with user_id for test2@example.com (different UUID)
4. Click "tasks" table
5. You should see 2 rows with different user_ids

#### 5D: Switch Back to Account 1
1. Sign out
2. Sign in as `test1@example.com`
3. Wait for sync

**Expected Results:**
- ✅ Console shows: "Pulled 1 orbs, 1 tasks"
- ✅ Only "Test Project A" visible
- ✅ Only "Task from Account 1" visible
- ✅ **NO data from Account 2 visible**

#### 5E: Switch Back to Account 2
1. Sign out
2. Sign in as `test2@example.com`
3. Wait for sync

**Expected Results:**
- ✅ Console shows: "Pulled 1 orbs, 1 tasks"
- ✅ Only "Test Project B" visible
- ✅ Only "Task from Account 2" visible
- ✅ **NO data from Account 1 visible**

---

## 🚨 Known Issues to Watch For

### Issue: See data from other accounts
**Symptom:** After signing in as Account 2, you see orbs/tasks from Account 1
**Cause:** RLS not properly applied or client-side filtering broken
**Action:** CRITICAL BUG - report immediately with console logs

### Issue: Sync fails with 403 Forbidden
**Symptom:** Console shows "Supabase sync error: 403"
**Cause:** RLS is working but blocking legitimate requests
**Action:** Check that queries include proper user_id filtering
**Note:** This shouldn't happen - our code already filters correctly

### Issue: Data persists after logout
**Symptom:** After sign out, still see orbs/tasks in UI
**Cause:** clearLocalData() not being called
**Action:** Check AppDelegate.swift:1507 is executing

### Issue: Duplicate data
**Symptom:** Same orb/task appears multiple times
**Cause:** Conflict resolution or sync logic issue
**Action:** Check remoteID and version fields in database

---

## 📊 Success Criteria

**All tests must pass:**
- [x] Sign up creates new account
- [x] Sign in loads existing data
- [x] Sign out clears all local data
- [x] Data syncs to Supabase correctly
- [x] **Multi-account isolation works perfectly**
- [x] No data visible when logged out
- [x] Console shows proper sync events

**Critical requirement:**
- **Users MUST NOT see each other's data under any circumstances**

---

## 🐛 Troubleshooting

### Console Log Locations
- Xcode Console: View → Debug Area → Show Debug Area (⌘⇧Y)
- System Console: Applications → Utilities → Console.app
  - Filter: `process:NotchToDo`

### Enable All Debug Logging
1. Click status bar icon → Debug
2. Enable all logging categories:
   - App
   - Speech
   - Intent
   - **Sync** (most important)
   - Persistence
   - UI

### Check Supabase Dashboard
- Auth Users: https://plvsgllkvttlnzqkqfnp.supabase.co/project/_/auth/users
- Table Editor: https://plvsgllkvttlnzqkqfnp.supabase.co/project/_/editor
- SQL Editor: https://plvsgllkvttlnzqkqfnp.supabase.co/project/_/sql
- Logs: https://plvsgllkvttlnzqkqfnp.supabase.co/project/_/logs/explorer

### Useful SQL Queries
```sql
-- See all users
SELECT email, created_at FROM auth.users;

-- See all orbs with owners
SELECT o.id, o.name, o.user_id, u.email
FROM orbs o
JOIN auth.users u ON o.user_id = u.id
ORDER BY o.created_at;

-- See all tasks with owners
SELECT t.id, t.title, t.user_id, u.email
FROM tasks t
JOIN auth.users u ON t.user_id = u.id
ORDER BY t.created_at;

-- Verify RLS is active
SELECT tablename, rowsecurity FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('orbs', 'tasks');
```

---

## ✅ Report Results

After testing, document:

1. **Which tests passed:** ✅ / ❌
2. **Any failures:** Describe what happened
3. **Console errors:** Copy relevant error messages
4. **Screenshots:** If data leakage occurred
5. **Database state:** Run SQL queries above and paste results

---

**Good luck! 🎉**

If all tests pass, the authentication and data isolation is working correctly!
