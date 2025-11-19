package com.notchtodo.data.remote

import com.notchtodo.data.remote.dto.*
import retrofit2.Response
import retrofit2.http.*

/**
 * Retrofit interface for Supabase REST API.
 */
interface SupabaseApi {

    // ==================== Tasks ====================

    @GET("rest/v1/tasks")
    suspend fun getTasks(
        @Query("select") select: String = "*",
        @Query("deleted_at") deletedAt: String = "is.null",
        @Query("order") order: String = "sort_order.asc,created_at.desc"
    ): Response<List<TaskDto>>

    @GET("rest/v1/tasks")
    suspend fun getTask(
        @Query("id") id: String,
        @Query("eq") eq: String = id,
        @Query("select") select: String = "*"
    ): Response<List<TaskDto>>

    @GET("rest/v1/tasks")
    suspend fun getTasksByOrb(
        @Query("orb_id") orbId: String,
        @Query("eq") eq: String = orbId,
        @Query("deleted_at") deletedAt: String = "is.null",
        @Query("select") select: String = "*"
    ): Response<List<TaskDto>>

    @GET("rest/v1/tasks")
    suspend fun getTasksUpdatedSince(
        @Query("updated_at") updatedAt: String,
        @Query("gte") gte: String = updatedAt,
        @Query("select") select: String = "*"
    ): Response<List<TaskDto>>

    @POST("rest/v1/tasks")
    @Headers("Prefer: return=representation")
    suspend fun createTask(
        @Body task: TaskCreateRequest
    ): Response<List<TaskDto>>

    @PATCH("rest/v1/tasks")
    @Headers("Prefer: return=representation")
    suspend fun updateTask(
        @Query("id") id: String,
        @Query("eq") eq: String = id,
        @Body updates: TaskUpdateRequest
    ): Response<List<TaskDto>>

    @PATCH("rest/v1/tasks")
    @Headers("Prefer: return=representation")
    suspend fun softDeleteTask(
        @Query("id") id: String,
        @Query("eq") eq: String = id,
        @Body deletedAt: Map<String, String>
    ): Response<List<TaskDto>>

    @DELETE("rest/v1/tasks")
    suspend fun deleteTask(
        @Query("id") id: String,
        @Query("eq") eq: String = id
    ): Response<Unit>

    // ==================== Orbs ====================

    @GET("rest/v1/orbs")
    suspend fun getOrbs(
        @Query("select") select: String = "*",
        @Query("deleted_at") deletedAt: String = "is.null",
        @Query("order") order: String = "sort_order.asc,created_at.desc"
    ): Response<List<OrbDto>>

    @GET("rest/v1/orbs")
    suspend fun getOrb(
        @Query("id") id: String,
        @Query("eq") eq: String = id,
        @Query("select") select: String = "*"
    ): Response<List<OrbDto>>

    @GET("rest/v1/orbs")
    suspend fun getOrbsUpdatedSince(
        @Query("updated_at") updatedAt: String,
        @Query("gte") gte: String = updatedAt,
        @Query("select") select: String = "*"
    ): Response<List<OrbDto>>

    @POST("rest/v1/orbs")
    @Headers("Prefer: return=representation")
    suspend fun createOrb(
        @Body orb: OrbCreateRequest
    ): Response<List<OrbDto>>

    @PATCH("rest/v1/orbs")
    @Headers("Prefer: return=representation")
    suspend fun updateOrb(
        @Query("id") id: String,
        @Query("eq") eq: String = id,
        @Body updates: OrbUpdateRequest
    ): Response<List<OrbDto>>

    @PATCH("rest/v1/orbs")
    @Headers("Prefer: return=representation")
    suspend fun softDeleteOrb(
        @Query("id") id: String,
        @Query("eq") eq: String = id,
        @Body deletedAt: Map<String, String>
    ): Response<List<OrbDto>>

    @DELETE("rest/v1/orbs")
    suspend fun deleteOrb(
        @Query("id") id: String,
        @Query("eq") eq: String = id
    ): Response<Unit>

    // ==================== Auth ====================

    @POST("auth/v1/token")
    @FormUrlEncoded
    suspend fun signIn(
        @Field("email") email: String,
        @Field("password") password: String,
        @Query("grant_type") grantType: String = "password"
    ): Response<AuthResponse>

    @POST("auth/v1/signup")
    suspend fun signUp(
        @Body request: SignUpRequest
    ): Response<AuthResponse>

    @POST("auth/v1/token")
    suspend fun refreshToken(
        @Body request: RefreshTokenRequest,
        @Query("grant_type") grantType: String = "refresh_token"
    ): Response<AuthResponse>

    @POST("auth/v1/logout")
    suspend fun signOut(): Response<Unit>
}
