package com.notchtodo.data.remote.dto

import com.google.gson.annotations.SerializedName
import com.notchtodo.domain.model.AuthSession
import java.util.Date

/**
 * Auth response from Supabase
 */
data class AuthResponse(
    @SerializedName("access_token")
    val accessToken: String? = null,

    @SerializedName("refresh_token")
    val refreshToken: String? = null,

    @SerializedName("expires_in")
    val expiresIn: Long? = null,

    @SerializedName("expires_at")
    val expiresAt: Long? = null,

    @SerializedName("token_type")
    val tokenType: String? = null,

    @SerializedName("user")
    val user: UserDto? = null,

    @SerializedName("session")
    val session: SessionDto? = null,

    @SerializedName("data")
    val data: DataWrapper? = null
) {
    data class SessionDto(
        @SerializedName("access_token")
        val accessToken: String? = null,

        @SerializedName("refresh_token")
        val refreshToken: String? = null,

        @SerializedName("expires_in")
        val expiresIn: Long? = null,

        @SerializedName("expires_at")
        val expiresAt: Long? = null,

        @SerializedName("user")
        val user: UserDto? = null
    )

    data class DataWrapper(
        @SerializedName("session")
        val session: SessionDto? = null,

        @SerializedName("user")
        val user: UserDto? = null
    )
}

data class UserDto(
    @SerializedName("id")
    val id: String,

    @SerializedName("email")
    val email: String? = null,

    @SerializedName("user_metadata")
    val userMetadata: Map<String, Any>? = null
)

data class SignInRequest(
    @SerializedName("email")
    val email: String,

    @SerializedName("password")
    val password: String
)

data class SignUpRequest(
    @SerializedName("email")
    val email: String,

    @SerializedName("password")
    val password: String,

    @SerializedName("data")
    val data: Map<String, Any> = emptyMap()
)

data class RefreshTokenRequest(
    @SerializedName("refresh_token")
    val refreshToken: String
)

/**
 * Conversion to AuthSession
 */
fun AuthResponse.toAuthSession(): AuthSession? {
    // Try to extract from top-level fields
    val token = accessToken ?: session?.accessToken ?: data?.session?.accessToken
    val refresh = refreshToken ?: session?.refreshToken ?: data?.session?.refreshToken
    val userId = user?.id ?: session?.user?.id ?: data?.user?.id

    if (token == null || userId == null) {
        return null
    }

    val expiresAtMillis = when {
        expiresAt != null -> expiresAt * 1000 // Convert seconds to milliseconds
        session?.expiresAt != null -> session.expiresAt * 1000
        data?.session?.expiresAt != null -> data.session.expiresAt * 1000
        expiresIn != null -> System.currentTimeMillis() + (expiresIn * 1000)
        session?.expiresIn != null -> System.currentTimeMillis() + (session.expiresIn * 1000)
        data?.session?.expiresIn != null -> System.currentTimeMillis() + (data.session.expiresIn * 1000)
        else -> null
    }

    return AuthSession(
        accessToken = token,
        refreshToken = refresh,
        expiresAt = expiresAtMillis?.let { Date(it) },
        userId = userId
    )
}
