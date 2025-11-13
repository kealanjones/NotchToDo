import Cocoa

// MARK: - Auth State
enum AuthState {
    case initial
    case signIn
    case signUp
    case loading
}

// MARK: - Auth Window Controller
final class AuthWindowController: NSWindowController {
    private var authViewController: AuthViewController?
    
    convenience init() {
        let contentRect = NSRect(x: 0, y: 0, width: 480, height: 620)
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .fullSizeContentView]
        let window = NSWindow(contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false)
        
        window.title = "NotchToDo"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.level = .floating
        window.isReleasedWhenClosed = false
        
        self.init(window: window)
        
        let viewController = AuthViewController()
        self.authViewController = viewController
        window.contentViewController = viewController
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Auth View Controller
final class AuthViewController: NSViewController {
    weak var delegate: AuthViewControllerDelegate?
    
    private var authState: AuthState = .initial {
        didSet { updateUI() }
    }
    
    private var signInButton: NSButton!
    private var signUpButton: NSButton!
    private var skipButton: NSButton!
    private var emailField: NSTextField!
    private var passwordField: NSSecureTextField!
    private var confirmPasswordField: NSSecureTextField!
    private var submitButton: NSButton!
    private var switchAuthButton: NSButton!
    private var errorLabel: NSTextField!
    private var loadingIndicator: NSProgressIndicator!
    private var formContainer: NSView!
    
