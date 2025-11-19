package com.notchtodo.domain.model

import java.util.Date

/**
 * Authentication session containing user credentials
 */
data class AuthSession(
    val accessToken: String,
    val refreshToken: String?,
    val expiresAt: Date?,
    val userId: String
) {
    /**
     * Check if the access token needs refresh
     * Returns true if token expires in less than 5 minutes
     */
    fun needsRefresh(): Boolean {
        val now = Date()
        return expiresAt?.let {
            it.time - now.time < 5 * 60 * 1000 // 5 minutes
        } ?: false
    }

    /**
     * Check if the session is expired
     */
    fun isExpired(): Boolean {
        val now = Date()
        return expiresAt?.let { it.before(now) } ?: false
    }
}
