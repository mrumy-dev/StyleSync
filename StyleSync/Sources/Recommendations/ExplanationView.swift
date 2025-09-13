import SwiftUI
import Charts

struct ExplanationView: View {
    let explanation: DetailedExplanation
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selectedFactor: DetailedExplanation.ExplanationFactor?
    @State private var showFeedback = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    confidenceSection
                    factorBreakdownSection
                    reasoningSection
                    visualExplanationSection
                    feedbackSection
                }
                .padding()
            }
            .navigationTitle("Why This Match?")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView(questions: explanation.feedbackQuestions)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text(explanation.primary)
                    .typography(.title2, theme: .modern)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                ForEach(explanation.secondary.prefix(2), id: \.self) { secondary in
                    Text(secondary)
                        .typography(.body2, theme: .minimal)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            HStack(spacing: 16) {
                confidenceBadge
                accuracyIndicator
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var confidenceBadge: some View {
        VStack(spacing: 4) {
            Text("\(Int(explanation.confidence * 100))%")
                .typography(.title2, theme: .modern)
                .fontWeight(.bold)
                .foregroundColor(.blue)

            Text("Confidence")
                .typography(.caption2, theme: .minimal)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }

    private var accuracyIndicator: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<5) { index in
                    Image(systemName: index < Int(explanation.confidence * 5) ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }

            Text("Accuracy")
                .typography(.caption2, theme: .minimal)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.1))
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }

    private var confidenceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Confidence Breakdown")
                .typography(.title3, theme: .modern)
                .fontWeight(.semibold)

            ConfidenceChart(confidence: explanation.confidence)
                .frame(height: 200)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }

    private var factorBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Factor Analysis")
                .typography(.title3, theme: .modern)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                ForEach(explanation.factorBreakdown, id: \.factor) { factor in
                    FactorRow(
                        factor: factor,
                        isSelected: selectedFactor?.factor == factor.factor
                    ) {
                        selectedFactor = selectedFactor?.factor == factor.factor ? nil : factor
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )

            if let selectedFactor = selectedFactor {
                FactorDetailView(factor: selectedFactor)
            }
        }
    }

    private var reasoningSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Reasoning")
                .typography(.title3, theme: .modern)
                .fontWeight(.semibold)

            VStack(spacing: 16) {
                ReasoningCard(
                    title: "Why We Recommend This",
                    content: explanation.secondary,
                    color: .green
                )

                ReasoningCard(
                    title: "Key Factors",
                    content: explanation.factorBreakdown.map { $0.explanation },
                    color: .blue
                )
            }
        }
    }

    private var visualExplanationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Visual Analysis")
                .typography(.title3, theme: .modern)
                .fontWeight(.semibold)

            VisualExplanationCard(visualExplanation: explanation.visualExplanation)
        }
    }

    private var feedbackSection: some View {
        VStack(spacing: 16) {
            Text("Help us improve")
                .typography(.title3, theme: .modern)
                .fontWeight(.semibold)

            Button("Provide Feedback") {
                showFeedback = true
            }
            .buttonStyle(PrimaryButtonStyle())

            Text("Your feedback helps our AI learn and provide better recommendations")
                .typography(.caption2, theme: .minimal)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct ConfidenceChart: View {
    let confidence: Double

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: confidence)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .cyan]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(Int(confidence * 100))")
                        .typography(.title1, theme: .modern)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)

                    Text("%")
                        .typography(.caption1, theme: .minimal)
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 8) {
                confidenceLabel
                confidenceDescription
            }
        }
    }

    private var confidenceLabel: some View {
        HStack {
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)

            Text(confidenceText)
                .typography(.body2, theme: .minimal)
                .fontWeight(.medium)

            Spacer()
        }
    }

    private var confidenceDescription: some View {
        Text(confidenceDescriptionText)
            .typography(.caption2, theme: .minimal)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var confidenceColor: Color {
        switch confidence {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        default: return .orange
        }
    }

    private var confidenceText: String {
        switch confidence {
        case 0.8...1.0: return "High Confidence"
        case 0.6..<0.8: return "Medium Confidence"
        default: return "Low Confidence"
        }
    }

    private var confidenceDescriptionText: String {
        switch confidence {
        case 0.8...1.0: return "We're very confident this matches your style and preferences"
        case 0.6..<0.8: return "This seems like a good match based on available data"
        default: return "This might be worth exploring, but we're less certain"
        }
    }
}

