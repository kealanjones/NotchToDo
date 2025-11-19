package com.notchtodo.data.local.entities

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import com.notchtodo.domain.model.Orb
import java.util.Date
import java.util.UUID

/**
 * Room entity for Orb table.
 */
@Entity(
    tableName = "orbs",
    indices = [
        Index("sort_order"),
        Index("updated_at"),
        Index("created_at")
    ]
)
data class OrbEntity(
    @PrimaryKey
    @ColumnInfo(name = "id")
    val id: String,

    @ColumnInfo(name = "name")
    val name: String,

    @ColumnInfo(name = "color_hex")
    val colorHex: String,

    @ColumnInfo(name = "sort_order")
    val sortOrder: Double = 0.0,

    @ColumnInfo(name = "created_at")
    val createdAt: Long,

    @ColumnInfo(name = "updated_at")
    val updatedAt: Long,

    @ColumnInfo(name = "version")
    val version: Long = 0,

    @ColumnInfo(name = "deleted_at")
    val deletedAt: Long? = null,

    @ColumnInfo(name = "sync_pending")
    val syncPending: Boolean = false
)

/**
 * Orb with task count (for queries)
 */
data class OrbWithTaskCount(
    @ColumnInfo(name = "id")
    val id: String,

    @ColumnInfo(name = "name")
    val name: String,

    @ColumnInfo(name = "color_hex")
    val colorHex: String,

    @ColumnInfo(name = "sort_order")
    val sortOrder: Double,

    @ColumnInfo(name = "created_at")
    val createdAt: Long,

    @ColumnInfo(name = "updated_at")
    val updatedAt: Long,

    @ColumnInfo(name = "version")
    val version: Long,

    @ColumnInfo(name = "deleted_at")
    val deletedAt: Long?,

    @ColumnInfo(name = "task_count")
    val taskCount: Int = 0
)

/**
 * Converter functions between OrbEntity and Orb domain model
 */
fun OrbEntity.toDomain(taskCount: Int = 0): Orb {
    return Orb(
        id = UUID.fromString(id),
        name = name,
        colorHex = colorHex,
        sortOrder = sortOrder,
        createdAt = Date(createdAt),
        updatedAt = Date(updatedAt),
        version = version,
        deletedAt = deletedAt?.let { Date(it) },
        taskCount = taskCount
    )
}

fun OrbWithTaskCount.toDomain(): Orb {
    return Orb(
        id = UUID.fromString(id),
        name = name,
        colorHex = colorHex,
        sortOrder = sortOrder,
        createdAt = Date(createdAt),
        updatedAt = Date(updatedAt),
        version = version,
        deletedAt = deletedAt?.let { Date(it) },
        taskCount = taskCount
    )
}

fun Orb.toEntity(): OrbEntity {
    return OrbEntity(
        id = id.toString(),
        name = name,
        colorHex = colorHex,
        sortOrder = sortOrder,
        createdAt = createdAt.time,
        updatedAt = updatedAt.time,
        version = version,
        deletedAt = deletedAt?.time,
        syncPending = false
    )
}
