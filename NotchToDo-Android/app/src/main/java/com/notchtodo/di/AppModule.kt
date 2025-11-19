package com.notchtodo.di

import android.content.Context
import androidx.room.Room
import com.notchtodo.BuildConfig
import com.notchtodo.data.local.NotchToDoDatabase
import com.notchtodo.data.local.dao.OrbDao
import com.notchtodo.data.local.dao.TaskDao
import com.notchtodo.data.remote.SupabaseApi
import com.notchtodo.data.remote.SupabaseAuthInterceptor
import com.notchtodo.data.remote.SupabaseConfig
import com.notchtodo.util.SecurePreferences
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit
import javax.inject.Singleton

/**
 * Hilt module for application-wide dependencies.
 */
@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideSupabaseConfig(): SupabaseConfig {
        return SupabaseConfig(
            projectUrl = BuildConfig.SUPABASE_URL,
            anonKey = BuildConfig.SUPABASE_ANON_KEY,
            storageBucket = BuildConfig.SUPABASE_STORAGE_BUCKET
        )
    }

    @Provides
    @Singleton
    fun provideOkHttpClient(
        authInterceptor: SupabaseAuthInterceptor
    ): OkHttpClient {
        val loggingInterceptor = HttpLoggingInterceptor().apply {
            level = if (BuildConfig.DEBUG) {
                HttpLoggingInterceptor.Level.BODY
            } else {
                HttpLoggingInterceptor.Level.NONE
            }
        }

        return OkHttpClient.Builder()
            .addInterceptor(authInterceptor)
            .addInterceptor(loggingInterceptor)
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build()
    }

    @Provides
    @Singleton
    fun provideRetrofit(
        okHttpClient: OkHttpClient,
        config: SupabaseConfig
    ): Retrofit {
        return Retrofit.Builder()
            .baseUrl(config.projectUrl)
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
    }

    @Provides
    @Singleton
    fun provideSupabaseApi(retrofit: Retrofit): SupabaseApi {
        return retrofit.create(SupabaseApi::class.java)
    }

    @Provides
    @Singleton
    fun provideNotchToDoDatabase(
        @ApplicationContext context: Context
    ): NotchToDoDatabase {
        return Room.databaseBuilder(
            context,
            NotchToDoDatabase::class.java,
            NotchToDoDatabase.DATABASE_NAME
        )
            .fallbackToDestructiveMigration()
            .build()
    }

    @Provides
    @Singleton
    fun provideTaskDao(database: NotchToDoDatabase): TaskDao {
        return database.taskDao()
    }

    @Provides
    @Singleton
    fun provideOrbDao(database: NotchToDoDatabase): OrbDao {
        return database.orbDao()
    }

    @Provides
    @Singleton
    fun provideSecurePreferences(
        @ApplicationContext context: Context
    ): SecurePreferences {
        return SecurePreferences(context)
    }
}
