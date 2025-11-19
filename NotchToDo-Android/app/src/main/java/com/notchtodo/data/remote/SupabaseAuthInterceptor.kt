package com.notchtodo.data.remote

import com.notchtodo.util.SecurePreferences
import okhttp3.Interceptor
import okhttp3.Response
import javax.inject.Inject
import javax.inject.Singleton

/**
 * OkHttp interceptor to add authentication headers to all requests.
 */
@Singleton
class SupabaseAuthInterceptor @Inject constructor(
    private val securePreferences: SecurePreferences,
    private val supabaseConfig: SupabaseConfig
) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val originalRequest = chain.request()
        val builder = originalRequest.newBuilder()

        // Add API key header
        builder.header("apikey", supabaseConfig.anonKey)

        // Add authorization header
        val accessToken = securePreferences.getAccessToken()
        if (accessToken != null) {
            builder.header("Authorization", "Bearer $accessToken")
        } else {
            builder.header("Authorization", "Bearer ${supabaseConfig.anonKey}")
        }

        // Add content type for REST API
        if (originalRequest.url.encodedPath.startsWith("/rest/")) {
            builder.header("Content-Type", "application/json")
            builder.header("Accept", "application/json")
        }

        return chain.proceed(builder.build())
    }
}

/**
 * Supabase configuration
 */
data class SupabaseConfig(
    val projectUrl: String,
    val anonKey: String,
    val storageBucket: String
)
