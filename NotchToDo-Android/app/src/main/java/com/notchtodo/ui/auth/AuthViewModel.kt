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
    val passwordVisible: Boolean = false
)

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(AuthUiState())
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()

    fun onEmailChange(email: String) {
        _uiState.value = _uiState.value.copy(email = email, emailError = null, error = null)
    }

    fun onPasswordChange(password: String) {
        _uiState.value = _uiState.value.copy(password = password, passwordError = null, error = null)
    }

    fun togglePasswordVisibility() {
        _uiState.value = _uiState.value.copy(passwordVisible = !_uiState.value.passwordVisible)
    }

    fun toggleMode() {
        _uiState.value = _uiState.value.copy(
            isSignUp = !_uiState.value.isSignUp,
            error = null,
            emailError = null,
            passwordError = null
        )
    }

    fun signIn() {
        val email = _uiState.value.email
        val password = _uiState.value.password

        if (!validateInputs(email, password)) {
            return
        }

        _uiState.value = _uiState.value.copy(isLoading = true, error = null)

        viewModelScope.launch {
            val result = authRepository.signIn(email, password)

            if (result.isSuccess) {
                DebugLog.log("Sign in successful", DebugLog.Category.AUTH)
            } else {
                val errorMessage = result.exceptionOrNull()?.message ?: "Sign in failed"
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

        if (!validateInputs(email, password)) {
            return
        }

        _uiState.value = _uiState.value.copy(isLoading = true, error = null)

        viewModelScope.launch {
            val result = authRepository.signUp(email, password)

            if (result.isSuccess) {
                DebugLog.log("Sign up successful", DebugLog.Category.AUTH)
            } else {
                val errorMessage = result.exceptionOrNull()?.message ?: "Sign up failed"
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = errorMessage
                )
                DebugLog.error("Sign up failed: $errorMessage", category = DebugLog.Category.AUTH)
            }
        }
    }

    private fun validateInputs(email: String, password: String): Boolean {
        var isValid = true

        if (email.isBlank()) {
            _uiState.value = _uiState.value.copy(emailError = "Email cannot be empty")
            isValid = false
        } else if (!android.util.Patterns.EMAIL_ADDRESS.matcher(email).matches()) {
            _uiState.value = _uiState.value.copy(emailError = "Invalid email format")
            isValid = false
        }

        if (password.isBlank()) {
            _uiState.value = _uiState.value.copy(passwordError = "Password cannot be empty")
            isValid = false
        } else if (password.length < 6) {
            _uiState.value = _uiState.value.copy(passwordError = "Password must be at least 6 characters")
            isValid = false
        }

        return isValid
    }
}
