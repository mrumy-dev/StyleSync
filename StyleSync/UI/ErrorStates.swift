import SwiftUI

struct ErrorStateView: View {
    let errorType: ErrorType
    let title: String?
    let message: String?
    let primaryAction: ErrorAction?
    let secondaryAction: ErrorAction?

    init(
        errorType: ErrorType,
        title: String? = nil,
        message: String? = nil,
        primaryAction: ErrorAction? = nil,
        secondaryAction: ErrorAction? = nil
    ) {
        self.errorType = errorType
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }

    var body: some View {
        VStack(spacing: 24) {
            ErrorIllustration(type: errorType)
                .frame(width: 200, height: 160)

            VStack(spacing: 12) {
                Text(title ?? errorType.defaultTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)

                Text(message ?? errorType.defaultMessage)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                if let primary = primaryAction {
                    Button(action: primary.action) {
                        HStack {
                            if let icon = primary.icon {
                                Image(systemName: icon)
                                    .font(.body.weight(.medium))
                            }
                            Text(primary.title)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.blue.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                if let secondary = secondaryAction {
                    Button(action: secondary.action) {
                        HStack {
                            if let icon = secondary.icon {
                                Image(systemName: icon)
                                    .font(.body.weight(.medium))
                            }
                            Text(secondary.title)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, 32)
        }
        .padding()
    }
}

enum ErrorType {
    case networkConnection
    case serverError
    case notFound
    case permissionDenied
    case outOfSync
    case rateLimit
    case maintenance
    case cameraAccess
    case photoLibraryAccess
    case locationAccess
    case microphoneAccess
    case general

    var defaultTitle: String {
        switch self {
        case .networkConnection:
            return "No Internet Connection"
        case .serverError:
            return "Something Went Wrong"
        case .notFound:
            return "Not Found"
        case .permissionDenied:
            return "Permission Required"
        case .outOfSync:
            return "Sync Issue"
        case .rateLimit:
            return "Too Many Requests"
        case .maintenance:
            return "Under Maintenance"
        case .cameraAccess:
            return "Camera Access Needed"
        case .photoLibraryAccess:
            return "Photo Access Needed"
        case .locationAccess:
            return "Location Access Needed"
        case .microphoneAccess:
            return "Microphone Access Needed"
        case .general:
            return "Oops!"
        }
    }

    var defaultMessage: String {
        switch self {
        case .networkConnection:
            return "Please check your internet connection and try again."
        case .serverError:
            return "We're experiencing technical difficulties. Please try again later."
        case .notFound:
            return "The item you're looking for couldn't be found."
        case .permissionDenied:
            return "This feature requires permission to work properly."
        case .outOfSync:
            return "Your data is out of sync. Let's refresh to get the latest updates."
        case .rateLimit:
            return "You've made too many requests. Please wait a moment and try again."
        case .maintenance:
            return "We're making improvements to StyleSync. We'll be back soon!"
        case .cameraAccess:
            return "Allow camera access to capture your outfits and get personalized style recommendations."
        case .photoLibraryAccess:
            return "Allow photo access to save your favorite looks and build your digital wardrobe."
        case .locationAccess:
            return "Enable location access for weather-based outfit suggestions and local style trends."
        case .microphoneAccess:
            return "Allow microphone access to use voice commands like 'Rate my outfit' and 'What should I wear?'"
        case .general:
            return "Something unexpected happened. Please try again."
        }
    }

    var primaryColor: Color {
        switch self {
        case .networkConnection:
            return .orange
        case .serverError:
            return .red
        case .notFound:
            return .purple
        case .permissionDenied, .cameraAccess, .photoLibraryAccess, .locationAccess, .microphoneAccess:
            return .blue
        case .outOfSync:
            return .green
        case .rateLimit:
            return .yellow
        case .maintenance:
            return .gray
        case .general:
            return .blue
        }
    }

    var illustration: String {
        switch self {
        case .networkConnection:
            return "wifi.slash"
        case .serverError:
            return "exclamationmark.triangle"
        case .notFound:
            return "magnifyingglass"
        case .permissionDenied:
            return "hand.raised"
        case .outOfSync:
            return "arrow.triangle.2.circlepath"
        case .rateLimit:
            return "clock"
        case .maintenance:
            return "wrench.and.screwdriver"
        case .cameraAccess:
            return "camera"
        case .photoLibraryAccess:
            return "photo"
        case .locationAccess:
            return "location"
        case .microphoneAccess:
            return "mic"
        case .general:
            return "exclamationmark.circle"
        }
    }
}

struct ErrorAction {
    let title: String
    let icon: String?
    let action: () -> Void

    init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
}

struct ErrorIllustration: View {
    let type: ErrorType

    @State private var animationOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            type.primaryColor.opacity(0.1),
                            type.primaryColor.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(pulseScale)

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(type.primaryColor.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .scaleEffect(pulseScale)

                    Image(systemName: type.illustration)
                        .font(.largeTitle)
                        .foregroundColor(type.primaryColor)
                        .rotationEffect(.degrees(rotation))
                        .offset(y: animationOffset)
                }

                decorativeElements
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    @ViewBuilder
    private var decorativeElements: some View {
        switch type {
        case .networkConnection:
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(type.primaryColor.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: pulseScale
                        )
                }
            }

        case .serverError:
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(type.primaryColor.opacity(0.4))
                        .frame(width: 3, height: CGFloat.random(in: 8...16))
                        .animation(
                            .easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1),
                            value: animationOffset
                        )
                }
            }

        case .maintenance:
            HStack(spacing: 6) {
                Image(systemName: "gear")
                    .foregroundColor(type.primaryColor.opacity(0.6))
                    .rotationEffect(.degrees(rotation * 0.5))

                Image(systemName: "gear")
                    .foregroundColor(type.primaryColor.opacity(0.4))
                    .rotationEffect(.degrees(-rotation * 0.3))
                    .scaleEffect(0.7)
            }

        default:
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(type.primaryColor.opacity(0.2))
                        .frame(width: 4, height: 4)
                }
            }
        }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            animationOffset = -5
        }

        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.05
        }

        if type == .maintenance {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

struct NetworkErrorView: View {
    let onRetry: () -> Void

    var body: some View {
        ErrorStateView(
            errorType: .networkConnection,
            primaryAction: ErrorAction(
                title: "Try Again",
                icon: "arrow.clockwise",
                action: onRetry
            ),
            secondaryAction: ErrorAction(
                title: "Check Settings",
                icon: "gear",
                action: {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
            )
        )
    }
}

struct PermissionErrorView: View {
    let permissionType: ErrorType
    let onGrantPermission: () -> Void
    let onSkip: (() -> Void)?

    init(
        permissionType: ErrorType,
        onGrantPermission: @escaping () -> Void,
        onSkip: (() -> Void)? = nil
    ) {
        self.permissionType = permissionType
        self.onGrantPermission = onGrantPermission
        self.onSkip = onSkip
    }

    var body: some View {
        ErrorStateView(
            errorType: permissionType,
            primaryAction: ErrorAction(
                title: "Grant Permission",
                icon: "checkmark.circle",
                action: onGrantPermission
            ),
            secondaryAction: onSkip != nil ? ErrorAction(
                title: "Skip for Now",
                action: onSkip!
            ) : nil
        )
    }
}

struct MaintenanceView: View {
    let estimatedDowntime: String?

    var body: some View {
        ErrorStateView(
            errorType: .maintenance,
            message: estimatedDowntime != nil
                ? "We're making improvements to StyleSync. Estimated completion: \(estimatedDowntime!)"
                : nil,
            secondaryAction: ErrorAction(
                title: "Check Status",
                icon: "info.circle",
                action: {

                }
            )
        )
    }
}

struct RateLimitView: View {
    let resetTime: Date
    let onWait: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ErrorStateView(
                errorType: .rateLimit,
                message: "You can try again in \(timeUntilReset)",
                primaryAction: ErrorAction(
                    title: "Wait & Retry",
                    icon: "clock",
                    action: onWait
                )
            )

            CountdownTimer(targetDate: resetTime)
        }
    }

    private var timeUntilReset: String {
        let interval = resetTime.timeIntervalSinceNow
        let minutes = Int(interval / 60)
        let seconds = Int(interval.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct CountdownTimer: View {
    let targetDate: Date
    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .foregroundColor(.orange)

            Text(timeString)
                .font(.monospaced(.body)())
                .fontWeight(.medium)
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.orange.opacity(0.1))
        .clipShape(Capsule())
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private var timeString: String {
        let minutes = Int(timeRemaining / 60)
        let seconds = Int(timeRemaining.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func startTimer() {
        updateTimeRemaining()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateTimeRemaining()
        }
    }

    private func updateTimeRemaining() {
        timeRemaining = max(0, targetDate.timeIntervalSinceNow)
        if timeRemaining <= 0 {
            timer?.invalidate()
        }
    }
}

struct ErrorHandler {
    static func handle(_ error: Error) -> ErrorType {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkConnection
            case .timedOut:
                return .serverError
            default:
                return .general
            }
        }

        return .general
    }

    static func createErrorView(for error: Error, onRetry: @escaping () -> Void) -> some View {
        let errorType = handle(error)

        switch errorType {
        case .networkConnection:
            return AnyView(NetworkErrorView(onRetry: onRetry))
        default:
            return AnyView(
                ErrorStateView(
                    errorType: errorType,
                    primaryAction: ErrorAction(
                        title: "Try Again",
                        icon: "arrow.clockwise",
                        action: onRetry
                    )
                )
            )
        }
    }
}

struct ErrorStateShowcase: View {
    @State private var selectedError = 0

    private let errorTypes: [ErrorType] = [
        .networkConnection,
        .serverError,
        .notFound,
        .permissionDenied,
        .cameraAccess,
        .maintenance,
        .rateLimit
    ]

    var body: some View {
        VStack(spacing: 20) {
            Picker("Error Type", selection: $selectedError) {
                ForEach(0..<errorTypes.count, id: \.self) { index in
                    Text(errorTypes[index].defaultTitle).tag(index)
                }
            }
            .pickerStyle(MenuPickerStyle())

            ScrollView {
                Group {
                    switch errorTypes[selectedError] {
                    case .networkConnection:
                        NetworkErrorView(onRetry: {})

                    case .cameraAccess:
                        PermissionErrorView(
                            permissionType: .cameraAccess,
                            onGrantPermission: {},
                            onSkip: {}
                        )

                    case .maintenance:
                        MaintenanceView(estimatedDowntime: "30 minutes")

                    case .rateLimit:
                        RateLimitView(
                            resetTime: Date().addingTimeInterval(300),
                            onWait: {}
                        )

                    default:
                        ErrorStateView(
                            errorType: errorTypes[selectedError],
                            primaryAction: ErrorAction(title: "Try Again", action: {}),
                            secondaryAction: ErrorAction(title: "Get Help", action: {})
                        )
                    }
                }
            }
        }
        .padding()
    }
}