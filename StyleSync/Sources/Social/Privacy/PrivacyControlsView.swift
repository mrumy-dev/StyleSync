import SwiftUI

struct PrivacyControlsView: View {
    @StateObject private var privacyManager = PrivacyManager.shared
    @StateObject private var hapticManager = HapticManager.shared
    @State private var showingBiometricSetup = false
    @State private var selectedProtectedFeature: ProtectedFeature?
    @State private var showingReportInterface = false
    @State private var showingDataManagement = false

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    accountPrivacySection
                    interactionControlsSection
                    contentFilteringSection
                    biometricProtectionSection
                    dataManagementSection
                    safetyToolsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color.black)
            .navigationTitle("Privacy & Safety")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingBiometricSetup) {
            BiometricSetupView(selectedFeature: $selectedProtectedFeature)
        }
        .sheet(isPresented: $showingReportInterface) {
            ReportingInterfaceView()
        }
        .sheet(isPresented: $showingDataManagement) {
            DataManagementView()
        }
    }

    private var accountPrivacySection: some View {
        VStack(spacing: 16) {
            SectionHeader(
                title: "Account Privacy",
                icon: "lock.shield",
                description: "Control who can see your profile and content"
            )

            VStack(spacing: 12) {
                PrivacyToggle(
                    title: "Private Account",
                    description: "Only approved followers can see your posts",
                    isOn: $privacyManager.isPrivateAccount
                ) {
                    privacyManager.setAccountPrivacy($0)
                }

                PrivacyToggle(
                    title: "Hide Like Counts",
                    description: "Like counts will only be visible to you",
                    isOn: $privacyManager.hideLikeCounts
                ) { _ in
                    privacyManager.toggleHideLikeCounts()
                }

                PrivacyToggle(
                    title: "Hide Activity Status",
                    description: "Others won't see when you're online",
                    isOn: $privacyManager.hideActivityStatus
                ) { _ in
                    privacyManager.toggleActivityStatus()
                }

                PrivacyToggle(
                    title: "Allow Screenshots",
                    description: "Enable screenshots in direct messages",
                    isOn: $privacyManager.allowScreenshots
                ) { _ in
                    privacyManager.toggleScreenshotPermissions()
                }
            }
        }
        .glassCard()
    }

    private var interactionControlsSection: some View {
        VStack(spacing: 16) {
            SectionHeader(
                title: "Interaction Controls",
                icon: "person.2.circle",
                description: "Manage how others can interact with you"
            )

            VStack(spacing: 12) {
                PrivacySelector(
                    title: "Who can message you",
                    selectedOption: privacyManager.privacySettings.whoCanMessage.rawValue,
                    options: MessagePermission.allCases.map { $0.rawValue }
                ) { selected in
                    if let permission = MessagePermission(rawValue: selected) {
                        privacyManager.privacySettings.whoCanMessage = permission
                    }
                }

                PrivacySelector(
                    title: "Who can see your profile",
                    selectedOption: privacyManager.privacySettings.whoCanSeeProfile.rawValue,
                    options: ProfileVisibility.allCases.map { $0.rawValue }
                ) { selected in
                    if let visibility = ProfileVisibility(rawValue: selected) {
                        privacyManager.privacySettings.whoCanSeeProfile = visibility
                    }
                }

                PrivacySelector(
                    title: "Who can tag you",
                    selectedOption: privacyManager.privacySettings.whoCanTagYou.rawValue,
                    options: TagPermission.allCases.map { $0.rawValue }
                ) { selected in
                    if let permission = TagPermission(rawValue: selected) {
                        privacyManager.privacySettings.whoCanTagYou = permission
                    }
                }
            }
        }
        .glassCard()
    }

    private var contentFilteringSection: some View {
        VStack(spacing: 16) {
            SectionHeader(
                title: "Content Filtering",
                icon: "eye.slash",
                description: "Control what content you see"
            )

            VStack(spacing: 12) {
                PrivacySelector(
                    title: "Safety Mode",
                    selectedOption: privacyManager.safetyMode.rawValue,
                    options: SafetyMode.allCases.map { $0.rawValue }
                ) { selected in
                    if let mode = SafetyMode(rawValue: selected) {
                        privacyManager.setSafetyMode(mode)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Content Filters")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    VStack(spacing: 8) {
                        FilterToggle(
                            title: "Adult Content",
                            isOn: $privacyManager.contentFilters.filterAdultContent
                        )

                        FilterToggle(
                            title: "Violence",
                            isOn: $privacyManager.contentFilters.filterViolence
                        )

                        FilterToggle(
                            title: "Profanity",
                            isOn: $privacyManager.contentFilters.filterProfanity
                        )

                        FilterToggle(
                            title: "Sensitive Topics",
                            isOn: $privacyManager.contentFilters.filterSensitiveTopics
                        )

                        FilterToggle(
                            title: "Require Content Warnings",
                            isOn: $privacyManager.contentFilters.requireContentWarnings
                        )
                    }
                }
            }
        }
        .glassCard()
    }

    private var biometricProtectionSection: some View {
        VStack(spacing: 16) {
            SectionHeader(
                title: "Biometric Protection",
                icon: "faceid",
                description: "Secure sensitive features with biometric authentication"
            )

            VStack(spacing: 12) {
                ForEach(ProtectedFeature.allCases, id: \.self) { feature in
                    BiometricProtectionRow(
                        feature: feature,
                        isProtected: privacyManager.isBiometricProtected(feature)
                    ) {
                        selectedProtectedFeature = feature
                        showingBiometricSetup = true
                    }
                }
            }
        }
        .glassCard()
    }

    private var dataManagementSection: some View {
        VStack(spacing: 16) {
            SectionHeader(
                title: "Data Management",
                icon: "externaldrive",
                description: "Control your data and privacy preferences"
            )

            VStack(spacing: 12) {
                ActionButton(
                    title: "Manage Data Retention",
                    description: "Set automatic data deletion policies",
                    icon: "clock.arrow.circlepath",
                    action: {
                        showingDataManagement = true
                    }
                )

                PrivacyToggle(
                    title: "Auto-Delete Media",
                    description: "Automatically delete old photos and videos",
                    isOn: $privacyManager.privacySettings.autoDeleteMedia
                ) { isOn in
                    privacyManager.privacySettings.autoDeleteMedia = isOn
                }

                PrivacyToggle(
                    title: "Allow Data Collection",
                    description: "Help improve StyleSync with anonymous analytics",
                    isOn: $privacyManager.privacySettings.allowDataCollection
                ) { isOn in
                    privacyManager.privacySettings.allowDataCollection = isOn
                }

                PrivacyToggle(
                    title: "Personalized Ads",
                    description: "Show ads based on your interests",
                    isOn: $privacyManager.privacySettings.allowPersonalizedAds
                ) { isOn in
                    privacyManager.privacySettings.allowPersonalizedAds = isOn
                }
            }
        }
        .glassCard()
    }

    private var safetyToolsSection: some View {
        VStack(spacing: 16) {
            SectionHeader(
                title: "Safety Tools",
                icon: "shield.checkered",
                description: "Report content and manage blocked users"
            )

            VStack(spacing: 12) {
                ActionButton(
                    title: "Report Content or Users",
                    description: "Report inappropriate content or behavior",
                    icon: "exclamationmark.triangle",
                    action: {
                        showingReportInterface = true
                    }
                )

                NavigationLink(destination: BlockedUsersView()) {
                    ActionButton(
                        title: "Blocked Users",
                        description: "Manage your blocked and restricted users",
                        icon: "person.crop.circle.badge.minus",
                        action: {}
                    )
                }

                NavigationLink(destination: SafetyResourcesView()) {
                    ActionButton(
                        title: "Safety Resources",
                        description: "Learn about digital wellbeing and safety",
                        icon: "heart.circle",
                        action: {}
                    )
                }
            }
        }
        .glassCard()
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }

            Text(description)
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
    }
}

