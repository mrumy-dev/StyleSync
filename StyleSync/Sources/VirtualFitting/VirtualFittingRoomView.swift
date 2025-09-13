import SwiftUI
import ARKit
import RealityKit

public struct VirtualFittingRoomView: View {
    @StateObject private var fittingRoom = VirtualFittingRoom()
    @StateObject private var visualizationEngine = VisualizationEngine()
    @StateObject private var socialManager = SocialTryOnManager()
    @StateObject private var privacyManager = FittingPrivacyManager()

    @State private var selectedGarment: VirtualGarment?
    @State private var currentStep: FittingStep = .welcome
    @State private var showingPrivacySettings = false
    @State private var showingSizeGuide = false
    @State private var showingSocialOptions = false

    public init() {}

    public var body: some View {
        NavigationView {
            ZStack {
                backgroundView
                mainContentView
            }
            .navigationTitle("Virtual Fitting Room")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    privacyButton
                }
            }
        }
        .sheet(isPresented: $showingPrivacySettings) {
            PrivacySettingsView(manager: privacyManager)
        }
        .sheet(isPresented: $showingSizeGuide) {
            SizeGuideView(garment: selectedGarment)
        }
        .sheet(isPresented: $showingSocialOptions) {
            SocialTryOnView(
                manager: socialManager,
                fittingResult: fittingRoom.fittingResult
            )
        }
        .onAppear {
            setupFittingRoom()
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        GradientMeshBackground(colors: [
            Color.purple.opacity(0.1),
            Color.blue.opacity(0.1),
            Color.pink.opacity(0.05)
        ])
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var mainContentView: some View {
        VStack(spacing: 0) {
            progressIndicator

            switch currentStep {
            case .welcome:
                WelcomeStepView(
                    onNext: { currentStep = .privacyConsent }
                )
            case .privacyConsent:
                PrivacyConsentView(
                    privacyManager: privacyManager,
                    onAccept: { currentStep = .bodyScanning }
                )
            case .bodyScanning:
                BodyScanningView(
                    fittingRoom: fittingRoom,
                    onComplete: { currentStep = .garmentSelection }
                )
            case .garmentSelection:
                GarmentSelectionView(
                    selectedGarment: $selectedGarment,
                    onNext: { currentStep = .virtualTryOn }
                )
            case .virtualTryOn:
                VirtualTryOnView(
                    fittingRoom: fittingRoom,
                    visualizationEngine: visualizationEngine,
                    garment: selectedGarment,
                    onComplete: { currentStep = .results }
                )
            case .results:
                FittingResultsView(
                    fittingResult: fittingRoom.fittingResult,
                    visualizationEngine: visualizationEngine,
                    onSocialShare: { showingSocialOptions = true },
                    onSizeGuide: { showingSizeGuide = true }
                )
            }
        }
    }

    @ViewBuilder
    private var progressIndicator: some View {
        VStack(spacing: 12) {
            HStack {
                ForEach(FittingStep.allCases, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)

                    if step != FittingStep.allCases.last {
                        Rectangle()
                            .fill(step < currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 2)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
            }
            .padding(.horizontal, 40)

            Text(currentStep.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
        .padding(.bottom, 30)
    }

    private var privacyButton: some View {
        Button(action: {
            showingPrivacySettings = true
        }) {
            Image(systemName: "shield.lefthalf.fill")
                .foregroundColor(.blue)
        }
    }

    private func setupFittingRoom() {
        privacyManager.configure(
            localProcessingOnly: true,
            autoDeleteAfter: .hours(24),
            encryptedStorage: true,
            anonymousProcessing: true
        )
    }
}

// MARK: - Welcome Step View

struct WelcomeStepView: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "person.crop.artframe")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("Revolutionary Virtual Fitting")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Experience the future of online shopping with our AI-powered virtual fitting room")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(spacing: 16) {
                FeatureRow(
                    icon: "lidar",
                    title: "3D Body Scanning",
                    description: "LiDAR precision measurement"
                )

                FeatureRow(
                    icon: "brain.head.profile",
                    title: "AI Size Prediction",
                    description: "Machine learning recommendations"
                )

                FeatureRow(
                    icon: "shield.lefthalf.fill",
                    title: "Privacy First",
                    description: "Your data stays on your device"
                )

                FeatureRow(
                    icon: "person.2.fill",
                    title: "Social Try-On",
                    description: "Get feedback from friends"
                )
            }
            .padding(.horizontal, 30)

            Spacer()

            Button(action: onNext) {
                HStack {
                    Text("Get Started")
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Privacy Consent View

struct PrivacyConsentView: View {
    @ObservedObject var privacyManager: FittingPrivacyManager
    let onAccept: () -> Void

    @State private var acceptedTerms = false
    @State private var acceptedPrivacy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "shield.lefthalf.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Privacy & Consent")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Your privacy is our top priority. All processing happens locally on your device.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }

                LazyVStack(spacing: 16) {
                    PrivacyFeatureCard(
                        icon: "iphone",
                        title: "Local Processing Only",
                        description: "Your body measurements never leave your device"
                    )

                    PrivacyFeatureCard(
                        icon: "lock.shield",
                        title: "Encrypted Storage",
                        description: "All data is encrypted with your device's secure enclave"
                    )

                    PrivacyFeatureCard(
                        icon: "clock.arrow.2.circlepath",
                        title: "Auto-Delete",
                        description: "Data automatically deleted after 24 hours"
                    )

                    PrivacyFeatureCard(
                        icon: "person.fill.questionmark",
                        title: "Anonymous Sharing",
                        description: "Social features use anonymous avatars only"
                    )
                }
                .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    Toggle("I agree to the Terms of Service", isOn: $acceptedTerms)
                        .font(.subheadline)

                    Toggle("I consent to the Privacy Policy", isOn: $acceptedPrivacy)
                        .font(.subheadline)
                }
                .padding(.horizontal, 30)

                Button(action: {
                    privacyManager.privacySettings.userConsent = true
                    onAccept()
                }) {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canProceed ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                .disabled(!canProceed)
                .padding(.horizontal, 30)
                .padding(.top, 20)
            }
            .padding(.vertical, 20)
        }
    }

    private var canProceed: Bool {
        acceptedTerms && acceptedPrivacy
    }
}

