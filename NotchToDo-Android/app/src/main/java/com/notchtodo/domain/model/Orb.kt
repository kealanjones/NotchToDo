package com.notchtodo.domain.model

import androidx.compose.ui.graphics.Color
import java.util.Date
import java.util.UUID

/**
 * Domain model for an Orb (task folder/category).
 */
data class Orb(
    val id: UUID,
    val name: String,
    val colorHex: String,
    val sortOrder: Double = 0.0,
    val createdAt: Date = Date(),
    val updatedAt: Date = Date(),
    val version: Long = 0,
    val deletedAt: Date? = null,
    val taskCount: Int = 0
) {
    /**
     * Get color as Compose Color
     */
    fun getColor(): Color {
        return parseColorHex(colorHex)
    }

    companion object {
        /**
         * Predefined color palette matching iOS
         */
        val COLOR_PALETTE = listOf(
            "#0099FF", // Bright Electric Blue
            "#FF2640", // Vibrant Crimson Red
            "#00FF66", // Luminous Emerald Green
            "#FFA500", // Vivid Amber Orange
            "#BF00FF", // Rich Royal Purple
            "#00F2FF", // Brilliant Cyan Blue
            "#FF00B3", // Vibrant Magenta Pink
            "#FFFA00"  // Bright Golden Yellow
        )

        /**
         * Get a color from the palette by index
         */
        fun getColorForIndex(index: Int): String {
            return COLOR_PALETTE[index % COLOR_PALETTE.size]
        }

        /**
         * Create a new orb with default values
         */
        fun create(name: String, colorIndex: Int = 0): Orb {
            return Orb(
                id = UUID.randomUUID(),
                name = name,
                colorHex = getColorForIndex(colorIndex),
                createdAt = Date(),
                updatedAt = Date()
            )
        }

        /**
         * Parse hex color to Compose Color
         */
        private fun parseColorHex(hex: String): Color {
            val cleanHex = hex.removePrefix("#")
            return try {
                val colorInt = cleanHex.toLong(16).toInt()
                Color(colorInt or 0xFF000000.toInt())
            } catch (e: Exception) {
                Color(0xFF4F5FFF) // Default blue
            }
        }
    }
}

/**
 * Extension to convert Color to hex string
 */
fun Color.toHexString(): String {
    val red = (this.red * 255).toInt()
    val green = (this.green * 255).toInt()
    val blue = (this.blue * 255).toInt()
    return "#%02X%02X%02X".format(red, green, blue)
}