struct PrivacyToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .white))
                .onChange(of: isOn) { newValue in
                    onToggle(newValue)
                }
        }
        .padding(.vertical, 8)
    }
}

struct PrivacySelector: View {
    let title: String
    let selectedOption: String
    let options: [String]
    let onSelection: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        onSelection(option)
                        HapticManager.shared.impact(.light)
                    }
                }
            } label: {
                HStack {
                    Text(selectedOption)
                        .font(.system(size: 14))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
            }
        }
    }
}

struct FilterToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white)

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .white))
                .scaleEffect(0.8)
        }
        .padding(.vertical, 4)
    }
}

struct BiometricProtectionRow: View {
    let feature: ProtectedFeature
    let isProtected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: isProtected ? "faceid" : "faceid")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isProtected ? .green : .gray)

            Text(feature.rawValue)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            Button(action: onToggle) {
                Text(isProtected ? "Enabled" : "Enable")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isProtected ? .green : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(isProtected ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
                    )
            }
            .hapticFeedback(.light, trigger: true)
        }
        .padding(.vertical, 8)
    }
}

struct ActionButton: View {
    let title: String
    let description: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)

                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 12)
        }
        .hapticFeedback(.light, trigger: true)
    }
}

#Preview {
    PrivacyControlsView()
        .preferredColorScheme(.dark)
}