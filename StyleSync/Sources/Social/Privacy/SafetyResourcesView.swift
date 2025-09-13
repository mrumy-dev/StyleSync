import SwiftUI

struct SafetyResourcesView: View {
    @State private var selectedCategory = SafetyCategory.wellbeing

    enum SafetyCategory: String, CaseIterable {
        case wellbeing = "Digital Wellbeing"
        case privacy = "Privacy Tips"
        case safety = "Safety Guidelines"
        case support = "Support"
    }

    var body: some View {
        VStack(spacing: 0) {
            categorySelector
            contentSection
        }
        .background(Color.black)
        .navigationTitle("Safety Resources")
        .navigationBarTitleDisplayMode(.large)
    }

    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SafetyCategory.allCases, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                        HapticManager.shared.impact(.light)
                    }) {
                        Text(category.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(selectedCategory == category ? .black : .white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedCategory == category ? Color.white : Color.white.opacity(0.1))
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
    }

    private var contentSection: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                switch selectedCategory {
                case .wellbeing:
                    wellbeingContent
                case .privacy:
                    privacyContent
                case .safety:
                    safetyContent
                case .support:
                    supportContent
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    private var wellbeingContent: some View {
        VStack(spacing: 20) {
            ResourceCard(
                title: "Take Control of Your Time",
                description: "Learn how to manage your social media usage and create healthy boundaries.",
                icon: "clock.fill",
                color: .blue,
                tips: [
                    "Set daily time limits for social apps",
                    "Turn off non-essential notifications",
                    "Schedule regular digital detox breaks",
                    "Use focus modes during work or study time"
                ]
            )

            ResourceCard(
                title: "Mindful Sharing",
                description: "Think before you post and understand the impact of your digital footprint.",
                icon: "heart.circle.fill",
                color: .pink,
                tips: [
                    "Consider if your post adds value or positivity",
                    "Avoid sharing personal information publicly",
                    "Think about how your content might affect others",
                    "Use content warnings for sensitive topics"
                ]
            )

            ResourceCard(
                title: "Building Positive Communities",
                description: "Create and participate in supportive online environments.",
                icon: "person.3.fill",
                color: .green,
                tips: [
                    "Support creators whose values align with yours",
                    "Engage constructively in conversations",
                    "Report harmful content when you see it",
                    "Celebrate others' achievements and milestones"
                ]
            )
        }
    }

    private var privacyContent: some View {
        VStack(spacing: 20) {
            ResourceCard(
                title: "Protect Your Personal Information",
                description: "Keep your sensitive data safe while using social media.",
                icon: "shield.fill",
                color: .blue,
                tips: [
                    "Review your privacy settings regularly",
                    "Be selective about what you share publicly",
                    "Avoid sharing location in real-time",
                    "Use strong, unique passwords for all accounts"
                ]
            )

            ResourceCard(
                title: "Smart Sharing Practices",
                description: "Share content safely without compromising your privacy.",
                icon: "eye.fill",
                color: .purple,
                tips: [
                    "Check photo backgrounds for personal information",
                    "Avoid sharing full names of family and friends",
                    "Be cautious with location tags and check-ins",
                    "Review tagged content before it appears on your profile"
                ]
            )

            ResourceCard(
                title: "Understanding Data Usage",
                description: "Know how your data is used and take control of it.",
                icon: "externaldrive.fill",
                color: .orange,
                tips: [
                    "Read privacy policies and understand data collection",
                    "Limit data sharing with third-party apps",
                    "Regularly review and delete old content",
                    "Export your data periodically for backup"
                ]
            )
        }
    }

    private var safetyContent: some View {
        VStack(spacing: 20) {
            ResourceCard(
                title: "Recognizing Harmful Behavior",
                description: "Identify and respond to cyberbullying, harassment, and other harmful activities.",
                icon: "exclamationmark.triangle.fill",
                color: .red,
                tips: [
                    "Trust your instincts if something feels wrong",
                    "Document harmful content with screenshots",
                    "Don't engage with trolls or harassers",
                    "Report serious threats to platform moderators"
                ]
            )

            ResourceCard(
                title: "Avoiding Scams and Fraud",
                description: "Protect yourself from common online scams and fraudulent activities.",
                icon: "checkmark.shield.fill",
                color: .green,
                tips: [
                    "Be skeptical of too-good-to-be-true offers",
                    "Verify accounts before sharing personal information",
                    "Don't click suspicious links or download unknown files",
                    "Never share financial information through social media"
                ]
            )

            ResourceCard(
                title: "Safe Meeting Practices",
                description: "Stay safe when meeting online connections in person.",
                icon: "location.fill",
                color: .blue,
                tips: [
                    "Meet in public places with good lighting",
                    "Tell someone where you're going and when",
                    "Have your own transportation to and from meetings",
                    "Trust your instincts and leave if you feel uncomfortable"
                ]
            )
        }
    }

    private var supportContent: some View {
        VStack(spacing: 20) {
            ResourceCard(
                title: "Crisis Resources",
                description: "Immediate help and support for mental health emergencies.",
                icon: "phone.fill",
                color: .red,
                tips: [
                    "National Suicide Prevention Lifeline: 988",
                    "Crisis Text Line: Text HOME to 741741",
                    "International Association for Suicide Prevention",
                    "Local emergency services: 911"
                ]
            )

            ResourceCard(
                title: "Mental Health Support",
                description: "Resources for ongoing mental health and wellbeing support.",
                icon: "heart.fill",
                color: .pink,
                tips: [
                    "Psychology Today therapist directory",
                    "National Alliance on Mental Illness (NAMI)",
                    "Better Help online therapy platform",
                    "Local community mental health centers"
                ]
            )

            ResourceCard(
                title: "Reporting and Help",
                description: "How to get help with platform-specific issues and violations.",
                icon: "questionmark.circle.fill",
                color: .blue,
                tips: [
                    "Use in-app reporting tools for harmful content",
                    "Contact platform support for account issues",
                    "Reach out to trusted friends or family for support",
                    "Consider taking breaks from social media when needed"
                ]
            )

            Button(action: {
                // Open StyleSync support contact
                HapticManager.shared.impact(.medium)
            }) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)

                    Text("Contact StyleSync Support")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.1))
                )
            }
            .hapticFeedback(.medium, trigger: true)
        }
    }
}

struct ResourceCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let tips: [String]

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 16) {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
                HapticManager.shared.impact(.light)
            }) {
                HStack(spacing: 16) {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)

                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                        .animation(.spring(response: 0.3), value: isExpanded)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }

            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(color)
                                .frame(width: 6, height: 6)
                                .padding(.top, 8)

                            Text(tip)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationView {
        SafetyResourcesView()
    }
    .preferredColorScheme(.dark)
}