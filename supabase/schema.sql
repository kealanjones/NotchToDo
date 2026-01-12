-- Supabase schema draft for Notch sync service.
-- Enable required extensions.
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- Helper function + trigger to keep updated_at fresh.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = timezone('utc', now());
    return new;
end;
$$;

-- Profiles provide a place for per-user metadata.
create table if not exists public.profiles (
    id uuid primary key references auth.users (id) on delete cascade,
    display_name text,
    avatar_url text,
    timezone text,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

create trigger on_profiles_updated
before update on public.profiles
for each row
execute procedure public.set_updated_at();

-- Orbs mirror OrbEntity records in Core Data.
create table if not exists public.orbs (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    name text not null,
    color_hex text not null,
    sort_order double precision not null default 0,
    version bigint not null default 0,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    deleted_at timestamptz
);

create index if not exists idx_orbs_user on public.orbs(user_id);
create index if not exists idx_orbs_updated_at on public.orbs(updated_at);
create index if not exists idx_orbs_deleted_at on public.orbs(deleted_at) where deleted_at is null;
create index if not exists idx_orbs_user_not_deleted on public.orbs(user_id, sort_order) where deleted_at is null;

create or replace function public.bump_orb_version()
returns trigger
language plpgsql
as $$
begin
    new.version = coalesce(old.version, 0) + 1;
    return new;
end;
$$;

create trigger on_orbs_updated
before update on public.orbs
for each row
execute procedure public.set_updated_at();

create trigger on_orbs_version
before update on public.orbs
for each row
execute procedure public.bump_orb_version();

-- Tasks mirror TaskEntity records.
create table if not exists public.tasks (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    orb_id uuid references public.orbs (id) on delete cascade,
    title text not null,
    notes text,
    status smallint not null default 1,
    priority smallint not null default 1,
    sort_order double precision not null default 0,
    is_completed boolean not null default false,
    due_date timestamptz,
    version bigint not null default 0,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    deleted_at timestamptz
);

create index if not exists idx_tasks_user on public.tasks(user_id);
create index if not exists idx_tasks_orb on public.tasks(orb_id);
create index if not exists idx_tasks_updated_at on public.tasks(updated_at);
create index if not exists idx_tasks_deleted_at on public.tasks(deleted_at) where deleted_at is null;
create index if not exists idx_tasks_user_not_deleted on public.tasks(user_id, sort_order) where deleted_at is null;
create index if not exists idx_tasks_orb_not_deleted on public.tasks(orb_id, sort_order) where deleted_at is null;

create or replace function public.bump_task_version()
returns trigger
language plpgsql
as $$
begin
    new.version = coalesce(old.version, 0) + 1;
    return new;
end;
$$;

create trigger on_tasks_updated
before update on public.tasks
for each row
execute procedure public.set_updated_at();

create trigger on_tasks_version
before update on public.tasks
for each row
execute procedure public.bump_task_version();

-- Attachments store metadata for audio files housed in Supabase Storage.
create table if not exists public.attachments (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    task_id uuid references public.tasks (id) on delete cascade,
    storage_path text not null,
    content_type text,
    duration_seconds numeric,
    sha256 text,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_attachments_user on public.attachments(user_id);
create index if not exists idx_attachments_task on public.attachments(task_id);

create trigger on_attachments_updated
before update on public.attachments
for each row
execute procedure public.set_updated_at();

-- Row Level Security policies
-- CRITICAL: These policies ensure users can only access their own data

-- Enable RLS on all tables
alter table public.profiles enable row level security;
alter table public.orbs enable row level security;
alter table public.tasks enable row level security;
alter table public.attachments enable row level security;

-- Profiles: users can only access their own profile
create policy "profiles_owner_read" on public.profiles
  for select using (auth.uid() = id);

create policy "profiles_owner_update" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

create policy "profiles_owner_insert" on public.profiles
  for insert with check (auth.uid() = id);

-- Orbs: users can only access their own orbs
create policy "orbs_owner_all" on public.orbs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Tasks: users can only access their own tasks
create policy "tasks_owner_all" on public.tasks
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Attachments: users can only access their own attachments
create policy "attachments_owner_all" on public.attachments
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
