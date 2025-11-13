-- Verification script for Row Level Security
-- Run this in Supabase SQL Editor to verify RLS is enabled

-- Check which tables have RLS enabled
SELECT
    tablename,
    rowsecurity as "RLS Enabled"
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('profiles', 'orbs', 'tasks', 'attachments')
ORDER BY tablename;

-- Expected result: All tables should show "RLS Enabled = true"

-- Check which policies exist
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as "Operation"
FROM pg_policies
WHERE schemaname = 'public'
AND tablename IN ('profiles', 'orbs', 'tasks', 'attachments')
ORDER BY tablename, policyname;

-- Expected policies:
-- profiles: profiles_owner_read, profiles_owner_update, profiles_owner_insert
-- orbs: orbs_owner_all
-- tasks: tasks_owner_all
-- attachments: attachments_owner_all
