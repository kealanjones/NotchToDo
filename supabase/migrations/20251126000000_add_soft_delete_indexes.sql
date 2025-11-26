-- Migration: Add indexes for soft delete columns
-- This improves query performance when filtering by deleted_at

-- Index on orbs.deleted_at for efficient soft delete filtering
-- Partial index only includes non-deleted rows (most common query pattern)
CREATE INDEX IF NOT EXISTS idx_orbs_deleted_at 
ON public.orbs(deleted_at) 
WHERE deleted_at IS NULL;

-- Index on tasks.deleted_at for efficient soft delete filtering
-- Partial index only includes non-deleted rows (most common query pattern)
CREATE INDEX IF NOT EXISTS idx_tasks_deleted_at 
ON public.tasks(deleted_at) 
WHERE deleted_at IS NULL;

-- Composite index for common query pattern: user's non-deleted orbs
CREATE INDEX IF NOT EXISTS idx_orbs_user_not_deleted 
ON public.orbs(user_id, sort_order) 
WHERE deleted_at IS NULL;

-- Composite index for common query pattern: user's non-deleted tasks
CREATE INDEX IF NOT EXISTS idx_tasks_user_not_deleted 
ON public.tasks(user_id, sort_order) 
WHERE deleted_at IS NULL;

-- Composite index for tasks by orb (common query pattern)
CREATE INDEX IF NOT EXISTS idx_tasks_orb_not_deleted 
ON public.tasks(orb_id, sort_order) 
WHERE deleted_at IS NULL;

COMMENT ON INDEX idx_orbs_deleted_at IS 'Partial index for efficient soft delete queries on orbs';
COMMENT ON INDEX idx_tasks_deleted_at IS 'Partial index for efficient soft delete queries on tasks';
COMMENT ON INDEX idx_orbs_user_not_deleted IS 'Composite index for fetching user orbs sorted by order';
COMMENT ON INDEX idx_tasks_user_not_deleted IS 'Composite index for fetching user tasks sorted by order';
COMMENT ON INDEX idx_tasks_orb_not_deleted IS 'Composite index for fetching tasks within an orb';
