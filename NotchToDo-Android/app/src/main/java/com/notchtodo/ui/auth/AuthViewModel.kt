package com.notchtodo.ui.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.notchtodo.data.repository.AuthRepository
import com.notchtodo.util.DebugLog
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class AuthUiState(
    val email: String = "",
    val password: String = "",
    val isSignUp: Boolean = false,
    val isLoading: Boolean = false,
    val error: String? = null,
    val emailError: String? = null,
    val passwordError: String? = null,
    val passwordVisible: Boolean = false,
    val isAuthenticated: Boolean = false
)

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(AuthUiState())
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()

    init {
        // Check if already authenticated
        if (authRepository.isAuthenticated()) {
            _uiState.value = _uiState.value.copy(isAuthenticated = true)
        }
    }

    fun onEmailChange(email: String) {
        _uiState.value = _uiState.value.copy(
            email = email.trim(),
            emailError = null,
            error = null
        )
    }

    fun onPasswordChange(password: String) {
        _uiState.value = _uiState.value.copy(
            password = password,
            passwordError = null,
            error = null
        )
    }

    fun togglePasswordVisibility() {
        _uiState.value = _uiState.value.copy(
            passwordVisible = !_uiState.value.passwordVisible
        )
    }

    fun toggleMode() {
        _uiState.value = _uiState.value.copy(
            isSignUp = !_uiState.value.isSignUp,
            error = null,
            emailError = null,
            passwordError = null
        )
    }

    fun clearErrors() {
        _uiState.value = _uiState.value.copy(
            error = null,
            emailError = null,
            passwordError = null
        )
    }

    fun clearForm() {
        _uiState.value = _uiState.value.copy(
            email = "",
            password = "",
            error = null,
            emailError = null,
            passwordError = null,
            passwordVisible = false
        )
    }

    fun signIn() {
        val email = _uiState.value.email
        val password = _uiState.value.password

        if (!validateInputs(email, password, isSignUp = false)) {
            return
        }

        _uiState.value = _uiState.value.copy(isLoading = true, error = null)

        viewModelScope.launch {
            val result = authRepository.signIn(email, password)

            if (result.isSuccess) {
                DebugLog.log("Sign in successful", DebugLog.Category.AUTH)
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    isAuthenticated = true
                )
            } else {
                val errorMessage = parseErrorMessage(result.exceptionOrNull())
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = errorMessage
                )
                DebugLog.error("Sign in failed: $errorMessage", category = DebugLog.Category.AUTH)
            }
        }
    }

    fun signUp() {
        val email = _uiState.value.email
        val password = _uiState.value.password

        if (!validateInputs(email, password, isSignUp = true)) {
            return
        }

        _uiState.value = _uiState.value.copy(isLoading = true, error = null)

        viewModelScope.launch {
            val result = authRepository.signUp(email, password)

            if (result.isSuccess) {
                DebugLog.log("Sign up successful", DebugLog.Category.AUTH)
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    isAuthenticated = true
                )
            } else {
                val errorMessage = parseErrorMessage(result.exceptionOrNull())
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = errorMessage
                )
                DebugLog.error("Sign up failed: $errorMessage", category = DebugLog.Category.AUTH)
            }
        }
    }

    fun signOut() {
        viewModelScope.launch {
            authRepository.signOut()
            _uiState.value = AuthUiState()
        }
    }

    private fun validateInputs(email: String, password: String, isSignUp: Boolean): Boolean {
        var isValid = true

        // Email validation
        when {
            email.isBlank() -> {
                _uiState.value = _uiState.value.copy(emailError = "Email is required")
                isValid = false
            }
            !android.util.Patterns.EMAIL_ADDRESS.matcher(email).matches() -> {
                _uiState.value = _uiState.value.copy(emailError = "Please enter a valid email")
                isValid = false
            }
        }

        // Password validation
        when {
            password.isBlank() -> {
                _uiState.value = _uiState.value.copy(passwordError = "Password is required")
                isValid = false
            }
            password.length < 6 -> {
                _uiState.value = _uiState.value.copy(passwordError = "Password must be at least 6 characters")
                isValid = false
            }
            isSignUp && password.length < 8 -> {
                _uiState.value = _uiState.value.copy(passwordError = "Password must be at least 8 characters for security")
                isValid = false
            }
        }

        return isValid
    }

    private fun parseErrorMessage(exception: Throwable?): String {
        val message = exception?.message ?: "An unexpected error occurred"

        // Parse common Supabase error messages for better UX
        return when {
            message.contains("Invalid login credentials", ignoreCase = true) -> 
                "Invalid email or password. Please try again."
            message.contains("Email not confirmed", ignoreCase = true) ->
                "Please verify your email address before signing in."
            message.contains("User already registered", ignoreCase = true) ->
                "An account with this email already exists."
            message.contains("Password should be at least", ignoreCase = true) ->
                "Password must be at least 6 characters."
            message.contains("rate limit", ignoreCase = true) ->
                "Too many attempts. Please wait a moment and try again."
            message.contains("network", ignoreCase = true) ->
                "Network error. Please check your connection."
            message.contains("timeout", ignoreCase = true) ->
                "Request timed out. Please try again."
            else -> message
        }
    }
}
