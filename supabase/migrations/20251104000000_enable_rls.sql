-- Enable Row Level Security for all tables
-- This migration MUST be applied to prevent users from seeing each other's data

-- Enable RLS on profiles table
alter table if exists public.profiles enable row level security;

-- Enable RLS on orbs table
alter table if exists public.orbs enable row level security;

-- Enable RLS on tasks table
alter table if exists public.tasks enable row level security;

-- Enable RLS on attachments table
alter table if exists public.attachments enable row level security;

-- Create RLS policies for profiles table
-- Users can only read and update their own profile
drop policy if exists "profiles_owner_read" on public.profiles;
create policy "profiles_owner_read"
on public.profiles
for select
using (auth.uid() = id);

drop policy if exists "profiles_owner_update" on public.profiles;
create policy "profiles_owner_update"
on public.profiles
for update
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "profiles_owner_insert" on public.profiles;
create policy "profiles_owner_insert"
on public.profiles
for insert
with check (auth.uid() = id);

-- Create RLS policies for orbs table
-- Users can only access their own orbs
drop policy if exists "orbs_owner_all" on public.orbs;
create policy "orbs_owner_all"
on public.orbs
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- Create RLS policies for tasks table
-- Users can only access their own tasks
drop policy if exists "tasks_owner_all" on public.tasks;
create policy "tasks_owner_all"
on public.tasks
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- Create RLS policies for attachments table
-- Users can only access their own attachments
drop policy if exists "attachments_owner_all" on public.attachments;
create policy "attachments_owner_all"
on public.attachments
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
