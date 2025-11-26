package com.notchtodo.ui.auth

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import kotlinx.coroutines.delay

// Password strength enum
enum class PasswordStrength(val label: String, val color: Color) {
    WEAK("Weak", Color(0xFFF04040)),
    FAIR("Fair", Color(0xFFF09020)),
    GOOD("Good", Color(0xFF40C060)),
    STRONG("Strong", Color(0xFF3090E0));

    companion object {
        fun calculate(password: String): PasswordStrength {
            var score = 0
            if (password.length >= 8) score++
            if (password.length >= 12) score++
            if (password.any { it.isUpperCase() }) score++
            if (password.any { it.isLowerCase() }) score++
            if (password.any { it.isDigit() }) score++
            if (password.any { !it.isLetterOrDigit() }) score++

            return when (score) {
                in 0..2 -> WEAK
                3 -> FAIR
                in 4..5 -> GOOD
                else -> STRONG
            }
        }
    }
}

// Auth mode
enum class AuthMode {
    WELCOME, SIGN_IN, SIGN_UP, FORGOT_PASSWORD
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AuthScreen(
    viewModel: AuthViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val focusManager = LocalFocusManager.current

    // Animation states
    var logoScale by remember { mutableStateOf(0.8f) }
    var contentAlpha by remember { mutableStateOf(0f) }
    var authMode by remember { mutableStateOf(AuthMode.WELCOME) }
    var confirmPassword by remember { mutableStateOf("") }
    var confirmPasswordVisible by remember { mutableStateOf(false) }
    var successMessage by remember { mutableStateOf<String?>(null) }

    // Animate gradient
    val infiniteTransition = rememberInfiniteTransition(label = "gradient")
    val gradientOffset by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(5000, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "gradientOffset"
    )

    // Initial animations
    LaunchedEffect(Unit) {
        logoScale = 1f
        delay(200)
        contentAlpha = 1f
    }

    val passwordStrength = remember(uiState.password) {
        PasswordStrength.calculate(uiState.password)
    }

    val passwordsMatch = remember(uiState.password, confirmPassword) {
        uiState.password == confirmPassword && confirmPassword.isNotEmpty()
    }

    val isFormValid = remember(uiState.email, uiState.password, confirmPassword, authMode, passwordStrength) {
        val emailValid = uiState.email.isNotBlank() && 
            android.util.Patterns.EMAIL_ADDRESS.matcher(uiState.email).matches()
        val passwordValid = uiState.password.length >= 6

        when (authMode) {
            AuthMode.WELCOME -> false
            AuthMode.SIGN_IN -> emailValid && passwordValid
            AuthMode.SIGN_UP -> emailValid && passwordValid && 
                passwordsMatch && passwordStrength.ordinal >= PasswordStrength.FAIR.ordinal
            AuthMode.FORGOT_PASSWORD -> emailValid
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                brush = Brush.linearGradient(
                    colors = listOf(
                        Color(0xFF1A1A2E),
                        Color(0xFF2D2B55),
                        Color(0xFF252545),
                        Color(0xFF1A1A35)
                    ),
                    start = Offset(0f, gradientOffset * 1000),
                    end = Offset(1000f, 1000f + gradientOffset * 500)
                )
            )
    ) {
        // Floating orbs background effect
        FloatingOrbs()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(60.dp))

            // Logo Section
            val animatedScale by animateFloatAsState(
                targetValue = logoScale,
                animationSpec = spring(dampingRatio = 0.6f, stiffness = 300f),
                label = "logoScale"
            )

            Box(
                modifier = Modifier
                    .scale(animatedScale)
                    .size(90.dp)
                    .clip(CircleShape)
                    .background(
                        brush = Brush.linearGradient(
                            colors = listOf(
                                Color(0xFF6070FF),
                                Color(0xFF8050E8)
                            )
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = null,
                    modifier = Modifier.size(48.dp),
                    tint = Color.White
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            Text(
                text = "NotchToDo",
                style = MaterialTheme.typography.headlineLarge.copy(
                    fontWeight = FontWeight.Bold,
                    letterSpacing = (-0.5).sp
                ),
                color = Color.White
            )

            Text(
                text = "Voice-First Task Manager",
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.7f)
            )

            Spacer(modifier = Modifier.height(32.dp))

            // Content Card
            val animatedAlpha by animateFloatAsState(
                targetValue = contentAlpha,
                animationSpec = tween(600),
                label = "contentAlpha"
            )

            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 32.dp),
                shape = RoundedCornerShape(28.dp),
                colors = CardDefaults.cardColors(
                    containerColor = Color.White.copy(alpha = 0.12f * animatedAlpha)
                )
            ) {
                AnimatedVisibility(
                    visible = authMode == AuthMode.WELCOME,
                    enter = fadeIn() + slideInVertically(),
                    exit = fadeOut() + slideOutVertically()
                ) {
                    WelcomeContent(
                        onSignInClick = { authMode = AuthMode.SIGN_IN },
                        onSignUpClick = { authMode = AuthMode.SIGN_UP },
                        onGoogleClick = { successMessage = "Google Sign-In coming soon!" },
                        onAppleClick = { /* Apple sign in - Android not typically supported */ }
                    )
                }

                AnimatedVisibility(
                    visible = authMode != AuthMode.WELCOME,
                    enter = fadeIn() + slideInVertically(),
                    exit = fadeOut() + slideOutVertically()
                ) {
                    FormContent(
                        authMode = authMode,
                        email = uiState.email,
                        password = uiState.password,
                        confirmPassword = confirmPassword,
                        passwordVisible = uiState.passwordVisible,
                        confirmPasswordVisible = confirmPasswordVisible,
                        passwordStrength = passwordStrength,
                        passwordsMatch = passwordsMatch,
                        isLoading = uiState.isLoading,
                        isFormValid = isFormValid,
                        errorMessage = uiState.error,
                        successMessage = successMessage,
                        emailError = uiState.emailError,
                        passwordError = uiState.passwordError,
                        onBackClick = {
                            authMode = AuthMode.WELCOME
                            viewModel.clearErrors()
                            confirmPassword = ""
                            successMessage = null
                        },
                        onEmailChange = viewModel::onEmailChange,
                        onPasswordChange = viewModel::onPasswordChange,
                        onConfirmPasswordChange = { confirmPassword = it },
                        onTogglePasswordVisibility = viewModel::togglePasswordVisibility,
                        onToggleConfirmPasswordVisibility = { confirmPasswordVisible = !confirmPasswordVisible },
                        onForgotPasswordClick = { 
                            authMode = AuthMode.FORGOT_PASSWORD
                            viewModel.clearErrors()
                        },
                        onSubmit = {
                            focusManager.clearFocus()
                            when (authMode) {
                                AuthMode.SIGN_IN -> viewModel.signIn()
                                AuthMode.SIGN_UP -> viewModel.signUp()
                                AuthMode.FORGOT_PASSWORD -> {
                                    successMessage = "If an account exists, you'll receive a reset email."
                                }
                                else -> {}
                            }
                        },
                        onToggleMode = {
                            authMode = if (authMode == AuthMode.SIGN_IN) AuthMode.SIGN_UP else AuthMode.SIGN_IN
                            viewModel.clearErrors()
                            confirmPassword = ""
                        },
                        focusManager = focusManager
                    )
                }
            }
        }
    }
}

