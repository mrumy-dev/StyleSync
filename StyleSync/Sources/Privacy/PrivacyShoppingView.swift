import SwiftUI

struct PrivacyShoppingView: View {
    @StateObject private var viewModel = PrivacyShoppingViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var privacyManager: PrivacyControlsManager
    @State private var showDataExport = false
    @State private var showDataDeletion = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background with gradient mesh
                GradientMeshBackground(colors: themeManager.currentTheme.gradients.mesh)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        privacyStatusSection
                        privacyControlsSection
                        anonymousBrowsingSection
                        dataControlsSection
                        securityFeaturesSection
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Privacy Shopping")
        .sheet(isPresented: $showDataExport) {
            DataExportView()
        }
        .sheet(isPresented: $showDataDeletion) {
            DataDeletionView()
        }
        .onAppear {
            viewModel.loadPrivacySettings()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "shield.fill")
                    .font(.title)
                    .foregroundColor(themeManager.currentTheme.colors.accent)
                
                Text("Privacy-First Shopping")
                    .typography(.display1, theme: .elegant)
                    .foregroundColor(themeManager.currentTheme.colors.primary)
            }
            
            Text("Shop with complete privacy protection. No tracking, no data collection, no compromises.")
                .typography(.body2, theme: .minimal)
                .foregroundColor(themeManager.currentTheme.colors.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var privacyStatusSection: some View {
        VStack(spacing: 16) {
            Text("Privacy Status")
                .typography(.heading3, theme: .modern)
                .foregroundColor(themeManager.currentTheme.colors.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                PrivacyStatusCard(
                    icon: "eye.slash.fill",
                    title: "Anonymous Mode",
                    status: viewModel.settings.anonymousMode ? "Active" : "Inactive",
                    isActive: viewModel.settings.anonymousMode,
                    color: .blue
                )
                
                PrivacyStatusCard(
                    icon: "hand.raised.fill",
                    title: "Tracking Blocked",
                    status: viewModel.settings.trackingOptOut ? "Protected" : "Exposed",
                    isActive: viewModel.settings.trackingOptOut,
                    color: .green
                )
                
                PrivacyStatusCard(
                    icon: "trash.fill",
                    title: "Data Retention",
                    status: "\(viewModel.settings.dataRetentionDays) days",
                    isActive: viewModel.settings.dataRetentionDays <= 30,
                    color: .orange
                )
                
                PrivacyStatusCard(
                    icon: "person.2.slash.fill",
                    title: "Data Sharing",
                    status: viewModel.settings.shareWithPartners ? "Enabled" : "Disabled",
                    isActive: !viewModel.settings.shareWithPartners,
                    color: .red
                )
            }
        }
    }
    
    private var privacyControlsSection: some View {
        VStack(spacing: 16) {
            Text("Privacy Controls")
                .typography(.heading3, theme: .modern)
                .foregroundColor(themeManager.currentTheme.colors.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                PrivacyToggleRow(
                    icon: "theatermasks.fill",
                    title: "Anonymous Browsing",
                    description: "Browse without creating any personal data trail",
                    isOn: $viewModel.settings.anonymousMode
                ) {
                    viewModel.updateSettings()
                }
                
                PrivacyToggleRow(
                    icon: "location.slash.fill",
                    title: "Block Location Tracking",
                    description: "Prevent stores from tracking your location",
                    isOn: $viewModel.settings.locationTracking
                ) {
                    viewModel.updateSettings()
                }
                
                PrivacyToggleRow(
                    icon: "magnifyingglass.circle.fill",
                    title: "Private Search History",
                    description: "Don't save your search queries",
                    isOn: $viewModel.settings.searchHistory
                ) {
                    viewModel.updateSettings()
                }
                
                PrivacyToggleRow(
                    icon: "creditcard.fill",
                    title: "Private Purchase History",
                    description: "Don't store your purchase information",
                    isOn: $viewModel.settings.purchaseHistory
                ) {
                    viewModel.updateSettings()
                }
                
                PrivacyToggleRow(
                    icon: "bell.slash.fill",
                    title: "Personalized Ads",
                    description: "Block targeted advertising",
                    isOn: $viewModel.settings.personalizedAds
                ) {
                    viewModel.updateSettings()
                }
            }
        }
    }
    
    private var anonymousBrowsingSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Anonymous Session")
                    .typography(.heading3, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.primary)
                
                Spacer()
                
                if viewModel.hasAnonymousSession {
                    Text("Active")
                        .typography(.caption1, theme: .minimal)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            if viewModel.hasAnonymousSession {
                AnonymousSessionCard(
                    sessionId: viewModel.anonymousSessionId,
                    expiresAt: viewModel.sessionExpiresAt
                ) {
                    viewModel.endAnonymousSession()
                }
            } else {
                Button("Start Anonymous Session") {
                    viewModel.startAnonymousSession()
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(themeManager.currentTheme.colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .tapWithHaptic(.medium)
            }
            
            Text("In anonymous mode, we don't store any personal data. Your shopping activity is completely private.")
                .typography(.caption2, theme: .minimal)
                .foregroundColor(themeManager.currentTheme.colors.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var dataControlsSection: some View {
        VStack(spacing: 16) {
            Text("Data Controls")
                .typography(.heading3, theme: .modern)
                .foregroundColor(themeManager.currentTheme.colors.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                DataControlCard(
                    icon: "arrow.down.doc.fill",
                    title: "Export Your Data",
                    description: "Download all data we have about you",
                    buttonText: "Export Data",
                    color: .blue
                ) {
                    showDataExport = true
                }
                
                DataControlCard(
                    icon: "trash.fill",
                    title: "Delete Your Data",
                    description: "Permanently remove all your data from our systems",
                    buttonText: "Delete Data",
                    color: .red
                ) {
                    showDataDeletion = true
                }
                
                DataControlCard(
                    icon: "clock.fill",
                    title: "Data Retention",
                    description: "Currently set to \(viewModel.settings.dataRetentionDays) days",
                    buttonText: "Change",
                    color: .orange
                ) {
                    // Show data retention settings
                }
            }
        }
    }
    
    private var securityFeaturesSection: some View {
        VStack(spacing: 16) {
            Text("Security Features")
                .typography(.heading3, theme: .modern)
                .foregroundColor(themeManager.currentTheme.colors.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                SecurityFeatureCard(
                    icon: "shield.checkered",
                    title: "No Tracking Pixels",
                    description: "We block all tracking pixels and beacons",
                    isActive: true
                )
                
                SecurityFeatureCard(
                    icon: "lock.shield.fill",
                    title: "Secure Checkout",
                    description: "Anonymous redirects to store checkouts",
                    isActive: true
                )
                
                SecurityFeatureCard(
                    icon: "eye.slash.fill",
                    title: "No Stored Payment Info",
                    description: "We never store credit card or payment data",
                    isActive: true
                )
                
                SecurityFeatureCard(
                    icon: "network.slash",
                    title: "Third-Party Blocking",
                    description: "Block all third-party trackers and analytics",
                    isActive: viewModel.settings.trackingOptOut
                )
            }
        }
    }
}

struct PrivacyStatusCard: View {
    let icon: String
    let title: String
    let status: String
    let isActive: Bool
    let color: Color
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isActive ? color : .gray)
            
            Text(title)
                .typography(.caption1, theme: .modern)
                .foregroundColor(themeManager.currentTheme.colors.primary)
                .fontWeight(.medium)
            
            Text(status)
                .typography(.caption2, theme: .minimal)
                .foregroundColor(isActive ? color : .gray)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100)
        .glassmorphism(intensity: .medium)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? color.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}

struct PrivacyToggleRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool
    let onToggle: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(themeManager.currentTheme.colors.accent)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .typography(.body2, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.primary)
                    .fontWeight(.medium)
                
                Text(description)
                    .typography(.caption2, theme: .minimal)
                    .foregroundColor(themeManager.currentTheme.colors.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: themeManager.currentTheme.colors.accent))
                .onChange(of: isOn) { _ in
                    onToggle()
                }
        }
        .padding()
        .glassmorphism(intensity: .light)
    }
}

