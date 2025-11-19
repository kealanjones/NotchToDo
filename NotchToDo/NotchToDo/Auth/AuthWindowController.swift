import Cocoa
import AuthenticationServices

// MARK: - Auth State
enum AuthState {
    case initial
    case signIn
    case signUp
    case loading
    case oauthLoading
}

// MARK: - Auth Window Controller
final class AuthWindowController: NSWindowController {
    private var authViewController: AuthViewController?

    convenience init() {
        let contentRect = NSRect(x: 0, y: 0, width: 520, height: 720)
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

    // Initial state buttons
    private var signInButton: NSButton!
    private var signUpButton: NSButton!
    private var skipButton: NSButton!

    // Social login buttons
    private var googleSignInButton: NSButton!
    private var appleSignInButton: NSButton!
    private var socialButtonsContainer: NSView!

    // Form fields
    private var emailField: NSTextField!
    private var passwordField: NSSecureTextField!
    private var passwordTextField: NSTextField! // For showing password
    private var confirmPasswordField: NSSecureTextField!
    private var confirmPasswordTextField: NSTextField! // For showing password

    // Form controls
    private var submitButton: NSButton!
    private var switchAuthButton: NSButton!
    private var showPasswordButton: NSButton!
    private var forgotPasswordButton: NSButton!

    // UI state
    private var errorLabel: NSTextField!
    private var loadingIndicator: NSProgressIndicator!
    private var formContainer: NSView!
    private var titleLabel: NSTextField!
    private var subtitleLabel: NSTextField!

    // Password visibility state
    private var isPasswordVisible: Bool = false

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 720))
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
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 50),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -50),
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

        // ===== INITIAL STATE BUTTONS =====
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

        // ===== FORM CONTAINER (SIGN IN/SIGN UP) =====
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
            formContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 400)
        ])

        // Form stack
        let formStack = NSStackView()
        formStack.orientation = .vertical
        formStack.spacing = 14
        formStack.alignment = .leading
        formStack.translatesAutoresizingMaskIntoConstraints = false
        formContainer.addSubview(formStack)
        NSLayoutConstraint.activate([
            formStack.topAnchor.constraint(equalTo: formContainer.topAnchor, constant: 28),
            formStack.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor, constant: 28),
            formStack.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor, constant: -28),
            formStack.bottomAnchor.constraint(lessThanOrEqualTo: formContainer.bottomAnchor, constant: -28)
        ])

        // Title
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .bold)
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
        let spacerTop = NSView()
        spacerTop.translatesAutoresizingMaskIntoConstraints = false
        spacerTop.heightAnchor.constraint(equalToConstant: 8).isActive = true
        formStack.addArrangedSubview(spacerTop)

        // ===== SOCIAL LOGIN BUTTONS =====
        socialButtonsContainer = NSView()
        socialButtonsContainer.translatesAutoresizingMaskIntoConstraints = false
        socialButtonsContainer.heightAnchor.constraint(equalToConstant: 110).isActive = true
        formStack.addArrangedSubview(socialButtonsContainer)
        socialButtonsContainer.widthAnchor.constraint(equalTo: formStack.widthAnchor).isActive = true

        // Google Sign-In button
        googleSignInButton = createSocialButton(
            title: "  Continue with Google",
            symbol: "g.circle.fill",
            backgroundColor: .white,
            textColor: NSColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0),
            borderColor: NSColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1.0),
            action: #selector(signInWithGoogle)
        )
        googleSignInButton.translatesAutoresizingMaskIntoConstraints = false
        socialButtonsContainer.addSubview(googleSignInButton)
        NSLayoutConstraint.activate([
            googleSignInButton.topAnchor.constraint(equalTo: socialButtonsContainer.topAnchor),
            googleSignInButton.leadingAnchor.constraint(equalTo: socialButtonsContainer.leadingAnchor),
            googleSignInButton.trailingAnchor.constraint(equalTo: socialButtonsContainer.trailingAnchor),
            googleSignInButton.heightAnchor.constraint(equalToConstant: 46)
        ])

        // Apple Sign-In button
        appleSignInButton = createSocialButton(
            title: "  Continue with Apple",
            symbol: "applelogo",
            backgroundColor: .black,
            textColor: .white,
            borderColor: .black,
            action: #selector(signInWithApple)
        )
        appleSignInButton.translatesAutoresizingMaskIntoConstraints = false
        socialButtonsContainer.addSubview(appleSignInButton)
        NSLayoutConstraint.activate([
            appleSignInButton.topAnchor.constraint(equalTo: googleSignInButton.bottomAnchor, constant: 12),
            appleSignInButton.leadingAnchor.constraint(equalTo: socialButtonsContainer.leadingAnchor),
            appleSignInButton.trailingAnchor.constraint(equalTo: socialButtonsContainer.trailingAnchor),
            appleSignInButton.heightAnchor.constraint(equalToConstant: 46)
        ])

        // "Or" divider
        let dividerContainer = NSView()
        dividerContainer.translatesAutoresizingMaskIntoConstraints = false
        dividerContainer.heightAnchor.constraint(equalToConstant: 32).isActive = true
        formStack.addArrangedSubview(dividerContainer)
        dividerContainer.widthAnchor.constraint(equalTo: formStack.widthAnchor).isActive = true

        let leftLine = NSBox()
        leftLine.boxType = .separator
        leftLine.translatesAutoresizingMaskIntoConstraints = false
        dividerContainer.addSubview(leftLine)

        let orLabel = NSTextField(labelWithString: "or")
        orLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        orLabel.textColor = NSColor(red: 0.6, green: 0.6, blue: 0.65, alpha: 1.0)
        orLabel.alignment = .center
        orLabel.translatesAutoresizingMaskIntoConstraints = false
        dividerContainer.addSubview(orLabel)

        let rightLine = NSBox()
        rightLine.boxType = .separator
        rightLine.translatesAutoresizingMaskIntoConstraints = false
        dividerContainer.addSubview(rightLine)

        NSLayoutConstraint.activate([
            leftLine.leadingAnchor.constraint(equalTo: dividerContainer.leadingAnchor),
            leftLine.trailingAnchor.constraint(equalTo: orLabel.leadingAnchor, constant: -12),
            leftLine.centerYAnchor.constraint(equalTo: dividerContainer.centerYAnchor),

            orLabel.centerXAnchor.constraint(equalTo: dividerContainer.centerXAnchor),
            orLabel.centerYAnchor.constraint(equalTo: dividerContainer.centerYAnchor),
            orLabel.widthAnchor.constraint(equalToConstant: 30),

            rightLine.leadingAnchor.constraint(equalTo: orLabel.trailingAnchor, constant: 12),
            rightLine.trailingAnchor.constraint(equalTo: dividerContainer.trailingAnchor),
            rightLine.centerYAnchor.constraint(equalTo: dividerContainer.centerYAnchor)
        ])

        // ===== EMAIL/PASSWORD FIELDS =====

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

        // Password field container (to add show/hide button)
        let passwordContainer = NSView()
        passwordContainer.translatesAutoresizingMaskIntoConstraints = false
        passwordContainer.heightAnchor.constraint(equalToConstant: 44).isActive = true
        formStack.addArrangedSubview(passwordContainer)
        passwordContainer.widthAnchor.constraint(equalTo: formStack.widthAnchor).isActive = true

        // Password field (secure)
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
        passwordField.target = self
        passwordField.action = #selector(submitForm)
        passwordContainer.addSubview(passwordField)

        // Password text field (visible)
        passwordTextField = NSTextField()
        passwordTextField.placeholderString = "Password"
        passwordTextField.bezelStyle = .roundedBezel
        passwordTextField.isBordered = true
        passwordTextField.font = NSFont.systemFont(ofSize: 14)
        passwordTextField.wantsLayer = true
        passwordTextField.layer?.cornerRadius = 10
        passwordTextField.layer?.borderWidth = 1
        passwordTextField.layer?.borderColor = NSColor(red: 0.88, green: 0.88, blue: 0.90, alpha: 1.0).cgColor
        passwordTextField.translatesAutoresizingMaskIntoConstraints = false
        passwordTextField.isHidden = true
        passwordTextField.target = self
        passwordTextField.action = #selector(submitForm)
        passwordContainer.addSubview(passwordTextField)

        // Show/hide password button
        showPasswordButton = NSButton(image: NSImage(systemSymbolName: "eye", accessibilityDescription: "Show password")!, target: self, action: #selector(togglePasswordVisibility))
        showPasswordButton.isBordered = false
        showPasswordButton.bezelStyle = .regularSquare
        showPasswordButton.contentTintColor = NSColor(red: 0.6, green: 0.6, blue: 0.65, alpha: 1.0)
        showPasswordButton.translatesAutoresizingMaskIntoConstraints = false
        passwordContainer.addSubview(showPasswordButton)

        NSLayoutConstraint.activate([
            passwordField.leadingAnchor.constraint(equalTo: passwordContainer.leadingAnchor),
            passwordField.trailingAnchor.constraint(equalTo: showPasswordButton.leadingAnchor, constant: -4),
            passwordField.topAnchor.constraint(equalTo: passwordContainer.topAnchor),
            passwordField.bottomAnchor.constraint(equalTo: passwordContainer.bottomAnchor),

            passwordTextField.leadingAnchor.constraint(equalTo: passwordContainer.leadingAnchor),
            passwordTextField.trailingAnchor.constraint(equalTo: showPasswordButton.leadingAnchor, constant: -4),
            passwordTextField.topAnchor.constraint(equalTo: passwordContainer.topAnchor),
            passwordTextField.bottomAnchor.constraint(equalTo: passwordContainer.bottomAnchor),

            showPasswordButton.trailingAnchor.constraint(equalTo: passwordContainer.trailingAnchor, constant: -8),
            showPasswordButton.centerYAnchor.constraint(equalTo: passwordContainer.centerYAnchor),
            showPasswordButton.widthAnchor.constraint(equalToConstant: 32),
            showPasswordButton.heightAnchor.constraint(equalToConstant: 32)
        ])

        // Confirm password field (for sign up) - similar structure
        let confirmPasswordContainer = NSView()
        confirmPasswordContainer.translatesAutoresizingMaskIntoConstraints = false
        confirmPasswordContainer.heightAnchor.constraint(equalToConstant: 44).isActive = true
        confirmPasswordContainer.isHidden = true
        formStack.addArrangedSubview(confirmPasswordContainer)
        confirmPasswordContainer.widthAnchor.constraint(equalTo: formStack.widthAnchor).isActive = true

        confirmPasswordField = NSSecureTextField()
        confirmPasswordField.placeholderString = "Confirm password"
        confirmPasswordField.bezelStyle = .roundedBezel
        confirmPasswordField.isBordered = true
        confirmPasswordField.font = NSFont.systemFont(ofSize: 14)
        confirmPasswordField.wantsLayer = true
        confirmPasswordField.layer?.cornerRadius = 10
        confirmPasswordField.layer?.borderWidth = 1
        confirmPasswordField.layer?.borderColor = NSColor(red: 0.88, green: 0.88, blue: 0.90, alpha: 1.0).cgColor
        confirmPasswordField.translatesAutoresizingMaskIntoConstraints = false
        confirmPasswordField.target = self
        confirmPasswordField.action = #selector(submitForm)
        confirmPasswordContainer.addSubview(confirmPasswordField)

        confirmPasswordTextField = NSTextField()
        confirmPasswordTextField.placeholderString = "Confirm password"
        confirmPasswordTextField.bezelStyle = .roundedBezel
        confirmPasswordTextField.isBordered = true
        confirmPasswordTextField.font = NSFont.systemFont(ofSize: 14)
        confirmPasswordTextField.wantsLayer = true
        confirmPasswordTextField.layer?.cornerRadius = 10
        confirmPasswordTextField.layer?.borderWidth = 1
        confirmPasswordTextField.layer?.borderColor = NSColor(red: 0.88, green: 0.88, blue: 0.90, alpha: 1.0).cgColor
        confirmPasswordTextField.translatesAutoresizingMaskIntoConstraints = false
        confirmPasswordTextField.isHidden = true
        confirmPasswordTextField.target = self
        confirmPasswordTextField.action = #selector(submitForm)
        confirmPasswordContainer.addSubview(confirmPasswordTextField)

        NSLayoutConstraint.activate([
            confirmPasswordField.leadingAnchor.constraint(equalTo: confirmPasswordContainer.leadingAnchor),
            confirmPasswordField.trailingAnchor.constraint(equalTo: confirmPasswordContainer.trailingAnchor),
            confirmPasswordField.topAnchor.constraint(equalTo: confirmPasswordContainer.topAnchor),
            confirmPasswordField.bottomAnchor.constraint(equalTo: confirmPasswordContainer.bottomAnchor),

            confirmPasswordTextField.leadingAnchor.constraint(equalTo: confirmPasswordContainer.leadingAnchor),
            confirmPasswordTextField.trailingAnchor.constraint(equalTo: confirmPasswordContainer.trailingAnchor),
            confirmPasswordTextField.topAnchor.constraint(equalTo: confirmPasswordContainer.topAnchor),
            confirmPasswordTextField.bottomAnchor.constraint(equalTo: confirmPasswordContainer.bottomAnchor)
        ])

        // Forgot password button
        forgotPasswordButton = NSButton(title: "Forgot password?", target: self, action: #selector(forgotPassword))
        forgotPasswordButton.isBordered = false
        forgotPasswordButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        forgotPasswordButton.contentTintColor = NSColor.systemBlue
        forgotPasswordButton.alignment = .right
        forgotPasswordButton.translatesAutoresizingMaskIntoConstraints = false
        formStack.addArrangedSubview(forgotPasswordButton)
        forgotPasswordButton.widthAnchor.constraint(equalTo: formStack.widthAnchor).isActive = true

        // Spacer before submit button
        let spacerMiddle = NSView()
        spacerMiddle.translatesAutoresizingMaskIntoConstraints = false
        spacerMiddle.heightAnchor.constraint(equalToConstant: 8).isActive = true
        formStack.addArrangedSubview(spacerMiddle)

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

        // Switch auth button
        switchAuthButton = NSButton(title: "", target: self, action: #selector(switchAuth))
        switchAuthButton.isBordered = false
        switchAuthButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        switchAuthButton.contentTintColor = NSColor.systemBlue
        switchAuthButton.alignment = .center
        switchAuthButton.translatesAutoresizingMaskIntoConstraints = false
        formStack.addArrangedSubview(switchAuthButton)
        switchAuthButton.widthAnchor.constraint(equalTo: formStack.widthAnchor).isActive = true

        // ===== ERROR LABEL & LOADING =====
        errorLabel = NSTextField(labelWithString: "")
        errorLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        errorLabel.textColor = NSColor.systemRed
        errorLabel.alignment = .center
        errorLabel.isHidden = true
        errorLabel.maximumNumberOfLines = 3
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
    }

    private func createSocialButton(title: String, symbol: String, backgroundColor: NSColor, textColor: NSColor, borderColor: NSColor, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        button.contentTintColor = textColor
        button.alignment = .center
        button.wantsLayer = true
        button.layer?.backgroundColor = backgroundColor.cgColor
        button.layer?.cornerRadius = 11
        button.layer?.borderWidth = 1.5
        button.layer?.borderColor = borderColor.cgColor

        // Add icon
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            button.image = image
            button.imagePosition = .imageLeading
            button.imageHugsTitle = true
        }

        return button
    }

    private func updateUI() {
        let isInitial = authState == .initial
        let isSignIn = authState == .signIn
        let isSignUp = authState == .signUp
        let isLoading = authState == .loading || authState == .oauthLoading

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
            passwordField.superview?.isHidden = false
            confirmPasswordField.superview?.isHidden = true
            forgotPasswordButton.isHidden = false
            submitButton.title = "Sign In"
            switchAuthButton.title = "Don't have an account? Sign Up"
        } else if isSignUp {
            titleLabel.stringValue = "Create Account"
            subtitleLabel.stringValue = "Start organizing your tasks in the cloud"
            passwordField.superview?.isHidden = false
            confirmPasswordField.superview?.isHidden = false
            forgotPasswordButton.isHidden = true
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

        // Disable controls during loading
        submitButton.isEnabled = !isLoading
        emailField.isEnabled = !isLoading
        passwordField.isEnabled = !isLoading
        passwordTextField.isEnabled = !isLoading
        confirmPasswordField.isEnabled = !isLoading
        confirmPasswordTextField.isEnabled = !isLoading
        switchAuthButton.isEnabled = !isLoading
        signInButton.isEnabled = !isLoading
        signUpButton.isEnabled = !isLoading
        googleSignInButton.isEnabled = !isLoading
        appleSignInButton.isEnabled = !isLoading

        // Focus
        if !isInitial && !isLoading {
            DispatchQueue.main.async { [weak self] in
                self?.emailField.becomeFirstResponder()
            }
        }
    }

    // MARK: - Actions

    @objc private func switchToSignIn() {
        hideError()
        authState = .signIn
    }

    @objc private func switchToSignUp() {
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

    @objc private func togglePasswordVisibility() {
        isPasswordVisible.toggle()

        if isPasswordVisible {
            // Show password
            passwordTextField.stringValue = passwordField.stringValue
            confirmPasswordTextField.stringValue = confirmPasswordField.stringValue
            passwordField.isHidden = true
            passwordTextField.isHidden = false
            confirmPasswordField.isHidden = true
            confirmPasswordTextField.isHidden = false
            showPasswordButton.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "Hide password")
        } else {
            // Hide password
            passwordField.stringValue = passwordTextField.stringValue
            confirmPasswordField.stringValue = confirmPasswordTextField.stringValue
            passwordField.isHidden = false
            passwordTextField.isHidden = true
            confirmPasswordField.isHidden = false
            confirmPasswordTextField.isHidden = true
            showPasswordButton.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Show password")
        }
    }

    @objc private func forgotPassword() {
        let alert = NSAlert()
        alert.messageText = "Reset Password"
        alert.informativeText = "Enter your email address and we'll send you a password reset link."
        alert.alertStyle = .informational

        let emailField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        emailField.placeholderString = "your@email.com"
        alert.accessoryView = emailField
        alert.addButton(withTitle: "Send Reset Link")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let email = emailField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !email.isEmpty else { return }

            // TODO: Implement password reset with Supabase
            DebugLog.log("Password reset requested for: \(email)", category: .sync)
            showError("Password reset feature coming soon!")
        }
    }

    @objc private func signInWithGoogle() {
        DebugLog.log("Google Sign-In initiated", category: .sync)
        hideError()
        authState = .oauthLoading

        guard let authManager = (NSApp.delegate as? AppDelegate)?.supabaseAuthManager else {
            showError("Authentication not available")
            authState = .initial
            return
        }

        let success = authManager.signInWithOAuth(provider: .google)
        if !success {
            showError("Failed to start Google Sign-In")
            authState = .initial
        } else {
            // Show loading message
            showError("Opening Google Sign-In in your browser...")
            errorLabel.textColor = NSColor.systemBlue

            // OAuth window is now open - the callback will be handled by AppDelegate
            // We'll close this window when the callback succeeds
        }
    }

    @objc private func signInWithApple() {
        DebugLog.log("Apple Sign-In initiated", category: .sync)
        hideError()
        authState = .oauthLoading

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    @objc private func submitForm() {
        DebugLog.log("Auth form submitted", category: .sync)

        // Get the actual password value (from visible or hidden field)
        let passwordValue = isPasswordVisible ? passwordTextField.stringValue : passwordField.stringValue
        let confirmPasswordValue = isPasswordVisible ? confirmPasswordTextField.stringValue : confirmPasswordField.stringValue

        // Validate email
        let email: String
        do {
            email = try InputValidator.validateEmail(emailField.stringValue)
        } catch {
            showError(error.localizedDescription)
            return
        }

        // Validate password
        let password: String
        do {
            if authState == .signUp {
                password = try InputValidator.validatePassword(passwordValue)
            } else {
                if passwordValue.count < 6 {
                    throw InputValidator.ValidationError.tooShort(field: "Password", minimum: 6)
                }
                password = passwordValue
            }
        } catch {
            showError(error.localizedDescription)
            return
        }

        // Check password confirmation for sign up
        if authState == .signUp {
            guard passwordValue == confirmPasswordValue else {
                showError("Passwords do not match")
                return
            }
        }

        hideError()
        let isSignIn = authState == .signIn
        authState = .loading

        _Concurrency.Task {
            do {
                if isSignIn {
                    try await delegate?.authViewController(self, signInWithEmail: email, password: password)
                } else {
                    try await delegate?.authViewController(self, signUpWithEmail: email, password: password)
                }
                await MainActor.run {
                    self.delegate?.authViewControllerDidAuthenticate(self)
                }
            } catch {
                await MainActor.run {
                    self.showError(error.localizedDescription)
                    self.authState = isSignIn ? .signIn : .signUp
                }
            }
        }
    }

    private func showError(_ message: String) {
        errorLabel.stringValue = message
        errorLabel.textColor = NSColor.systemRed
        errorLabel.isHidden = false
    }

    private func hideError() {
        errorLabel.stringValue = ""
        errorLabel.isHidden = true
    }
}