struct FactorRow: View {
    let factor: DetailedExplanation.ExplanationFactor
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(factor.factor)
                        .typography(.body2, theme: .modern)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text("\(Int(factor.contribution * 100))% contribution")
                        .typography(.caption2, theme: .minimal)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(factor.confidence * 100))%")
                        .typography(.caption1, theme: .minimal)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)

                    Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())

        if !isSelected {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
        }
    }
}

struct FactorDetailView: View {
    let factor: DetailedExplanation.ExplanationFactor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(factor.explanation)
                .typography(.body2, theme: .minimal)
                .foregroundColor(.primary)

            HStack {
                ContributionBar(percentage: factor.contribution)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Confidence: \(Int(factor.confidence * 100))%")
                        .typography(.caption2, theme: .minimal)
                        .foregroundColor(.secondary)

                    Text("Impact: \(Int(factor.contribution * 100))%")
                        .typography(.caption2, theme: .minimal)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: factor.factor)
    }
}

struct ContributionBar: View {
    let percentage: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .cyan]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * percentage, height: 8)
            }
        }
        .frame(height: 8)
        .frame(maxWidth: 120)
    }
}

struct ReasoningCard: View {
    let title: String
    let content: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundColor(color)

                Text(title)
                    .typography(.body1, theme: .modern)
                    .fontWeight(.semibold)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(content.prefix(3).enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .typography(.body2, theme: .minimal)
                            .foregroundColor(color)

                        Text(item)
                            .typography(.body2, theme: .minimal)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.05))
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }

    private var iconName: String {
        switch color {
        case .green: return "checkmark.circle"
        case .blue: return "info.circle"
        default: return "star.circle"
        }
    }
}

struct VisualExplanationCard: View {
    let visualExplanation: DetailedExplanation.VisualExplanation

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "eye")
                    .font(.title3)
                    .foregroundColor(.purple)

                Text("Visual Analysis")
                    .typography(.body1, theme: .modern)
                    .fontWeight(.semibold)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Style matching algorithm analyzed visual elements")
                    .typography(.body2, theme: .minimal)
                    .foregroundColor(.primary)

                if visualExplanation.type == "style_match" {
                    StyleMatchVisualization()
                } else if visualExplanation.type == "color_harmony" {
                    ColorHarmonyVisualization()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.05))
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
}

struct StyleMatchVisualization: View {
    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 8) {
                Text("Your Style")
                    .typography(.caption2, theme: .minimal)
                    .foregroundColor(.secondary)

                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
            }

            Image(systemName: "arrow.right")
                .font(.title3)
                .foregroundColor(.green)

            VStack(spacing: 8) {
                Text("This Item")
                    .typography(.caption2, theme: .minimal)
                    .foregroundColor(.secondary)

                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.cyan, .blue]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
            }

            Spacer()

            VStack(spacing: 4) {
                Text("92%")
                    .typography(.title3, theme: .modern)
                    .fontWeight(.bold)
                    .foregroundColor(.green)

                Text("Match")
                    .typography(.caption2, theme: .minimal)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ColorHarmonyVisualization: View {
    private let colors: [Color] = [.red, .blue, .green, .yellow, .purple]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color harmony analysis")
                .typography(.caption1, theme: .minimal)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                ForEach(0..<colors.count, id: \.self) { index in
                    Circle()
                        .fill(colors[index])
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }

                Spacer()

                Text("85% harmony")
                    .typography(.caption1, theme: .minimal)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
        }
    }
}

