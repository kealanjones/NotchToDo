package com.notchtodo.data.remote.dto

import com.google.gson.annotations.SerializedName
import com.notchtodo.data.local.entities.OrbEntity
import com.notchtodo.domain.model.Orb
import java.util.Date

/**
 * Data Transfer Object for Orb from Supabase API.
 * Maps to the 'orbs' table in PostgreSQL.
 */
data class OrbDto(
    @SerializedName("id")
    val id: String,

    @SerializedName("user_id")
    val userId: String? = null,

    @SerializedName("name")
    val name: String,

    @SerializedName("color_hex")
    val colorHex: String,

    @SerializedName("sort_order")
    val sortOrder: Double = 0.0,

    @SerializedName("version")
    val version: Long = 0,

    @SerializedName("created_at")
    val createdAt: String,

    @SerializedName("updated_at")
    val updatedAt: String,

    @SerializedName("deleted_at")
    val deletedAt: String? = null
)

/**
 * Request body for creating an orb
 */
data class OrbCreateRequest(
    @SerializedName("id")
    val id: String? = null,

    @SerializedName("name")
    val name: String,

    @SerializedName("color_hex")
    val colorHex: String,

    @SerializedName("sort_order")
    val sortOrder: Double = 0.0
)

/**
 * Request body for updating an orb
 */
data class OrbUpdateRequest(
    @SerializedName("name")
    val name: String? = null,

    @SerializedName("color_hex")
    val colorHex: String? = null,

    @SerializedName("sort_order")
    val sortOrder: Double? = null
)

/**
 * Conversion functions
 */
fun OrbDto.toEntity(): OrbEntity {
    return OrbEntity(
        id = id,
        name = name,
        colorHex = colorHex,
        sortOrder = sortOrder,
        createdAt = parseISO8601(createdAt)?.time ?: System.currentTimeMillis(),
        updatedAt = parseISO8601(updatedAt)?.time ?: System.currentTimeMillis(),
        version = version,
        deletedAt = deletedAt?.let { parseISO8601(it)?.time },
        syncPending = false
    )
}

fun Orb.toDto(userId: String): OrbDto {
    return OrbDto(
        id = id.toString(),
        userId = userId,
        name = name,
        colorHex = colorHex,
        sortOrder = sortOrder,
        version = version,
        createdAt = formatISO8601(createdAt),
        updatedAt = formatISO8601(updatedAt),
        deletedAt = deletedAt?.let { formatISO8601(it) }
    )
}

fun Orb.toCreateRequest(): OrbCreateRequest {
    return OrbCreateRequest(
        id = id.toString(),
        name = name,
        colorHex = colorHex,
        sortOrder = sortOrder
    )
}

/**
 * ISO8601 date parsing and formatting helpers
 */
private fun parseISO8601(dateString: String): Date? {
    return try {
        val formatter = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'", java.util.Locale.US)
        formatter.timeZone = java.util.TimeZone.getTimeZone("UTC")
        formatter.parse(dateString)
    } catch (e: Exception) {
        try {
            val formatter = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", java.util.Locale.US)
            formatter.timeZone = java.util.TimeZone.getTimeZone("UTC")
            formatter.parse(dateString)
        } catch (e2: Exception) {
            null
        }
    }
}

private fun formatISO8601(date: Date): String {
    val formatter = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'", java.util.Locale.US)
    formatter.timeZone = java.util.TimeZone.getTimeZone("UTC")
    return formatter.format(date)
}