@Composable
private fun FloatingOrbs() {
    val infiniteTransition = rememberInfiniteTransition(label = "orbs")

    repeat(4) { index ->
        val yOffset by infiniteTransition.animateFloat(
            initialValue = -50f,
            targetValue = 50f,
            animationSpec = infiniteRepeatable(
                animation = tween(3000 + index * 500, easing = FastOutSlowInEasing),
                repeatMode = RepeatMode.Reverse
            ),
            label = "orbY$index"
        )

        Box(
            modifier = Modifier
                .offset(
                    x = (50 + index * 80).dp,
                    y = (100 + index * 150 + yOffset).dp
                )
                .size((60 + index * 30).dp)
                .blur(40.dp)
                .clip(CircleShape)
                .background(
                    Color(0xFF6070FF).copy(alpha = 0.15f - index * 0.02f)
                )
        )
    }
}

@Composable
private fun WelcomeContent(
    onSignInClick: () -> Unit,
    onSignUpClick: () -> Unit,
    onGoogleClick: () -> Unit,
    onAppleClick: () -> Unit
) {
    Column(
        modifier = Modifier.padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = "Welcome",
            style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
            color = Color.White
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "Sign in to sync your tasks\nacross all your devices",
            style = MaterialTheme.typography.bodyMedium,
            color = Color.White.copy(alpha = 0.7f),
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Google Sign-In Button
        SocialButton(
            text = "Continue with Google",
            icon = Icons.Default.Email, // Use appropriate Google icon
            backgroundColor = Color.White,
            contentColor = Color(0xFF202020),
            onClick = onGoogleClick
        )

        Spacer(modifier = Modifier.height(12.dp))

        // Divider
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            HorizontalDivider(
                modifier = Modifier.weight(1f),
                color = Color.White.copy(alpha = 0.2f)
            )
            Text(
                text = "or",
                modifier = Modifier.padding(horizontal = 16.dp),
                style = MaterialTheme.typography.bodySmall,
                color = Color.White.copy(alpha = 0.5f)
            )
            HorizontalDivider(
                modifier = Modifier.weight(1f),
                color = Color.White.copy(alpha = 0.2f)
            )
        }

        // Email Sign In Button
        GradientButton(
            text = "Sign In with Email",
            icon = Icons.Default.Email,
            onClick = onSignInClick
        )

        Spacer(modifier = Modifier.height(12.dp))

        // Create Account Button
        OutlinedButton(
            onClick = onSignUpClick,
            modifier = Modifier
                .fillMaxWidth()
                .height(54.dp),
            shape = RoundedCornerShape(14.dp),
            colors = ButtonDefaults.outlinedButtonColors(
                contentColor = Color(0xFF6070FF)
            ),
            border = ButtonDefaults.outlinedButtonBorder.copy(
                brush = Brush.linearGradient(
                    colors = listOf(Color(0xFF6070FF), Color(0xFF8050E8))
                )
            )
        ) {
            Icon(
                imageVector = Icons.Default.PersonAdd,
                contentDescription = null,
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                text = "Create Account",
                style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold)
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Skip option
        TextButton(onClick = { /* Skip */ }) {
            Text(
                text = "Skip for now",
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.5f)
            )
        }
    }
}

