package com.notchtodo.data.repository

import com.notchtodo.data.remote.SupabaseApi
import com.notchtodo.data.remote.dto.RefreshTokenRequest
import com.notchtodo.data.remote.dto.SignUpRequest
import com.notchtodo.data.remote.dto.toAuthSession
import com.notchtodo.domain.model.AuthSession
import com.notchtodo.util.DebugLog
import com.notchtodo.util.SecurePreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Repository for authentication operations.
 */
@Singleton
class AuthRepository @Inject constructor(
    private val api: SupabaseApi,
    private val securePreferences: SecurePreferences
) {
    private val _authState = MutableStateFlow<AuthState>(AuthState.Unauthenticated)
    val authState: StateFlow<AuthState> = _authState.asStateFlow()

    sealed class AuthState {
        object Unauthenticated : AuthState()
        data class Authenticated(val session: AuthSession) : AuthState()
        data class Error(val message: String) : AuthState()
    }

    init {
        // Load persisted session on init
        loadPersistedSession()
    }

    /**
     * Sign in with email and password
     */
    suspend fun signIn(email: String, password: String): Result<AuthSession> {
        return try {
            DebugLog.log("Signing in with email: $email", DebugLog.Category.AUTH)

            val response = api.signIn(email, password)

            if (response.isSuccessful) {
                val authResponse = response.body()
                val session = authResponse?.toAuthSession()

                if (session != null) {
                    persistSession(session)
                    _authState.value = AuthState.Authenticated(session)
                    DebugLog.log("Sign in successful", DebugLog.Category.AUTH)
                    Result.success(session)
                } else {
                    val error = "Invalid auth response"
                    DebugLog.error(error, category = DebugLog.Category.AUTH)
                    _authState.value = AuthState.Error(error)
                    Result.failure(Exception(error))
                }
            } else {
                val error = "Sign in failed: ${response.code()} - ${response.message()}"
                DebugLog.error(error, category = DebugLog.Category.AUTH)
                _authState.value = AuthState.Error(error)
                Result.failure(Exception(error))
            }
        } catch (e: Exception) {
            DebugLog.error("Sign in error", e, DebugLog.Category.AUTH)
            _authState.value = AuthState.Error(e.message ?: "Unknown error")
            Result.failure(e)
        }
    }

    /**
     * Sign up with email and password
     */
    suspend fun signUp(email: String, password: String): Result<AuthSession> {
        return try {
            DebugLog.log("Signing up with email: $email", DebugLog.Category.AUTH)

            val request = SignUpRequest(email, password)
            val response = api.signUp(request)

            if (response.isSuccessful) {
                val authResponse = response.body()
                val session = authResponse?.toAuthSession()

                if (session != null) {
                    persistSession(session)
                    _authState.value = AuthState.Authenticated(session)
                    DebugLog.log("Sign up successful", DebugLog.Category.AUTH)
                    Result.success(session)
                } else {
                    val error = "Invalid auth response"
                    DebugLog.error(error, category = DebugLog.Category.AUTH)
                    _authState.value = AuthState.Error(error)
                    Result.failure(Exception(error))
                }
            } else {
                val error = "Sign up failed: ${response.code()} - ${response.message()}"
                DebugLog.error(error, category = DebugLog.Category.AUTH)
                _authState.value = AuthState.Error(error)
                Result.failure(Exception(error))
            }
        } catch (e: Exception) {
            DebugLog.error("Sign up error", e, DebugLog.Category.AUTH)
            _authState.value = AuthState.Error(e.message ?: "Unknown error")
            Result.failure(e)
        }
    }

    /**
     * Sign out
     */
    suspend fun signOut() {
        try {
            DebugLog.log("Signing out", DebugLog.Category.AUTH)
            api.signOut()
        } catch (e: Exception) {
            DebugLog.error("Sign out error", e, DebugLog.Category.AUTH)
        } finally {
            clearSession()
            _authState.value = AuthState.Unauthenticated
        }
    }

    /**
     * Refresh the access token
     */
    suspend fun refreshToken(): Result<AuthSession> {
        val refreshToken = securePreferences.getRefreshToken()

        if (refreshToken == null) {
            clearSession()
            _authState.value = AuthState.Unauthenticated
            return Result.failure(Exception("No refresh token available"))
        }

        return try {
            DebugLog.log("Refreshing access token", DebugLog.Category.AUTH)

            val request = RefreshTokenRequest(refreshToken)
            val response = api.refreshToken(request)

            if (response.isSuccessful) {
                val authResponse = response.body()
                val session = authResponse?.toAuthSession()

                if (session != null) {
                    persistSession(session)
                    _authState.value = AuthState.Authenticated(session)
                    DebugLog.log("Token refresh successful", DebugLog.Category.AUTH)
                    Result.success(session)
                } else {
                    val error = "Invalid refresh response"
                    DebugLog.error(error, category = DebugLog.Category.AUTH)
                    clearSession()
                    _authState.value = AuthState.Unauthenticated
                    Result.failure(Exception(error))
                }
            } else {
                val error = "Token refresh failed: ${response.code()}"
                DebugLog.error(error, category = DebugLog.Category.AUTH)
                clearSession()
                _authState.value = AuthState.Unauthenticated
                Result.failure(Exception(error))
            }
        } catch (e: Exception) {
            DebugLog.error("Token refresh error", e, DebugLog.Category.AUTH)
            clearSession()
            _authState.value = AuthState.Unauthenticated
            Result.failure(e)
        }
    }

    /**
     * Check if user is authenticated
     */
    fun isAuthenticated(): Boolean {
        return securePreferences.hasSession()
    }

    /**
     * Get current session
     */
    fun getCurrentSession(): AuthSession? {
        val accessToken = securePreferences.getAccessToken()
        val userId = securePreferences.getUserId()

        return if (accessToken != null && userId != null) {
            AuthSession(
                accessToken = accessToken,
                refreshToken = securePreferences.getRefreshToken(),
                expiresAt = securePreferences.getExpiresAt(),
                userId = userId
            )
        } else {
            null
        }
    }

    /**
     * Get user ID
     */
    fun getUserId(): String? {
        return securePreferences.getUserId()
    }

    private fun persistSession(session: AuthSession) {
        securePreferences.saveAccessToken(session.accessToken)
        securePreferences.saveRefreshToken(session.refreshToken)
        securePreferences.saveExpiresAt(session.expiresAt)
        securePreferences.saveUserId(session.userId)
    }

    private fun clearSession() {
        securePreferences.clearSession()
    }

    private fun loadPersistedSession() {
        val session = getCurrentSession()
        if (session != null) {
            _authState.value = AuthState.Authenticated(session)
            DebugLog.log("Loaded persisted session", DebugLog.Category.AUTH)
        } else {
            _authState.value = AuthState.Unauthenticated
        }
    }
}