struct FeedbackView: View {
    let questions: [DetailedExplanation.FeedbackQuestion]
    @Environment(\.dismiss) private var dismiss
    @State private var responses: [String: Any] = [:]

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Help us improve our recommendations by answering a few questions")
                        .typography(.body2, theme: .minimal)
                        .foregroundColor(.secondary)
                }

                ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                    Section(question.question) {
                        QuestionView(question: question, response: binding(for: question.question))
                    }
                }
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitFeedback()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(responses.isEmpty)
                }
            }
        }
    }

    private func binding(for question: String) -> Binding<Any?> {
        Binding(
            get: { responses[question] },
            set: { responses[question] = $0 }
        )
    }

    private func submitFeedback() {
        // In real app, would submit to analytics/AI service
        print("Feedback submitted: \(responses)")
    }
}

struct QuestionView: View {
    let question: DetailedExplanation.FeedbackQuestion
    @Binding var response: Any?

    var body: some View {
        switch question.type {
        case .rating:
            StarRatingView(rating: binding(for: Int.self))
        case .binary:
            if let options = question.options {
                Picker("Response", selection: binding(for: String.self)) {
                    ForEach(options, id: \.self) { option in
                        Text(option).tag(option as String?)
                    }
                }
                .pickerStyle(.segmented)
            }
        case .multipleChoice:
            if let options = question.options {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        response = option
                    }) {
                        HStack {
                            Text(option)
                                .foregroundColor(.primary)
                            Spacer()
                            if let selected = response as? String, selected == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
        case .text:
            TextField("Your response", text: binding(for: String.self) ?? .constant(""))
        }
    }

    private func binding<T>(for type: T.Type) -> Binding<T>? {
        Binding(
            get: { response as? T ?? (type == String.self ? "" as! T : type == Int.self ? 0 as! T : response as? T) },
            set: { response = $0 }
        )
    }
}

struct StarRatingView: View {
    @Binding var rating: Int?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { star in
                Button(action: {
                    rating = star
                }) {
                    Image(systemName: (rating ?? 0) >= star ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundColor(.yellow)
                }
            }
            Spacer()
        }
    }
}

#Preview {
    ExplanationView(
        explanation: DetailedExplanation(
            primary: "This dress is an excellent match for your style preferences",
            secondary: [
                "Matches your favorite colors",
                "From a brand you trust",
                "Perfect for your upcoming events"
            ],
            confidence: 0.89,
            factorBreakdown: [
                DetailedExplanation.ExplanationFactor(
                    factor: "Style Match",
                    contribution: 0.35,
                    explanation: "Aligns perfectly with your minimalist aesthetic",
                    confidence: 0.9
                ),
                DetailedExplanation.ExplanationFactor(
                    factor: "Price Value",
                    contribution: 0.25,
                    explanation: "Excellent value within your budget",
                    confidence: 0.85
                ),
                DetailedExplanation.ExplanationFactor(
                    factor: "Brand Preference",
                    contribution: 0.2,
                    explanation: "From Zara, one of your preferred brands",
                    confidence: 0.95
                ),
                DetailedExplanation.ExplanationFactor(
                    factor: "Contextual Fit",
                    contribution: 0.2,
                    explanation: "Perfect for your upcoming work events",
                    confidence: 0.75
                )
            ],
            visualExplanation: DetailedExplanation.VisualExplanation(
                type: "style_match",
                data: [:],
                imageUrl: nil
            ),
            feedbackQuestions: [
                DetailedExplanation.FeedbackQuestion(
                    question: "How helpful was this explanation?",
                    type: .rating,
                    options: nil,
                    importance: .high
                ),
                DetailedExplanation.FeedbackQuestion(
                    question: "Does this match your style?",
                    type: .binary,
                    options: ["Yes", "No"],
                    importance: .high
                )
            ]
        )
    )
    .environmentObject(ThemeManager())
}