@Composable
private fun FormContent(
    authMode: AuthMode,
    email: String,
    password: String,
    confirmPassword: String,
    passwordVisible: Boolean,
    confirmPasswordVisible: Boolean,
    passwordStrength: PasswordStrength,
    passwordsMatch: Boolean,
    isLoading: Boolean,
    isFormValid: Boolean,
    errorMessage: String?,
    successMessage: String?,
    emailError: String?,
    passwordError: String?,
    onBackClick: () -> Unit,
    onEmailChange: (String) -> Unit,
    onPasswordChange: (String) -> Unit,
    onConfirmPasswordChange: (String) -> Unit,
    onTogglePasswordVisibility: () -> Unit,
    onToggleConfirmPasswordVisibility: () -> Unit,
    onForgotPasswordClick: () -> Unit,
    onSubmit: () -> Unit,
    onToggleMode: () -> Unit,
    focusManager: androidx.compose.ui.focus.FocusManager
) {
    val formTitle = when (authMode) {
        AuthMode.SIGN_IN -> "Sign In"
        AuthMode.SIGN_UP -> "Create Account"
        AuthMode.FORGOT_PASSWORD -> "Reset Password"
        else -> ""
    }

    val formSubtitle = when (authMode) {
        AuthMode.SIGN_IN -> "Welcome back! Enter your credentials"
        AuthMode.SIGN_UP -> "Create your account to sync across devices"
        AuthMode.FORGOT_PASSWORD -> "Enter your email to receive a reset link"
        else -> ""
    }

    Column(
        modifier = Modifier.padding(24.dp)
    ) {
        // Header with back button
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(
                onClick = onBackClick,
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.1f))
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = Color.White
                )
            }

            Spacer(modifier = Modifier.weight(1f))

            Text(
                text = formTitle,
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                color = Color.White
            )

            Spacer(modifier = Modifier.weight(1f))

            // Invisible spacer for centering
            Spacer(modifier = Modifier.size(40.dp))
        }

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = formSubtitle,
            style = MaterialTheme.typography.bodyMedium,
            color = Color.White.copy(alpha = 0.7f),
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Email Field
        AuthTextField(
            value = email,
            onValueChange = onEmailChange,
            label = "Email",
            leadingIcon = Icons.Outlined.Email,
            keyboardType = KeyboardType.Email,
            imeAction = if (authMode == AuthMode.FORGOT_PASSWORD) ImeAction.Done else ImeAction.Next,
            onNext = { 
                if (authMode == AuthMode.FORGOT_PASSWORD) {
                    focusManager.clearFocus()
                    onSubmit()
                } else {
                    focusManager.moveFocus(FocusDirection.Down)
                }
            },
            error = emailError
        )

        // Password fields (not for forgot password)
        if (authMode != AuthMode.FORGOT_PASSWORD) {
            Spacer(modifier = Modifier.height(16.dp))

            // Password with forgot option
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Password",
                    style = MaterialTheme.typography.labelMedium,
                    color = Color.White.copy(alpha = 0.7f)
                )
                if (authMode == AuthMode.SIGN_IN) {
                    TextButton(
                        onClick = onForgotPasswordClick,
                        contentPadding = PaddingValues(0.dp)
                    ) {
                        Text(
                            text = "Forgot?",
                            style = MaterialTheme.typography.labelMedium,
                            color = Color(0xFF6070FF)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(6.dp))

            AuthTextField(
                value = password,
                onValueChange = onPasswordChange,
                label = "",
                leadingIcon = Icons.Outlined.Lock,
                trailingIcon = if (passwordVisible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                onTrailingIconClick = onTogglePasswordVisibility,
                isPassword = !passwordVisible,
                keyboardType = KeyboardType.Password,
                imeAction = if (authMode == AuthMode.SIGN_UP) ImeAction.Next else ImeAction.Done,
                onNext = {
                    if (authMode == AuthMode.SIGN_UP) {
                        focusManager.moveFocus(FocusDirection.Down)
                    } else {
                        focusManager.clearFocus()
                        onSubmit()
                    }
                },
                error = passwordError
            )

            // Password strength indicator (for sign up)
            if (authMode == AuthMode.SIGN_UP && password.isNotEmpty()) {
                Spacer(modifier = Modifier.height(12.dp))
                PasswordStrengthIndicator(passwordStrength)
                Spacer(modifier = Modifier.height(8.dp))
                PasswordRequirements(password)
            }

            // Confirm password (for sign up)
            if (authMode == AuthMode.SIGN_UP) {
                Spacer(modifier = Modifier.height(16.dp))

                Text(
                    text = "Confirm Password",
                    style = MaterialTheme.typography.labelMedium,
                    color = Color.White.copy(alpha = 0.7f)
                )

                Spacer(modifier = Modifier.height(6.dp))

                AuthTextField(
                    value = confirmPassword,
                    onValueChange = onConfirmPasswordChange,
                    label = "",
                    leadingIcon = Icons.Outlined.LockOpen,
                    trailingIcon = if (confirmPasswordVisible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                    onTrailingIconClick = onToggleConfirmPasswordVisibility,
                    isPassword = !confirmPasswordVisible,
                    keyboardType = KeyboardType.Password,
                    imeAction = ImeAction.Done,
                    onNext = {
                        focusManager.clearFocus()
                        onSubmit()
                    }
                )

                // Password match indicator
                if (confirmPassword.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = if (passwordsMatch) Icons.Default.CheckCircle else Icons.Default.Cancel,
                            contentDescription = null,
                            modifier = Modifier.size(16.dp),
                            tint = if (passwordsMatch) Color(0xFF40C060) else Color(0xFFF04040)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = if (passwordsMatch) "Passwords match" else "Passwords do not match",
                            style = MaterialTheme.typography.bodySmall,
                            color = if (passwordsMatch) Color(0xFF40C060) else Color(0xFFF04040)
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Error message
        AnimatedVisibility(visible = errorMessage != null) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 12.dp),
                shape = RoundedCornerShape(10.dp),
                color = Color(0xFFF04040).copy(alpha = 0.15f)
            ) {
                Row(
                    modifier = Modifier.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.Warning,
                        contentDescription = null,
                        tint = Color(0xFFF04040),
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = errorMessage ?: "",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFFF04040)
                    )
                }
            }
        }

        // Success message
        AnimatedVisibility(visible = successMessage != null) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 12.dp),
                shape = RoundedCornerShape(10.dp),
                color = Color(0xFF40C060).copy(alpha = 0.15f)
            ) {
                Row(
                    modifier = Modifier.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.CheckCircle,
                        contentDescription = null,
                        tint = Color(0xFF40C060),
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = successMessage ?: "",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFF40C060)
                    )
                }
            }
        }

        // Submit button
        val submitIcon = when (authMode) {
            AuthMode.SIGN_IN -> Icons.Default.Login
            AuthMode.SIGN_UP -> Icons.Default.PersonAdd
            AuthMode.FORGOT_PASSWORD -> Icons.Default.Send
            else -> Icons.Default.ArrowForward
        }

        val submitText = when (authMode) {
            AuthMode.SIGN_IN -> "Sign In"
            AuthMode.SIGN_UP -> "Create Account"
            AuthMode.FORGOT_PASSWORD -> "Send Reset Link"
            else -> ""
        }

        GradientButton(
            text = submitText,
            icon = submitIcon,
            enabled = isFormValid && !isLoading,
            isLoading = isLoading,
            onClick = onSubmit
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Toggle mode
        if (authMode == AuthMode.SIGN_IN || authMode == AuthMode.SIGN_UP) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = if (authMode == AuthMode.SIGN_IN) "Don't have an account?" else "Already have an account?",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.White.copy(alpha = 0.7f)
                )
                TextButton(onClick = onToggleMode) {
                    Text(
                        text = if (authMode == AuthMode.SIGN_IN) "Sign Up" else "Sign In",
                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                        color = Color(0xFF6070FF)
                    )
                }
            }
        }
    }
}

