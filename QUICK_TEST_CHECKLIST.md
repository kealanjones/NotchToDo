# Quick Testing Checklist

## 🚀 QUICK START

1. **Build & Run** (in Xcode, press ⌘R)
2. **Enable Sync Logging:**
   - Click status bar icon → Debug → Enable "Sync" category

---

## ✅ TEST SEQUENCE (15 minutes)

### Test 1: Sign Up (Account 1)
- [ ] Sign up as `test1@example.com` / `password123`
- [ ] Create orb: "Project A"
- [ ] Add task: "Task A"
- [ ] Wait 10 seconds, check console for "Pulled 1 orbs, 1 tasks"

### Test 2: Sign Out
- [ ] Debug menu → Sign Out
- [ ] Console shows: "✅ Signed out: cleared session, sync state, and local data"
- [ ] All orbs disappear
- [ ] Auth window appears

### Test 3: Sign Up (Account 2) - CRITICAL DATA ISOLATION TEST
- [ ] Sign up as `test2@example.com` / `password123`
- [ ] **Verify NO orbs visible** (should be empty)
- [ ] Create orb: "Project B"
- [ ] Add task: "Task B"
- [ ] **Verify ONLY "Project B" visible** (NOT Project A)

### Test 4: Switch Back to Account 1
- [ ] Sign out
- [ ] Sign in as `test1@example.com`
- [ ] **Verify ONLY "Project A" visible** (NOT Project B)
- [ ] **SUCCESS:** Data isolation working! ✅

---

## 🚨 RED FLAGS (Report if you see these)

❌ See "Project A" when logged in as Account 2
❌ See any data when logged out
❌ Console error: "403 Forbidden"
❌ Console error: "Supabase sync failed"
❌ Duplicate orbs/tasks appearing

---

## 📝 Console Commands to Watch For

**Good Signs:**
```
✅ Signed out: cleared session, sync state, and local data
Supabase sync running
Pulled 1 orbs, 1 tasks
Processing outbox item: insert OrbEntity
Skipping initial sync: no authenticated session (when logged out)
```

**Bad Signs (Report these):**
```
❌ Supabase sync error: 403
❌ Failed to save merged remote changes
❌ Unable to decode Supabase user ID
❌ 401 unauthorized
```

---

## 🎯 SUCCESS = All 4 Tests Pass

**If all pass:** Authentication & data isolation working perfectly! 🎉
**If any fail:** Note which test failed and what console showed.
