import SwiftUI
import AuthenticationServices

// MARK: - Password Strength
enum PasswordStrength: Int {
    case weak = 1
    case fair = 2
    case good = 3
    case strong = 4
    
    var label: String {
        switch self {
        case .weak: return "Weak"
        case .fair: return "Fair"
        case .good: return "Good"
        case .strong: return "Strong"
        }
    }
    
    var color: Color {
        switch self {
        case .weak: return Color(red: 0.95, green: 0.3, blue: 0.3)
        case .fair: return Color(red: 0.95, green: 0.6, blue: 0.2)
        case .good: return Color(red: 0.3, green: 0.75, blue: 0.4)
        case .strong: return Color(red: 0.2, green: 0.65, blue: 0.9)
        }
    }
    
    static func calculate(for password: String) -> PasswordStrength {
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;':\",./<>?")) != nil { score += 1 }
        
        switch score {
        case 0...2: return .weak
        case 3: return .fair
        case 4...5: return .good
        default: return .strong
        }
    }
}

// MARK: - Auth Mode
enum AuthMode {
    case welcome
    case signIn
    case signUp
    case forgotPassword
}

// MARK: - Auth View
struct AuthView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var authMode: AuthMode = .welcome
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var showPasswordRequirements = false
    
    // Animation states
    @State private var logoScale: CGFloat = 0.8
    @State private var contentOpacity: Double = 0
    @State private var cardOffset: CGFloat = 50
    
    private var passwordStrength: PasswordStrength {
        PasswordStrength.calculate(for: password)
    }
    
    private var isFormValid: Bool {
        let emailValid = !email.isEmpty && email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 6
        
        switch authMode {
        case .welcome:
            return false
        case .signIn:
            return emailValid && passwordValid
        case .signUp:
            return emailValid && passwordValid && password == confirmPassword && passwordStrength.rawValue >= 2
        case .forgotPassword:
            return emailValid
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated gradient background
                AnimatedGradientBackground()
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Logo & Branding
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.4, green: 0.5, blue: 1.0),
                                                Color(red: 0.6, green: 0.3, blue: 0.9)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .shadow(color: Color(red: 0.5, green: 0.4, blue: 0.9).opacity(0.4), radius: 20, y: 10)
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 40, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .scaleEffect(logoScale)
                            
                            Text("NotchToDo")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Voice-First Task Manager")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top, geometry.safeAreaInsets.top + 40)
                        .padding(.bottom, 32)
                        
                        // Content Card
                        VStack(spacing: 0) {
                            if authMode == .welcome {
                                welcomeContent
                            } else {
                                formContent
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(.ultraThinMaterial)
                                .background(
                                    RoundedRectangle(cornerRadius: 28)
                                        .fill(Color.white.opacity(0.1))
                                )
                                .shadow(color: .black.opacity(0.15), radius: 30, y: 15)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .padding(.horizontal, 20)
                        .offset(y: cardOffset)
                        .opacity(contentOpacity)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                logoScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                contentOpacity = 1.0
                cardOffset = 0
            }
        }
    }
    
    // MARK: - Welcome Content
    private var welcomeContent: some View {
        VStack(spacing: 20) {
            Text("Welcome")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.top, 28)
            
            Text("Sign in to sync your tasks\nacross all your devices")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 14) {
                // Sign In with Apple
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .cornerRadius(14)
                
                // Sign In with Google
                Button(action: handleGoogleSignIn) {
                    HStack(spacing: 12) {
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 20))
                        Text("Continue with Google")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white)
                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.25))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
                
                // Divider
                HStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                    Text("or")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.vertical, 8)
                
                // Email Sign In
                Button(action: { withAnimation(.spring(response: 0.4)) { authMode = .signIn } }) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 18))
                        Text("Sign In with Email")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.4, green: 0.5, blue: 1.0),
                                Color(red: 0.5, green: 0.35, blue: 0.95)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                
                // Create Account
                Button(action: { withAnimation(.spring(response: 0.4)) { authMode = .signUp } }) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 18))
                        Text("Create Account")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.clear)
                    .foregroundColor(Color(red: 0.4, green: 0.5, blue: 1.0))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(red: 0.4, green: 0.5, blue: 1.0), lineWidth: 2)
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
            // Skip option
            Button(action: { /* Skip for now - use locally */ }) {
                Text("Skip for now")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Form Content
    private var formContent: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.4)) {
                        authMode = .welcome
                        clearForm()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text(formTitle)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Subtitle
            Text(formSubtitle)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            VStack(spacing: 16) {
                // Email Field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Email")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "envelope")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                        
                        TextField("your@email.com", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .font(.system(size: 16))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(14)
                }
                
                // Password Field (not for forgot password)
                if authMode != .forgotPassword {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Password")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if authMode == .signIn {
                                Button(action: {
                                    withAnimation(.spring(response: 0.4)) {
                                        authMode = .forgotPassword
                                        clearForm()
                                    }
                                }) {
                                    Text("Forgot?")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Color(red: 0.4, green: 0.5, blue: 1.0))
                                }
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "lock")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                            
                            if isPasswordVisible {
                                TextField("••••••••", text: $password)
                                    .font(.system(size: 16))
                            } else {
                                SecureField("••••••••", text: $password)
                                    .font(.system(size: 16))
                            }
                            
                            Button(action: { isPasswordVisible.toggle() }) {
                                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(14)
                        
                        // Password Strength (for sign up)
                        if authMode == .signUp && !password.isEmpty {
                            passwordStrengthView
                        }
                    }
                }
                
                // Confirm Password (for sign up)
                if authMode == .signUp {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Confirm Password")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "lock.badge.checkmark")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                            
                            if isConfirmPasswordVisible {
                                TextField("••••••••", text: $confirmPassword)
                                    .font(.system(size: 16))
                            } else {
                                SecureField("••••••••", text: $confirmPassword)
                                    .font(.system(size: 16))
                            }
                            
                            Button(action: { isConfirmPasswordVisible.toggle() }) {
                                Image(systemName: isConfirmPasswordVisible ? "eye.slash" : "eye")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(14)
                        
                        // Password match indicator
                        if !confirmPassword.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: password == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 12))
                                Text(password == confirmPassword ? "Passwords match" : "Passwords do not match")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(password == confirmPassword ? .green : .red)
                            .padding(.top, 4)
                        }
                    }
                }
                
                // Error Message
                if let errorMessage = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                }
                
                // Success Message
                if let successMessage = successMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                        Text(successMessage)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                }
                
                // Submit Button
                Button(action: handleSubmit) {
                    HStack(spacing: 10) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: submitButtonIcon)
                                .font(.system(size: 18))
                            Text(submitButtonTitle)
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        Group {
                            if isFormValid && !isLoading {
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.5, blue: 1.0),
                                        Color(red: 0.5, green: 0.35, blue: 0.95)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            } else {
                                Color.gray.opacity(0.3)
                            }
                        }
                    )
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .disabled(!isFormValid || isLoading)
                
                // Toggle Auth Mode
                if authMode == .signIn {
                    Button(action: {
                        withAnimation(.spring(response: 0.4)) {
                            authMode = .signUp
                            clearForm()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundColor(.secondary)
                            Text("Sign Up")
                                .foregroundColor(Color(red: 0.4, green: 0.5, blue: 1.0))
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 14))
                    }
                } else if authMode == .signUp {
                    Button(action: {
                        withAnimation(.spring(response: 0.4)) {
                            authMode = .signIn
                            clearForm()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .foregroundColor(.secondary)
                            Text("Sign In")
                                .foregroundColor(Color(red: 0.4, green: 0.5, blue: 1.0))
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 14))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }
    
    // MARK: - Password Strength View
    private var passwordStrengthView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(1...4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index <= passwordStrength.rawValue ? passwordStrength.color : Color.gray.opacity(0.2))
                        .frame(height: 4)
                }
            }
            
            HStack {
                Text("Strength: ")
                    .foregroundColor(.secondary)
                Text(passwordStrength.label)
                    .foregroundColor(passwordStrength.color)
                    .fontWeight(.semibold)
            }
            .font(.system(size: 12))
            
            // Password requirements
            VStack(alignment: .leading, spacing: 4) {
                PasswordRequirement(text: "At least 8 characters", isMet: password.count >= 8)
                PasswordRequirement(text: "Contains uppercase letter", isMet: password.rangeOfCharacter(from: .uppercaseLetters) != nil)
                PasswordRequirement(text: "Contains number", isMet: password.rangeOfCharacter(from: .decimalDigits) != nil)
                PasswordRequirement(text: "Contains special character", isMet: password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;':\",./<>?")) != nil)
            }
            .padding(.top, 4)
        }
        .padding(.top, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - Helper Properties
    private var formTitle: String {
        switch authMode {
        case .welcome: return ""
        case .signIn: return "Sign In"
        case .signUp: return "Create Account"
        case .forgotPassword: return "Reset Password"
        }
    }
    
    private var formSubtitle: String {
        switch authMode {
        case .welcome: return ""
        case .signIn: return "Welcome back! Enter your credentials to continue"
        case .signUp: return "Create your account to sync across devices"
        case .forgotPassword: return "Enter your email and we'll send you a reset link"
        }
    }
    
    private var submitButtonTitle: String {
        switch authMode {
        case .welcome: return ""
        case .signIn: return "Sign In"
        case .signUp: return "Create Account"
        case .forgotPassword: return "Send Reset Link"
        }
    }
    
    private var submitButtonIcon: String {
        switch authMode {
        case .welcome: return ""
        case .signIn: return "arrow.right.circle.fill"
        case .signUp: return "person.badge.plus.fill"
        case .forgotPassword: return "envelope.badge.fill"
        }
    }
    
    // MARK: - Actions
    private func handleSubmit() {
        errorMessage = nil
        successMessage = nil
        isLoading = true
        
        Task {
            do {
                switch authMode {
                case .signIn:
                    try await dataManager.signIn(email: email, password: password)
                case .signUp:
                    try await dataManager.signUp(email: email, password: password)
                case .forgotPassword:
                    try await dataManager.resetPassword(email: email)
                    await MainActor.run {
                        successMessage = "If an account exists with this email, you'll receive a reset link."
                        isLoading = false
                    }
                    return
                case .welcome:
                    break
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken,
                  let _ = String(data: identityToken, encoding: .utf8) else {
                errorMessage = "Apple Sign-In failed: Invalid credentials"
                return
            }
            // TODO: Exchange token with Supabase
            successMessage = "Apple Sign-In integration coming soon!"
            
        case .failure(let error):
            if (error as NSError).code != 1001 { // Not user canceled
                errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func handleGoogleSignIn() {
        // TODO: Implement Google Sign-In
        successMessage = "Google Sign-In integration coming soon!"
    }
    
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        errorMessage = nil
        successMessage = nil
        isPasswordVisible = false
        isConfirmPasswordVisible = false
    }
}

// MARK: - Password Requirement View
struct PasswordRequirement: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 10))
                .foregroundColor(isMet ? .green : .gray)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(isMet ? .primary : .secondary)
        }
    }
}

// MARK: - Animated Gradient Background
struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.15, green: 0.15, blue: 0.25),
                Color(red: 0.25, green: 0.2, blue: 0.45),
                Color(red: 0.2, green: 0.25, blue: 0.5),
                Color(red: 0.15, green: 0.15, blue: 0.35)
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
        .overlay {
            // Subtle pattern overlay
            GeometryReader { geo in
                ZStack {
                    // Floating orbs effect
                    ForEach(0..<5) { index in
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 80
                                )
                            )
                            .frame(width: CGFloat.random(in: 100...200))
                            .offset(
                                x: CGFloat.random(in: -geo.size.width/2...geo.size.width/2),
                                y: CGFloat.random(in: -geo.size.height/2...geo.size.height/2)
                            )
                            .blur(radius: 30)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(DataManager.shared)
}