struct PrivacyFeatureCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Body Scanning View

struct BodyScanningView: View {
    @ObservedObject var fittingRoom: VirtualFittingRoom

    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            if fittingRoom.isScanning {
                ScanningActiveView(
                    progress: fittingRoom.scanProgress,
                    onComplete: onComplete
                )
            } else {
                ScanningReadyView(
                    onStartScan: {
                        Task {
                            try await fittingRoom.startBodyScan()
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ScanningReadyView: View {
    let onStartScan: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "lidar")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("3D Body Scanning")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("We'll use your device's LiDAR sensor to create a precise 3D model of your body for accurate fitting.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(spacing: 16) {
                InstructionStep(
                    number: 1,
                    text: "Stand 3 feet away from your device"
                )

                InstructionStep(
                    number: 2,
                    text: "Face the camera with arms slightly away from body"
                )

                InstructionStep(
                    number: 3,
                    text: "Stay still during the 15-second scan"
                )
            }

            Spacer()

            Button(action: onStartScan) {
                HStack {
                    Text("Start Body Scan")
                        .fontWeight(.semibold)
                    Image(systemName: "play.fill")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.blue)
                .frame(width: 30, height: 30)
                .overlay(
                    Text("\(number)")
                        .font(.headline)
                        .foregroundColor(.white)
                )

            Text(text)
                .font(.body)

            Spacer()
        }
        .padding(.horizontal, 30)
    }
}

struct ScanningActiveView: View {
    let progress: Double
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: progress)

                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                }

                Text("Scanning in Progress...")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("\(Int(progress * 100))% Complete")
                    .font(.headline)
                    .foregroundColor(.blue)

                Text("Please stay still and keep your arms slightly away from your body")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
        .onChange(of: progress) { newProgress in
            if newProgress >= 1.0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onComplete()
                }
            }
        }
    }
}

// MARK: - Fitting Steps

enum FittingStep: CaseIterable {
    case welcome
    case privacyConsent
    case bodyScanning
    case garmentSelection
    case virtualTryOn
    case results

    var description: String {
        switch self {
        case .welcome: return "Welcome"
        case .privacyConsent: return "Privacy"
        case .bodyScanning: return "Body Scan"
        case .garmentSelection: return "Select Garment"
        case .virtualTryOn: return "Virtual Try-On"
        case .results: return "Results"
        }
    }
}

// Additional view components would be implemented here for:
// - GarmentSelectionView
// - VirtualTryOnView
// - FittingResultsView
// - SocialTryOnView
// - PrivacySettingsView
// - SizeGuideView

#Preview {
    VirtualFittingRoomView()
}