@Composable
private fun AuthTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    leadingIcon: ImageVector,
    trailingIcon: ImageVector? = null,
    onTrailingIconClick: (() -> Unit)? = null,
    isPassword: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
    imeAction: ImeAction = ImeAction.Next,
    onNext: () -> Unit = {},
    error: String? = null
) {
    Column {
        if (label.isNotEmpty()) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                color = Color.White.copy(alpha = 0.7f)
            )
            Spacer(modifier = Modifier.height(6.dp))
        }

        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            visualTransformation = if (isPassword) PasswordVisualTransformation() else VisualTransformation.None,
            keyboardOptions = KeyboardOptions(
                keyboardType = keyboardType,
                imeAction = imeAction
            ),
            keyboardActions = KeyboardActions(
                onNext = { onNext() },
                onDone = { onNext() }
            ),
            leadingIcon = {
                Icon(
                    imageVector = leadingIcon,
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.5f)
                )
            },
            trailingIcon = if (trailingIcon != null) {
                {
                    IconButton(onClick = { onTrailingIconClick?.invoke() }) {
                        Icon(
                            imageVector = trailingIcon,
                            contentDescription = null,
                            tint = Color.White.copy(alpha = 0.5f)
                        )
                    }
                }
            } else null,
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = Color.White,
                unfocusedTextColor = Color.White,
                focusedContainerColor = Color.White.copy(alpha = 0.08f),
                unfocusedContainerColor = Color.White.copy(alpha = 0.05f),
                focusedBorderColor = Color(0xFF6070FF),
                unfocusedBorderColor = Color.Transparent,
                cursorColor = Color(0xFF6070FF),
                errorBorderColor = Color(0xFFF04040)
            ),
            shape = RoundedCornerShape(14.dp),
            isError = error != null
        )

        if (error != null) {
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = error,
                style = MaterialTheme.typography.bodySmall,
                color = Color(0xFFF04040)
            )
        }
    }
}

