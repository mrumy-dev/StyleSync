import SwiftUI

struct ReportingInterfaceView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var privacyManager = PrivacyManager.shared
    @State private var selectedTab = ReportTab.content
    @State private var selectedReason: ReportReason?
    @State private var reportDetails = ""
    @State private var contentID = ""
    @State private var userID = ""
    @State private var isSubmitting = false
    @State private var showingSuccess = false

    enum ReportTab: String, CaseIterable {
        case content = "Content"
        case user = "User"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                tabSelector
                formContent
                submitButton
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
        .alert("Report Submitted", isPresented: $showingSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Thank you for helping keep StyleSync safe. We'll review your report and take appropriate action.")
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

                Text("Report")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: {}) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            VStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)

                Text("Help us keep StyleSync safe")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 16)
        }
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ReportTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                    HapticManager.shared.impact(.light)
                }) {
                    Text(tab.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(selectedTab == tab ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedTab == tab ? Color.white : Color.clear)
                        )
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private var formContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                if selectedTab == .content {
                    contentReportForm
                } else {
                    userReportForm
                }

                reasonSelection
                detailsSection
            }
            .padding(.horizontal, 20)
        }
    }

    private var contentReportForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Content Information")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 8) {
                Text("Content ID or URL")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)

                TextField("Enter content ID or share URL", text: $contentID)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
            }

            Text("You can find the content ID by tapping the three dots menu on any post or by sharing the content URL.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
        .glassCard()
    }

    private var userReportForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("User Information")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 8) {
                Text("Username or User ID")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)

                TextField("@username or user ID", text: $userID)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
            }

            Text("Report users for violations of our community guidelines, including harassment, impersonation, or inappropriate behavior.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
        .glassCard()
    }

    private var reasonSelection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reason for Report")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(ReportReason.allCases, id: \.self) { reason in
                    ReasonCard(
                        reason: reason,
                        isSelected: selectedReason == reason
                    ) {
                        selectedReason = reason
                        HapticManager.shared.impact(.light)
                    }
                }
            }
        }
        .glassCard()
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Additional Details")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 8) {
                Text("Describe the issue (Optional)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)

                TextEditor(text: $reportDetails)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(height: 120)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }

            Text("Providing additional context helps us better understand and address your report.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
        .glassCard()
    }

    private var submitButton: some View {
        VStack(spacing: 16) {
            Button(action: submitReport) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .medium))
                    }

                    Text(isSubmitting ? "Submitting..." : "Submit Report")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(canSubmit ? Color.white : Color.gray)
                )
            }
            .disabled(!canSubmit || isSubmitting)
            .hapticFeedback(.medium, trigger: canSubmit)

            Text("Reports are anonymous and help us maintain a safe community.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black)
    }

    private var canSubmit: Bool {
        guard let _ = selectedReason else { return false }

        if selectedTab == .content {
            return !contentID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return !userID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func submitReport() {
        guard let reason = selectedReason else { return }

        isSubmitting = true

        Task {
            do {
                if selectedTab == .content {
                    await privacyManager.reportContent(
                        contentID.trimmingCharacters(in: .whitespacesAndNewlines),
                        reason: reason,
                        details: reportDetails.isEmpty ? nil : reportDetails
                    )
                } else {
                    await privacyManager.reportUser(
                        userID.trimmingCharacters(in: .whitespacesAndNewlines),
                        reason: reason,
                        details: reportDetails.isEmpty ? nil : reportDetails
                    )
                }

                DispatchQueue.main.async {
                    self.isSubmitting = false
                    self.showingSuccess = true
                    HapticManager.shared.success()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isSubmitting = false
                    HapticManager.shared.error()
                }
            }
        }
    }
}

struct ReasonCard: View {
    let reason: ReportReason
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: iconForReason(reason))
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isSelected ? .black : .white)

                VStack(alignment: .leading, spacing: 4) {
                    Text(reason.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .black : .white)
                        .multilineTextAlignment(.leading)

                    Text(reason.description)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .black.opacity(0.7) : .gray)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }

                Spacer()
            }
            .padding(16)
            .frame(height: 120)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    private func iconForReason(_ reason: ReportReason) -> String {
        switch reason {
        case .spam:
            return "envelope.badge.fill"
        case .harassment:
            return "person.crop.circle.badge.exclamationmark"
        case .inappropriateContent:
            return "eye.slash.fill"
        case .impersonation:
            return "person.crop.circle.badge.questionmark"
        case .copyrightViolation:
            return "c.circle.fill"
        case .violence:
            return "exclamationmark.triangle.fill"
        case .selfHarm:
            return "heart.circle.fill"
        case .hateSpeech:
            return "message.badge.fill"
        case .other:
            return "ellipsis.circle.fill"
        }
    }
}

#Preview {
    ReportingInterfaceView()
        .preferredColorScheme(.dark)
}