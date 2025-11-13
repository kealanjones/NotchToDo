# Supabase Integration Checklist

This document maps the high-level migration plan onto concrete Supabase configuration and macOS app work items.

## Auth
- [ ] Enable email/password and Sign in with Apple in **Authentication → Providers**.
- [ ] Register your bundle/service IDs with Apple and paste the team ID, key ID, and `.p8` secret into Supabase.
- [ ] Configure redirect URLs (`notch://auth-callback` as the Site URL plus `https://<project>.supabase.co/auth/v1/callback` for web previews/testing).
- [ ] Decide if display names/avatars live in Supabase `profiles` table; backfill existing data when first syncing.
- [ ] Update the app to handle session persistence (store `access_token` / `refresh_token` in Keychain, refresh on launch).

## Database
- [ ] Apply `schema.sql` using the Supabase SQL editor or CLI migrations.
- [ ] **CRITICAL: Enable Row Level Security** - Apply the migration file `migrations/20251104000000_enable_rls.sql` to your Supabase database
  - **Option 1 (Recommended):** Use Supabase Dashboard SQL Editor:
    1. Go to https://plvsgllkvttlnzqkqfnp.supabase.co/project/_/sql
    2. Copy contents of `migrations/20251104000000_enable_rls.sql`
    3. Paste and run the SQL
  - **Option 2:** Use Supabase CLI (if installed):
    ```bash
    cd /Users/kealanjones/Desktop/Notch/supabase
    supabase db push
    ```
  - **Verify RLS is enabled:** After applying, run this query to verify:
    ```sql
    SELECT tablename, rowsecurity FROM pg_tables
    WHERE schemaname = 'public' AND tablename IN ('profiles', 'orbs', 'tasks', 'attachments');
    ```
    All tables should show `rowsecurity = true`
- [ ] Create indexes for `updated_at`, `user_id`, and `orb_id` (already included in `schema.sql` but verify post-migration).
- [ ] Seed initial data for a staging environment to validate end-to-end sync.

## Storage
- [ ] Create a private bucket named `attachments`.
- [ ] Restrict uploads to authenticated users; allow signed URLs for playback/download.
- [ ] Document storage path convention (`userId/tasks/<taskId>/<filename>.m4a`) so the macOS client can construct keys.
- [ ] Configure Supabase edge function or cron to purge orphaned storage objects (optional hardening).

## macOS App Integration
- [ ] Populate `SupabaseURL`, `SupabaseAnonKey`, and `SupabaseStorageBucket` keys in the macOS target `Info.plist` (placeholder values are checked in).
- [ ] Optionally provide `SupabaseDevAccessToken` in `Info.plist` while bootstrapping (use a short-lived service JWT or test user token).
- [ ] Add a `SupabaseService` wrapper that encapsulates auth, PostgREST, storage, and realtime clients.
- [ ] Build a `SyncManager` that:
  - Maintains an outbox of pending Core Data mutations.
  - Pushes local changes to Supabase (create/update/delete).
  - Subscribes to realtime channels for `orbs`, `tasks`, and `attachments` to pull remote updates.
  - Handles conflict resolution using `version`/`updated_at`.
- [ ] Replace the developer-token bootstrap with real Supabase Auth (GoTrue) flows so `SupabaseAuthManager` can exchange Sign in with Apple/email credentials for access & refresh tokens.
- [ ] Extend Core Data models to store `remoteID`, `version`, `deletedAt`.
- [ ] Surface sync state/errors in the UI (status indicator + logging).
- [ ] Implement attachment upload/download with retries and temp file cleanup.

## Testing & Rollout
- [ ] Create a staging Supabase project; wire the app via build configuration.
- [ ] Write integration tests (or scripts) to verify CRUD + realtime flows against staging.
- [ ] Manual QA scenarios: offline edits, simultaneous edits on two devices, attachment upload failures.
- [ ] Prepare migration tooling to bootstrap existing local users into Supabase on first sync.
- [ ] Monitor Supabase dashboard (logs, quota) during beta and production rollout.