    private var titleLabel: NSTextField!
    private var subtitleLabel: NSTextField!
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 620))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateUI()
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor
        
        // Beautiful gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = view.bounds
        gradientLayer.colors = [
            NSColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 1.0).cgColor,
            NSColor(red: 0.96, green: 0.97, blue: 1.0, alpha: 1.0).cgColor,
            NSColor(red: 0.98, green: 0.96, blue: 0.99, alpha: 1.0).cgColor
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        view.layer?.insertSublayer(gradientLayer, at: 0)
        
        // Content container to ensure safe margins
        let contentContainer = NSView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentContainer)
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 60),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40)
        ])
        
        // App icon circle
        let iconCircle = NSView()
        iconCircle.wantsLayer = true
        iconCircle.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.12).cgColor
        iconCircle.layer?.cornerRadius = 35
        iconCircle.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(iconCircle)
        NSLayoutConstraint.activate([
            iconCircle.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            iconCircle.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            iconCircle.widthAnchor.constraint(equalToConstant: 70),
            iconCircle.heightAnchor.constraint(equalToConstant: 70)
        ])
        
        // Icon emoji
        let iconLabel = NSTextField(labelWithString: "📋")
        iconLabel.font = NSFont.systemFont(ofSize: 36)
        iconLabel.alignment = .center
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.addSubview(iconLabel)
        NSLayoutConstraint.activate([
            iconLabel.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor)
        ])
        
        // App name
        let appNameLabel = NSTextField(labelWithString: "NotchToDo")
        appNameLabel.font = NSFont.systemFont(ofSize: 28, weight: .bold)
        appNameLabel.textColor = NSColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        appNameLabel.alignment = .center
        appNameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(appNameLabel)
        NSLayoutConstraint.activate([
            appNameLabel.topAnchor.constraint(equalTo: iconCircle.bottomAnchor, constant: 16),
            appNameLabel.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor)
        ])
        
        // Tagline
        let taglineLabel = NSTextField(labelWithString: "Your tasks, always in sight")
        taglineLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        taglineLabel.textColor = NSColor(red: 0.45, green: 0.45, blue: 0.55, alpha: 1.0)
        taglineLabel.alignment = .center
        taglineLabel.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(taglineLabel)
        NSLayoutConstraint.activate([
            taglineLabel.topAnchor.constraint(equalTo: appNameLabel.bottomAnchor, constant: 8),
            taglineLabel.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor)
        ])
        
        // Initial state buttons container
        let initialButtonsStack = NSStackView()
        initialButtonsStack.orientation = .vertical
        initialButtonsStack.spacing = 12
        initialButtonsStack.alignment = .leading
        initialButtonsStack.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(initialButtonsStack)
        NSLayoutConstraint.activate([
            initialButtonsStack.topAnchor.constraint(equalTo: taglineLabel.bottomAnchor, constant: 40),
            initialButtonsStack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            initialButtonsStack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor)
        ])
        
        // Sign in button
        signInButton = NSButton(title: "Sign In", target: self, action: #selector(switchToSignIn))
        signInButton.bezelStyle = .rounded
        signInButton.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        signInButton.contentTintColor = .white
        signInButton.wantsLayer = true
        signInButton.layer?.backgroundColor = NSColor.systemBlue.cgColor
        signInButton.layer?.cornerRadius = 12
        signInButton.translatesAutoresizingMaskIntoConstraints = false
        signInButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        initialButtonsStack.addArrangedSubview(signInButton)
        signInButton.widthAnchor.constraint(equalTo: initialButtonsStack.widthAnchor).isActive = true
        
        // Sign up button
        signUpButton = NSButton(title: "Create Account", target: self, action: #selector(switchToSignUp))
        signUpButton.bezelStyle = .rounded
        signUpButton.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        signUpButton.contentTintColor = NSColor.systemBlue
        signUpButton.wantsLayer = true
        signUpButton.layer?.backgroundColor = NSColor.white.cgColor
        signUpButton.layer?.cornerRadius = 12
        signUpButton.layer?.borderWidth = 1.5
        signUpButton.layer?.borderColor = NSColor.systemBlue.cgColor
        signUpButton.translatesAutoresizingMaskIntoConstraints = false
        signUpButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        initialButtonsStack.addArrangedSubview(signUpButton)
        signUpButton.widthAnchor.constraint(equalTo: initialButtonsStack.widthAnchor).isActive = true
        
        // Skip button
        skipButton = NSButton(title: "Skip for now", target: self, action: #selector(skipAuth))
        skipButton.isBordered = false
        skipButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        skipButton.contentTintColor = NSColor(red: 0.5, green: 0.5, blue: 0.6, alpha: 1.0)
        skipButton.alignment = .center
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        initialButtonsStack.addArrangedSubview(skipButton)
        skipButton.widthAnchor.constraint(equalTo: initialButtonsStack.widthAnchor).isActive = true
        
        // Error label
        errorLabel = NSTextField(labelWithString: "")
        errorLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        errorLabel.textColor = NSColor.systemRed
        errorLabel.alignment = .center
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(errorLabel)
        NSLayoutConstraint.activate([
            errorLabel.topAnchor.constraint(equalTo: initialButtonsStack.bottomAnchor, constant: 16),
            errorLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            errorLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor)
        ])
        
        // Loading indicator
        loadingIndicator = NSProgressIndicator()
        loadingIndicator.style = .spinning
        loadingIndicator.controlSize = .regular
        loadingIndicator.isIndeterminate = true
        loadingIndicator.isHidden = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 16)
        ])
        
        // Form container (hidden initially)
        formContainer = NSView()
        formContainer.wantsLayer = true
        formContainer.layer?.backgroundColor = NSColor.white.cgColor
        formContainer.layer?.cornerRadius = 18
        formContainer.layer?.shadowColor = NSColor.black.cgColor
        formContainer.layer?.shadowOpacity = 0.1
        formContainer.layer?.shadowOffset = CGSize(width: 0, height: 2)
        formContainer.layer?.shadowRadius = 12
        formContainer.translatesAutoresizingMaskIntoConstraints = false
        formContainer.isHidden = true
        contentContainer.addSubview(formContainer)
        NSLayoutConstraint.activate([
            formContainer.topAnchor.constraint(equalTo: taglineLabel.bottomAnchor, constant: 32),
            formContainer.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            formContainer.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            formContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ])
        
        // Form stack
        let formStack = NSStackView()
        formStack.orientation = .vertical
        formStack.spacing = 16
        formStack.alignment = .leading
        formStack.translatesAutoresizingMaskIntoConstraints = false
        formContainer.addSubview(formStack)
        NSLayoutConstraint.activate([
            formStack.topAnchor.constraint(equalTo: formContainer.topAnchor, constant: 28),
            formStack.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor, constant: 24),
            formStack.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor, constant: -24),
            formStack.bottomAnchor.constraint(lessThanOrEqualTo: formContainer.bottomAnchor, constant: -28)
        ])
        
        // Title
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = NSColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        titleLabel.alignment = .left
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        formStack.addArrangedSubview(titleLabel)
        titleLabel.widthAnchor.constraint(equalTo: formStack.widthAnchor).isActive = true
        
        // Subtitle
        subtitleLabel = NSTextField(labelWithString: "")
        subtitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = NSColor(red: 0.45, green: 0.45, blue: 0.55, alpha: 1.0)
        subtitleLabel.alignment = .left
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        formStack.addArrangedSubview(subtitleLabel)
        subtitleLabel.widthAnchor.constraint(equalTo: formStack.widthAnchor).isActive = true
        
        // Spacer
        let spacer1 = NSView()
        spacer1.translatesAutoresizingMaskIntoConstraints = false
        spacer1.heightAnchor.constraint(equalToConstant: 4).isActive = true
        formStack.addArrangedSubview(spacer1)
        
        // Email field
        emailField = NSTextField()
        emailField.placeholderString = "Email address"
        emailField.bezelStyle = .roundedBezel
        emailField.isBordered = true
        emailField.font = NSFont.systemFont(ofSize: 14)
        emailField.wantsLayer = true
        emailField.layer?.cornerRadius = 10
        emailField.layer?.borderWidth = 1
        emailField.layer?.borderColor = NSColor(red: 0.88, green: 0.88, blue: 0.90, alpha: 1.0).cgColor
        emailField.translatesAutoresizingMaskIntoConstraints = false
        emailField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        formStack.addArrangedSubview(emailField)
        emailField.widthAnchor.constraint(equalTo: formStack.widthAnchor).isActive = true
        
        // Password field
        passwordField = NSSecureTextField()
        passwordField.placeholderString = "Password"
        passwordField.bezelStyle = .roundedBezel
        passwordField.isBordered = true
        passwordField.font = NSFont.systemFont(ofSize: 14)
        passwordField.wantsLayer = true
        passwordField.layer?.cornerRadius = 10
        passwordField.layer?.borderWidth = 1
        passwordField.layer?.borderColor = NSColor(red: 0.88, green: 0.88, blue: 0.90, alpha: 1.0).cgColor
        passwordField.translatesAutoresizingMaskIntoConstraints = false
        passwordField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        passwordField.target = self
        passwordField.action = #selector(submitForm)
        formStack.addArrangedSubview(passwordField)
        passwordField.widthAnchor.constraint(equalTo: formStack.widthAnchor).isActive = true
        
        // Confirm password field (for sign up)
        confirmPasswordField = NSSecureTextField()
        confirmPasswordField.placeholderString = "Confirm password"
        confirmPasswordField.bezelStyle = .roundedBezel
        confirmPasswordField.isBordered = true
        confirmPasswordField.font = NSFont.systemFont(ofSize: 14)
        confirmPasswordField.wantsLayer = true
        confirmPasswordField.layer?.cornerRadius = 10
        confirmPasswordField.layer?.borderWidth = 1
        confirmPasswordField.layer?.borderColor = NSColor(red: 0.88, green: 0.88, blue: 0.90, alpha: 1.0).cgColor
        confirmPasswordField.isHidden = true
        confirmPasswordField.translatesAutoresizingMaskIntoConstraints = false
        confirmPasswordField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        confirmPasswordField.target = self
        confirmPasswordField.action = #selector(submitForm)
        formStack.addArrangedSubview(confirmPasswordField)
        confirmPasswordField.widthAnchor.constraint(equalTo: formStack.widthAnchor).isActive = true
        
        // Spacer
        let spacer2 = NSView()
        spacer2.translatesAutoresizingMaskIntoConstraints = false
        spacer2.heightAnchor.constraint(equalToConstant: 8).isActive = true
        formStack.addArrangedSubview(spacer2)
        
        // Submit button
        submitButton = NSButton(title: "", target: self, action: #selector(submitForm))
        submitButton.bezelStyle = .rounded
        submitButton.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        submitButton.contentTintColor = .white
        submitButton.wantsLayer = true
        submitButton.layer?.backgroundColor = NSColor.systemBlue.cgColor
        submitButton.layer?.cornerRadius = 11
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        submitButton.heightAnchor.constraint(equalToConstant: 46).isActive = true
        formStack.addArrangedSubview(submitButton)
        submitButton.widthAnchor.constraint(equalTo: formStack.widthAnchor).isActive = true
        
        // Spacer
        let spacer3 = NSView()
        spacer3.translatesAutoresizingMaskIntoConstraints = false
        spacer3.heightAnchor.constraint(equalToConstant: 4).isActive = true
        formStack.addArrangedSubview(spacer3)
        
        // Switch auth button
        switchAuthButton = NSButton(title: "", target: self, action: #selector(switchAuth))
        switchAuthButton.isBordered = false
        switchAuthButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        switchAuthButton.contentTintColor = NSColor.systemBlue
        switchAuthButton.alignment = .center
        switchAuthButton.translatesAutoresizingMaskIntoConstraints = false
        formStack.addArrangedSubview(switchAuthButton)
        switchAuthButton.widthAnchor.constraint(equalTo: formStack.widthAnchor).isActive = true
        
    }
    
    private func updateUI() {
        let isInitial = authState == .initial
        let isSignIn = authState == .signIn
        let isSignUp = authState == .signUp
        let isLoading = authState == .loading
        
        // Show/hide initial buttons
        signInButton.isHidden = !isInitial
        signUpButton.isHidden = !isInitial
        skipButton.isHidden = !isInitial
        
        // Show/hide form
        formContainer.isHidden = isInitial
        
        // Update form content
        if isSignIn {
            titleLabel.stringValue = "Welcome Back"
            subtitleLabel.stringValue = "Sign in to sync your tasks across devices"
            confirmPasswordField.isHidden = true
            submitButton.title = "Sign In"
            switchAuthButton.title = "Don't have an account? Sign Up"
        } else if isSignUp {
            titleLabel.stringValue = "Create Account"
            subtitleLabel.stringValue = "Start organizing your tasks in the cloud"
            confirmPasswordField.isHidden = false
            submitButton.title = "Create Account"
            switchAuthButton.title = "Already have an account? Sign In"
        }
        
        // Loading state
        loadingIndicator.isHidden = !isLoading
        if isLoading {
            loadingIndicator.startAnimation(nil)
        } else {
            loadingIndicator.stopAnimation(nil)
        }
        
        submitButton.isEnabled = !isLoading
        emailField.isEnabled = !isLoading
        passwordField.isEnabled = !isLoading
        confirmPasswordField.isEnabled = !isLoading
        switchAuthButton.isEnabled = !isLoading
        signInButton.isEnabled = !isLoading
        signUpButton.isEnabled = !isLoading
        
        // Focus
        if !isInitial && !isLoading {
            DispatchQueue.main.async { [weak self] in
                self?.emailField.becomeFirstResponder()
            }
        }
    }
    
    @objc private func switchToSignIn() {
        hideError()
        authState = .signIn
    }
    
    @objc private func switchToSignUp() {
        print("🔵 DEBUG: switchToSignUp() called")
        hideError()
        authState = .signUp
    }
    
    @objc private func switchAuth() {
        hideError()
        if authState == .signIn {
            authState = .signUp
        } else {
            authState = .signIn
        }
    }
    
    @objc private func skipAuth() {
        delegate?.authViewControllerDidSkip(self)
    }
    
    @objc private func submitForm() {
        print("🔵 DEBUG: submitForm() called")
        print("🔵 DEBUG: authState = \(authState)")
        print("🔵 DEBUG: email field = '\(emailField.stringValue)'")
        print("🔵 DEBUG: password length = \(passwordField.stringValue.count)")
        print("🔵 DEBUG: delegate = \(String(describing: delegate))")

        guard let email = validateEmail(emailField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            print("❌ DEBUG: Email validation failed")
            showError("Please enter a valid email address")
            return
        }
        print("✅ DEBUG: Email validated: \(email)")

        guard passwordField.stringValue.count >= 6 else {
            print("❌ DEBUG: Password too short")
            showError("Password must be at least 6 characters")
            return
        }
        print("✅ DEBUG: Password length OK")

        if authState == .signUp {
            print("🔵 DEBUG: Checking password confirmation (signUp mode)")
            print("🔵 DEBUG: confirm password length = \(confirmPasswordField.stringValue.count)")
            guard passwordField.stringValue == confirmPasswordField.stringValue else {
                print("❌ DEBUG: Passwords don't match")
                showError("Passwords do not match")
                return
            }
            print("✅ DEBUG: Passwords match")
        }

        hideError()
        let isSignIn = authState == .signIn
        print("🔵 DEBUG: Setting loading state, calling delegate...")
        authState = .loading

        _Concurrency.Task {
            do {
                if isSignIn {
                    print("🔵 DEBUG: Calling delegate signIn...")
                    try await delegate?.authViewController(self, signInWithEmail: email, password: passwordField.stringValue)
                } else {
                    print("🔵 DEBUG: Calling delegate signUp...")
                    try await delegate?.authViewController(self, signUpWithEmail: email, password: passwordField.stringValue)
                }
                print("✅ DEBUG: Auth succeeded, calling didAuthenticate...")
                await MainActor.run {
                    self.delegate?.authViewControllerDidAuthenticate(self)
                }
            } catch {
                print("❌ DEBUG: Auth failed with error: \(error)")
                await MainActor.run {
                    self.showError(error.localizedDescription)
                    self.authState = isSignIn ? .signIn : .signUp
                }
            }
        }
    }
    
    private func validateEmail(_ email: String) -> String? {
        guard !email.isEmpty else { return nil }
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email) ? email : nil
    }
    
    private func showError(_ message: String) {
        print("🔴 DEBUG: showError called with message: '\(message)'")
        errorLabel.stringValue = message
        errorLabel.isHidden = false
    }
    
    private func hideError() {
        errorLabel.stringValue = ""
        errorLabel.isHidden = true
    }
}

// MARK: - Auth Delegate
protocol AuthViewControllerDelegate: AnyObject {
    func authViewController(_ controller: AuthViewController, signInWithEmail email: String, password: String) async throws
    func authViewController(_ controller: AuthViewController, signUpWithEmail email: String, password: String) async throws
    func authViewControllerDidAuthenticate(_ controller: AuthViewController)
    func authViewControllerDidSkip(_ controller: AuthViewController)
}