@Composable
private fun PasswordStrengthIndicator(strength: PasswordStrength) {
    Column {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            repeat(4) { index ->
                val isActive = index <= strength.ordinal
                val color by animateColorAsState(
                    targetValue = if (isActive) strength.color else Color.White.copy(alpha = 0.2f),
                    label = "strengthColor"
                )
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(4.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(color)
                )
            }
        }

        Spacer(modifier = Modifier.height(6.dp))

        Row {
            Text(
                text = "Strength: ",
                style = MaterialTheme.typography.bodySmall,
                color = Color.White.copy(alpha = 0.7f)
            )
            Text(
                text = strength.label,
                style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold),
                color = strength.color
            )
        }
    }
}

@Composable
private fun PasswordRequirements(password: String) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        PasswordRequirementItem("At least 8 characters", password.length >= 8)
        PasswordRequirementItem("Contains uppercase letter", password.any { it.isUpperCase() })
        PasswordRequirementItem("Contains number", password.any { it.isDigit() })
        PasswordRequirementItem("Contains special character", password.any { !it.isLetterOrDigit() })
    }
}

@Composable
private fun PasswordRequirementItem(text: String, isMet: Boolean) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(
            imageVector = if (isMet) Icons.Default.CheckCircle else Icons.Outlined.Circle,
            contentDescription = null,
            modifier = Modifier.size(14.dp),
            tint = if (isMet) Color(0xFF40C060) else Color.White.copy(alpha = 0.4f)
        )
        Spacer(modifier = Modifier.width(6.dp))
        Text(
            text = text,
            style = MaterialTheme.typography.bodySmall,
            color = if (isMet) Color.White else Color.White.copy(alpha = 0.5f)
        )
    }
}

