package com.notchtodo.data.local.dao

import androidx.room.*
import com.notchtodo.data.local.entities.OrbEntity
import com.notchtodo.data.local.entities.OrbWithTaskCount
import kotlinx.coroutines.flow.Flow

/**
 * Data Access Object for Orb operations.
 */
@Dao
interface OrbDao {

    @Query("SELECT * FROM orbs WHERE deleted_at IS NULL ORDER BY sort_order ASC, created_at DESC")
    fun observeAllOrbs(): Flow<List<OrbEntity>>

    @Query("""
        SELECT
            o.*,
            (SELECT COUNT(*) FROM tasks WHERE orb_id = o.id AND deleted_at IS NULL) as task_count
        FROM orbs o
        WHERE o.deleted_at IS NULL
        ORDER BY o.sort_order ASC, o.created_at DESC
    """)
    fun observeOrbsWithTaskCount(): Flow<List<OrbWithTaskCount>>

    @Query("SELECT * FROM orbs WHERE deleted_at IS NULL AND id = :orbId")
    fun observeOrb(orbId: String): Flow<OrbEntity?>

    @Query("SELECT * FROM orbs WHERE deleted_at IS NULL AND id = :orbId")
    suspend fun getOrb(orbId: String): OrbEntity?

    @Query("SELECT * FROM orbs WHERE deleted_at IS NULL")
    suspend fun getAllOrbs(): List<OrbEntity>

    @Query("""
        SELECT
            o.*,
            (SELECT COUNT(*) FROM tasks WHERE orb_id = o.id AND deleted_at IS NULL) as task_count
        FROM orbs o
        WHERE o.deleted_at IS NULL AND o.id = :orbId
    """)
    suspend fun getOrbWithTaskCount(orbId: String): OrbWithTaskCount?

    @Query("SELECT * FROM orbs WHERE sync_pending = 1")
    suspend fun getPendingSyncOrbs(): List<OrbEntity>

    @Query("SELECT * FROM orbs WHERE updated_at > :since")
    suspend fun getOrbsUpdatedSince(since: Long): List<OrbEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(orb: OrbEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(orbs: List<OrbEntity>)

    @Update
    suspend fun update(orb: OrbEntity)

    @Query("UPDATE orbs SET deleted_at = :deletedAt WHERE id = :orbId")
    suspend fun softDelete(orbId: String, deletedAt: Long = System.currentTimeMillis())

    @Delete
    suspend fun delete(orb: OrbEntity)

    @Query("DELETE FROM orbs WHERE id = :orbId")
    suspend fun deleteById(orbId: String)

    @Query("DELETE FROM orbs WHERE deleted_at IS NOT NULL AND deleted_at < :before")
    suspend fun deleteOldSoftDeletedOrbs(before: Long)

    @Query("UPDATE orbs SET sync_pending = :pending WHERE id = :orbId")
    suspend fun updateSyncPending(orbId: String, pending: Boolean)

    @Query("SELECT COUNT(*) FROM orbs WHERE deleted_at IS NULL")
    suspend fun getOrbCount(): Int

    @Transaction
    suspend fun upsertOrb(orb: OrbEntity) {
        val existing = getOrb(orb.id)
        if (existing == null) {
            insert(orb)
        } else {
            // Only update if remote version is newer
            if (orb.version >= existing.version) {
                insert(orb)
            }
        }
    }

    @Transaction
    suspend fun upsertOrbs(orbs: List<OrbEntity>) {
        orbs.forEach { upsertOrb(it) }
    }
}