// MARK: - Apple Sign-In Delegate

extension AuthViewController: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return view.window!
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            showError("Apple Sign-In failed: Invalid credential")
            authState = .initial
            return
        }

        guard let identityToken = credential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            showError("Apple Sign-In failed: No identity token")
            authState = .initial
            return
        }

        DebugLog.log("Apple Sign-In succeeded, exchanging token with Supabase", category: .sync)

        // TODO: Exchange Apple ID token with Supabase using signInWithIdToken API
        // For now, show a message
        showError("Apple Sign-In integration coming soon!")
        authState = .initial

        // Store user info if available
        if let email = credential.email {
            DebugLog.log("Apple user email: \(email)", category: .sync)
        }
        if let fullName = credential.fullName {
            DebugLog.log("Apple user name: \(fullName.givenName ?? "") \(fullName.familyName ?? "")", category: .sync)
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        DebugLog.log("Apple Sign-In error: \(error.localizedDescription)", category: .sync)

        let nsError = error as NSError
        if nsError.code == 1001 { // User canceled
            authState = .initial
            return
        }

        showError("Apple Sign-In failed: \(error.localizedDescription)")
        authState = .initial
    }
}

// MARK: - Auth Delegate Protocol

protocol AuthViewControllerDelegate: AnyObject {
    func authViewController(_ controller: AuthViewController, signInWithEmail email: String, password: String) async throws
    func authViewController(_ controller: AuthViewController, signUpWithEmail email: String, password: String) async throws
    func authViewControllerDidAuthenticate(_ controller: AuthViewController)
    func authViewControllerDidSkip(_ controller: AuthViewController)
}
