package com.notchtodo.util

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import dagger.hilt.android.qualifiers.ApplicationContext
import java.util.Date
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Secure storage for sensitive data using EncryptedSharedPreferences.
 */
@Singleton
class SecurePreferences @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val masterKey: MasterKey by lazy {
        MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
    }

    private val encryptedPrefs: SharedPreferences by lazy {
        EncryptedSharedPreferences.create(
            context,
            "notchtodo_secure_prefs",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    companion object {
        private const val KEY_ACCESS_TOKEN = "access_token"
        private const val KEY_REFRESH_TOKEN = "refresh_token"
        private const val KEY_EXPIRES_AT = "expires_at"
        private const val KEY_USER_ID = "user_id"
        private const val KEY_LAST_SYNC = "last_sync"
    }

    // ==================== Auth Session ====================

    fun saveAccessToken(token: String?) {
        encryptedPrefs.edit().putString(KEY_ACCESS_TOKEN, token).apply()
    }

    fun getAccessToken(): String? {
        return encryptedPrefs.getString(KEY_ACCESS_TOKEN, null)
    }

    fun saveRefreshToken(token: String?) {
        encryptedPrefs.edit().putString(KEY_REFRESH_TOKEN, token).apply()
    }

    fun getRefreshToken(): String? {
        return encryptedPrefs.getString(KEY_REFRESH_TOKEN, null)
    }

    fun saveExpiresAt(expiresAt: Date?) {
        encryptedPrefs.edit().putLong(KEY_EXPIRES_AT, expiresAt?.time ?: 0L).apply()
    }

    fun getExpiresAt(): Date? {
        val time = encryptedPrefs.getLong(KEY_EXPIRES_AT, 0L)
        return if (time > 0) Date(time) else null
    }

    fun saveUserId(userId: String?) {
        encryptedPrefs.edit().putString(KEY_USER_ID, userId).apply()
    }

    fun getUserId(): String? {
        return encryptedPrefs.getString(KEY_USER_ID, null)
    }

    fun clearSession() {
        encryptedPrefs.edit()
            .remove(KEY_ACCESS_TOKEN)
            .remove(KEY_REFRESH_TOKEN)
            .remove(KEY_EXPIRES_AT)
            .remove(KEY_USER_ID)
            .apply()
    }

    fun hasSession(): Boolean {
        return getAccessToken() != null && getUserId() != null
    }

    // ==================== Sync ====================

    fun saveLastSyncTime(time: Long) {
        encryptedPrefs.edit().putLong(KEY_LAST_SYNC, time).apply()
    }

    fun getLastSyncTime(): Long {
        return encryptedPrefs.getLong(KEY_LAST_SYNC, 0L)
    }
}