struct AnonymousSessionCard: View {
    let sessionId: String
    let expiresAt: Date
    let onEnd: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session ID")
                        .typography(.caption2, theme: .minimal)
                        .foregroundColor(themeManager.currentTheme.colors.secondary)
                    
                    Text(sessionId.prefix(8) + "...")
                        .typography(.caption1, theme: .modern)
                        .foregroundColor(themeManager.currentTheme.colors.primary)
                        .fontFamily(.monospaced)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Expires")
                        .typography(.caption2, theme: .minimal)
                        .foregroundColor(themeManager.currentTheme.colors.secondary)
                    
                    Text(expiresAt, style: .time)
                        .typography(.caption1, theme: .modern)
                        .foregroundColor(themeManager.currentTheme.colors.primary)
                }
            }
            
            Button("End Session") {
                onEnd()
            }
            .foregroundColor(.red)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .glassmorphism(intensity: .medium)
    }
}

struct DataControlCard: View {
    let icon: String
    let title: String
    let description: String
    let buttonText: String
    let color: Color
    let action: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .typography(.body2, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.primary)
                    .fontWeight(.medium)
                
                Text(description)
                    .typography(.caption2, theme: .minimal)
                    .foregroundColor(themeManager.currentTheme.colors.secondary)
            }
            
            Spacer()
            
            Button(buttonText) {
                action()
            }
            .typography(.caption1, theme: .minimal)
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .glassmorphism(intensity: .light)
    }
}

struct SecurityFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let isActive: Bool
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isActive ? .green : .gray)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .typography(.body2, theme: .modern)
                    .foregroundColor(themeManager.currentTheme.colors.primary)
                    .fontWeight(.medium)
                
                Text(description)
                    .typography(.caption2, theme: .minimal)
                    .foregroundColor(themeManager.currentTheme.colors.secondary)
            }
            
            Spacer()
            
            Image(systemName: isActive ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isActive ? .green : .red)
        }
        .padding()
        .glassmorphism(intensity: .light)
    }
}

#Preview {
    PrivacyShoppingView()
        .environmentObject(ThemeManager())
        .environmentObject(PrivacyControlsManager())
}