package com.notchtodo.ui

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.hilt.navigation.compose.hiltViewModel
import com.notchtodo.data.repository.AuthRepository
import com.notchtodo.ui.auth.AuthScreen
import com.notchtodo.ui.navigation.NotchToDoNavHost
import com.notchtodo.ui.theme.NotchToDoTheme
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    @Inject
    lateinit fun authRepository: AuthRepository

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        installSplashScreen()

        setContent {
            NotchToDoTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    val authState by authRepository.authState.collectAsState()

                    when (authState) {
                        is AuthRepository.AuthState.Authenticated -> {
                            NotchToDoNavHost()
                        }
                        is AuthRepository.AuthState.Unauthenticated,
                        is AuthRepository.AuthState.Error -> {
                            AuthScreen()
                        }
                    }
                }
            }
        }
    }
}