@Composable
private fun SocialButton(
    text: String,
    icon: ImageVector,
    backgroundColor: Color,
    contentColor: Color,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .height(54.dp),
        shape = RoundedCornerShape(14.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = backgroundColor,
            contentColor = contentColor
        )
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Text(
            text = text,
            style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold)
        )
    }
}

@Composable
private fun GradientButton(
    text: String,
    icon: ImageVector,
    enabled: Boolean = true,
    isLoading: Boolean = false,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .height(54.dp),
        enabled = enabled && !isLoading,
        shape = RoundedCornerShape(14.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.Transparent,
            contentColor = Color.White,
            disabledContainerColor = Color.Transparent,
            disabledContentColor = Color.White.copy(alpha = 0.5f)
        ),
        contentPadding = PaddingValues(0.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    brush = if (enabled && !isLoading) {
                        Brush.linearGradient(
                            colors = listOf(Color(0xFF6070FF), Color(0xFF8050E8))
                        )
                    } else {
                        Brush.linearGradient(
                            colors = listOf(
                                Color.White.copy(alpha = 0.15f),
                                Color.White.copy(alpha = 0.1f)
                            )
                        )
                    }
                ),
            contentAlignment = Alignment.Center
        ) {
            if (isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(24.dp),
                    color = Color.White,
                    strokeWidth = 2.dp
                )
            } else {
                Row(
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(
                        text = text,
                        style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Bold)
                    )
                }
            }
        }
    }
}
