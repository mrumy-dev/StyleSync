import SwiftUI
import LocalAuthentication

struct BiometricSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var privacyManager = PrivacyManager.shared
    @Binding var selectedFeature: ProtectedFeature?
    @State private var isAuthenticating = false
    @State private var authenticationError: String?
    @State private var showingError = false

    private var biometricType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        return context.biometryType
    }

    private var biometricIcon: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock"
        }
    }

    private var biometricName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "Biometric Authentication"
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                headerSection
                featureExplanation
                biometricInfo
                actionButtons
                Spacer()
            }
            .padding(.horizontal, 20)
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .alert("Authentication Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(authenticationError ?? "Unable to authenticate")
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }

                Spacer()

                Text("Biometric Protection")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: {}) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.top, 16)

            Image(systemName: biometricIcon)
                .font(.system(size: 64, weight: .light))
                .foregroundColor(.white)
                .padding(.top, 24)
        }
    }

    private var featureExplanation: some View {
        VStack(spacing: 16) {
            if let feature = selectedFeature {
                VStack(spacing: 12) {
                    Text("Protect \(feature.rawValue)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(explanationForFeature(feature))
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .glassCard()
            }
        }
    }

    private var biometricInfo: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.green)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enhanced Security")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Only you can access protected features")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }

                    Spacer()
                }

                HStack(spacing: 16) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quick Access")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Fast authentication with \(biometricName)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }

                    Spacer()
                }

                HStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.purple)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Privacy First")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Biometric data never leaves your device")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }

                    Spacer()
                }
            }
        }
        .glassCard()
    }

    private var actionButtons: some View {
        VStack(spacing: 16) {
            if let feature = selectedFeature {
                if privacyManager.isBiometricProtected(feature) {
                    Button(action: disableBiometricProtection) {
                        HStack {
                            if isAuthenticating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "lock.open.fill")
                                    .font(.system(size: 16, weight: .medium))
                            }

                            Text(isAuthenticating ? "Authenticating..." : "Disable Protection")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.red)
                        )
                    }
                    .disabled(isAuthenticating)
                    .hapticFeedback(.medium, trigger: !isAuthenticating)
                } else {
                    Button(action: enableBiometricProtection) {
                        HStack {
                            if isAuthenticating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: biometricIcon)
                                    .font(.system(size: 16, weight: .medium))
                            }

                            Text(isAuthenticating ? "Authenticating..." : "Enable \(biometricName)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                        )
                    }
                    .disabled(isAuthenticating || biometricType == .none)
                    .hapticFeedback(.medium, trigger: !isAuthenticating && biometricType != .none)
                }
            }

            Button(action: { dismiss() }) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.1))
                    )
            }
            .hapticFeedback(.light, trigger: true)

            if biometricType == .none {
                Text("Biometric authentication is not available on this device.")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func explanationForFeature(_ feature: ProtectedFeature) -> String {
        switch feature {
        case .directMessages:
            return "Require authentication to view and send direct messages. Your conversations will remain private even if someone else has access to your device."
        case .profile:
            return "Protect your profile settings and personal information. Others won't be able to view or modify your profile without authentication."
        case .settings:
            return "Secure your account settings and privacy controls. Prevent unauthorized changes to your StyleSync preferences."
        case .wallet:
            return "Protect your digital wallet and payment information. Ensure secure access to your financial data and transactions."
        case .purchases:
            return "Secure your purchase history and shopping data. Keep your buying habits and preferences private and protected."
        }
    }

    private func enableBiometricProtection() {
        guard let feature = selectedFeature else { return }

        isAuthenticating = true
        authenticationError = nil

        Task {
            do {
                try await privacyManager.enableBiometricProtection(for: feature)

                DispatchQueue.main.async {
                    self.isAuthenticating = false
                    self.dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isAuthenticating = false
                    self.authenticationError = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }

    private func disableBiometricProtection() {
        guard let feature = selectedFeature else { return }

        isAuthenticating = true
        authenticationError = nil

        Task {
            do {
                try await privacyManager.disableBiometricProtection(for: feature)

                DispatchQueue.main.async {
                    self.isAuthenticating = false
                    self.dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isAuthenticating = false
                    self.authenticationError = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
}

#Preview {
    BiometricSetupView(selectedFeature: .constant(.directMessages))
        .preferredColorScheme(.dark)
}