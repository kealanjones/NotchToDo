package com.notchtodo.util

import android.util.Log

/**
 * Debug logging utility with category support.
 * Matches the iOS DebugLog implementation.
 */
object DebugLog {

    enum class Category {
        DATA,
        SYNC,
        AUTH,
        SPEECH,
        UI,
        NETWORK,
        GENERAL
    }

    private val enabledCategories = mutableSetOf(
        Category.DATA,
        Category.SYNC,
        Category.AUTH,
        Category.NETWORK
    )

    private const val TAG = "NotchToDo"

    /**
     * Log a message with a specific category
     */
    fun log(message: String, category: Category = Category.GENERAL) {
        if (enabledCategories.contains(category)) {
            val prefix = "[${category.name}]"
            Log.d(TAG, "$prefix $message")
        }
    }

    /**
     * Log an error
     */
    fun error(message: String, throwable: Throwable? = null, category: Category = Category.GENERAL) {
        val prefix = "[${category.name}]"
        if (throwable != null) {
            Log.e(TAG, "$prefix $message", throwable)
        } else {
            Log.e(TAG, "$prefix $message")
        }
    }

    /**
     * Log a warning
     */
    fun warn(message: String, category: Category = Category.GENERAL) {
        val prefix = "[${category.name}]"
        Log.w(TAG, "$prefix $message")
    }

    /**
     * Enable a category
     */
    fun enable(category: Category) {
        enabledCategories.add(category)
    }

    /**
     * Disable a category
     */
    fun disable(category: Category) {
        enabledCategories.remove(category)
    }

    /**
     * Enable all categories
     */
    fun enableAll() {
        enabledCategories.addAll(Category.entries)
    }

    /**
     * Disable all categories
     */
    fun disableAll() {
        enabledCategories.clear()
    }
}

/**
 * Extension functions for easy logging
 */
fun Any.logD(message: String, category: DebugLog.Category = DebugLog.Category.GENERAL) {
    DebugLog.log("${this::class.simpleName}: $message", category)
}

fun Any.logE(message: String, throwable: Throwable? = null, category: DebugLog.Category = DebugLog.Category.GENERAL) {
    DebugLog.error("${this::class.simpleName}: $message", throwable, category)
}

fun Any.logW(message: String, category: DebugLog.Category = DebugLog.Category.GENERAL) {
    DebugLog.warn("${this::class.simpleName}: $message", category)
}
