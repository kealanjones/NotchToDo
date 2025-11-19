package com.notchtodo.data.repository

import com.notchtodo.data.local.dao.OrbDao
import com.notchtodo.data.local.entities.toDomain
import com.notchtodo.data.local.entities.toEntity
import com.notchtodo.data.remote.SupabaseApi
import com.notchtodo.data.remote.dto.*
import com.notchtodo.domain.model.Orb
import com.notchtodo.util.DebugLog
import com.notchtodo.util.SecurePreferences
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.util.Date
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Repository for Orb operations.
 */
@Singleton
class OrbRepository @Inject constructor(
    private val orbDao: OrbDao,
    private val api: SupabaseApi,
    private val securePreferences: SecurePreferences,
    private val authRepository: AuthRepository
) {

    // ==================== Local Operations ====================

    fun observeAllOrbs(): Flow<List<Orb>> {
        return orbDao.observeOrbsWithTaskCount().map { entities ->
            entities.map { it.toDomain() }
        }
    }

    fun observeOrb(orbId: UUID): Flow<Orb?> {
        return orbDao.observeOrb(orbId.toString()).map { it?.toDomain() }
    }

    suspend fun getOrb(orbId: UUID): Orb? {
        return orbDao.getOrbWithTaskCount(orbId.toString())?.toDomain()
    }

    suspend fun getAllOrbs(): List<Orb> {
        return orbDao.getAllOrbs().map { it.toDomain() }
    }

    // ==================== CRUD Operations ====================

    suspend fun createOrb(orb: Orb): Result<Orb> {
        return try {
            DebugLog.log("Creating orb: ${orb.name}", DebugLog.Category.DATA)

            // Save to local database
            val entity = orb.toEntity().copy(syncPending = true)
            orbDao.insert(entity)

            // Sync to remote
            syncOrbToRemote(orb)

            Result.success(orb)
        } catch (e: Exception) {
            DebugLog.error("Failed to create orb", e, DebugLog.Category.DATA)
            Result.failure(e)
        }
    }

    suspend fun updateOrb(orb: Orb): Result<Orb> {
        return try {
            DebugLog.log("Updating orb: ${orb.name}", DebugLog.Category.DATA)

            val updatedOrb = orb.copy(updatedAt = Date())
            val entity = updatedOrb.toEntity().copy(syncPending = true)
            orbDao.update(entity)

            // Sync to remote
            syncOrbToRemote(updatedOrb)

            Result.success(updatedOrb)
        } catch (e: Exception) {
            DebugLog.error("Failed to update orb", e, DebugLog.Category.DATA)
            Result.failure(e)
        }
    }

    suspend fun deleteOrb(orbId: UUID): Result<Unit> {
        return try {
            DebugLog.log("Deleting orb: $orbId", DebugLog.Category.DATA)

            // Soft delete locally
            orbDao.softDelete(orbId.toString())

            // Sync to remote
            val userId = authRepository.getUserId()
            if (userId != null) {
                try {
                    val response = api.softDeleteOrb(
                        id = orbId.toString(),
                        deletedAt = mapOf("deleted_at" to formatISO8601(Date()))
                    )
                    if (!response.isSuccessful) {
                        DebugLog.error("Remote delete failed: ${response.code()}", category = DebugLog.Category.SYNC)
                    }
                } catch (e: Exception) {
                    DebugLog.error("Failed to sync delete to remote", e, DebugLog.Category.SYNC)
                }
            }

            Result.success(Unit)
        } catch (e: Exception) {
            DebugLog.error("Failed to delete orb", e, DebugLog.Category.DATA)
            Result.failure(e)
        }
    }

    // ==================== Sync Operations ====================

    suspend fun syncOrbs(): Result<Unit> {
        return try {
            val userId = authRepository.getUserId() ?: return Result.failure(Exception("Not authenticated"))

            DebugLog.log("Starting orb sync", DebugLog.Category.SYNC)

            // Fetch remote orbs
            val response = api.getOrbs()
            if (response.isSuccessful) {
                val remoteOrbs = response.body() ?: emptyList()
                DebugLog.log("Fetched ${remoteOrbs.size} orbs from remote", DebugLog.Category.SYNC)

                // Upsert to local database
                val entities = remoteOrbs.map { it.toEntity() }
                orbDao.upsertOrbs(entities)

                // Push pending local changes
                pushPendingOrbs()

                DebugLog.log("Orb sync completed", DebugLog.Category.SYNC)
                Result.success(Unit)
            } else {
                val error = "Sync failed: ${response.code()}"
                DebugLog.error(error, category = DebugLog.Category.SYNC)
                Result.failure(Exception(error))
            }
        } catch (e: Exception) {
            DebugLog.error("Orb sync failed", e, DebugLog.Category.SYNC)
            Result.failure(e)
        }
    }

    private suspend fun pushPendingOrbs() {
        try {
            val pendingOrbs = orbDao.getPendingSyncOrbs()
            DebugLog.log("Pushing ${pendingOrbs.size} pending orbs", DebugLog.Category.SYNC)

            pendingOrbs.forEach { entity ->
                syncOrbToRemote(entity.toDomain())
            }
        } catch (e: Exception) {
            DebugLog.error("Failed to push pending orbs", e, DebugLog.Category.SYNC)
        }
    }

    private suspend fun syncOrbToRemote(orb: Orb) {
        val userId = authRepository.getUserId() ?: return

        try {
            // Check if orb exists on remote
            val existingResponse = api.getOrb(orb.id.toString())

            if (existingResponse.isSuccessful && existingResponse.body()?.isNotEmpty() == true) {
                // Update existing orb
                val updates = OrbUpdateRequest(
                    name = orb.name,
                    colorHex = orb.colorHex,
                    sortOrder = orb.sortOrder
                )
                api.updateOrb(orb.id.toString(), updates = updates)
            } else {
                // Create new orb
                val createRequest = orb.toCreateRequest()
                api.createOrb(createRequest)
            }

            // Mark as synced
            orbDao.updateSyncPending(orb.id.toString(), false)

        } catch (e: Exception) {
            DebugLog.error("Failed to sync orb to remote: ${orb.name}", e, DebugLog.Category.SYNC)
        }
    }

    private fun formatISO8601(date: Date): String {
        val formatter = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'", java.util.Locale.US)
        formatter.timeZone = java.util.TimeZone.getTimeZone("UTC")
        return formatter.format(date)
    }
}
