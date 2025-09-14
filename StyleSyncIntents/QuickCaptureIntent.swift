import Foundation
import AppIntents
import SwiftUI
import Photos
import PhotosUI

struct QuickCaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Capture"
    static var description = IntentDescription("Quickly capture and analyze your outfit with AI-powered insights")

    static var parameterSummary: some ParameterSummary {
        Summary("Quick capture \(\.$captureType)") {
            \.$autoAnalyze
            \.$saveToWardrobe
            \.$addTags
        }
    }

    static var openAppWhenRun: Bool = true

    @Parameter(title: "Capture Type", description: "What type of photo to capture", default: .outfit)
    var captureType: CaptureType

    @Parameter(title: "Auto Analyze", description: "Automatically analyze the captured image", default: true)
    var autoAnalyze: Bool

    @Parameter(title: "Save to Wardrobe", description: "Save the item to your digital wardrobe", default: true)
    var saveToWardrobe: Bool

    @Parameter(title: "Add Tags", description: "Prompt to add tags after capture", default: false)
    var addTags: Bool

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {

        let captureSession = QuickCaptureSession(
            type: captureType,
            autoAnalyze: autoAnalyze,
            saveToWardrobe: saveToWardrobe,
            addTags: addTags,
            timestamp: Date()
        )

        let result = await QuickCaptureService.shared.initiateCaptureSession(captureSession)

        let dialog = generateCaptureDialog(for: result)
        let snippet = QuickCaptureResultView(result: result, session: captureSession)

        return .result(
            dialog: dialog,
            view: snippet
        )
    }

    private func generateCaptureDialog(for result: QuickCaptureResult) -> IntentDialog {
        switch result.status {
        case .ready:
            return IntentDialog("Ready to capture your \(captureType.displayName.lowercased())! The camera is launching now.")

        case .captured:
            var message = "Great shot! "

            if autoAnalyze {
                if let analysis = result.analysis {
                    switch analysis.confidence {
                    case .high:
                        message += "I can see \(analysis.detectedItems.joined(separator: ", ")). "
                    case .medium:
                        message += "I detected some fashion items. "
                    case .low:
                        message += "Image captured, but analysis needs better lighting. "
                    }
                }
            }

            if saveToWardrobe {
                message += "Added to your wardrobe!"
            } else {
                message += "Capture completed!"
            }

            return IntentDialog(message)

        case .failed:
            return IntentDialog("Couldn't complete the capture. Please try again or check camera permissions.")
        }
    }
}

enum CaptureType: String, CaseIterable, AppEnum {
    case outfit = "outfit"
    case single_item = "single_item"
    case inspiration = "inspiration"
    case color_palette = "color_palette"
    case accessory = "accessory"
    case shoes = "shoes"
    case details = "details"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Capture Type")

    static var caseDisplayRepresentations: [CaptureType: DisplayRepresentation] = [
        .outfit: DisplayRepresentation(title: "Full Outfit", subtitle: "Complete head-to-toe look"),
        .single_item: DisplayRepresentation(title: "Single Item", subtitle: "Individual piece of clothing"),
        .inspiration: DisplayRepresentation(title: "Inspiration", subtitle: "Style inspiration from anywhere"),
        .color_palette: DisplayRepresentation(title: "Color Palette", subtitle: "Colors for outfit matching"),
        .accessory: DisplayRepresentation(title: "Accessory", subtitle: "Bags, jewelry, scarves"),
        .shoes: DisplayRepresentation(title: "Shoes", subtitle: "Footwear collection"),
        .details: DisplayRepresentation(title: "Details", subtitle: "Close-up details and textures")
    ]

    var displayName: String {
        switch self {
        case .outfit: return "Full Outfit"
        case .single_item: return "Single Item"
        case .inspiration: return "Style Inspiration"
        case .color_palette: return "Color Palette"
        case .accessory: return "Accessory"
        case .shoes: return "Shoes"
        case .details: return "Details"
        }
    }

    var icon: String {
        switch self {
        case .outfit: return "person.fill"
        case .single_item: return "tshirt.fill"
        case .inspiration: return "lightbulb.fill"
        case .color_palette: return "paintpalette.fill"
        case .accessory: return "bag.fill"
        case .shoes: return "shoe.2.fill"
        case .details: return "magnifyingglass"
        }
    }

    var captureGuidance: String {
        switch self {
        case .outfit: return "Stand in good lighting, show full body"
        case .single_item: return "Lay item flat with clear background"
        case .inspiration: return "Capture anything that inspires your style"
        case .color_palette: return "Focus on colors you want to match"
        case .accessory: return "Show accessory clearly with good lighting"
        case .shoes: return "Capture both shoes from best angle"
        case .details: return "Get close to show texture and details"
        }
    }
}

struct QuickCaptureSession {
    let type: CaptureType
    let autoAnalyze: Bool
    let saveToWardrobe: Bool
    let addTags: Bool
    let timestamp: Date
}

struct QuickCaptureResult {
    let status: CaptureStatus
    let analysis: CaptureAnalysis?
    let savedItem: SavedItem?
    let suggestions: [CaptureSuggestion]
}

enum CaptureStatus {
    case ready
    case captured
    case failed
}

struct CaptureAnalysis {
    let detectedItems: [String]
    let colors: [DetectedColor]
    let style: DetectedStyle
    let confidence: AnalysisConfidence
    let metadata: CaptureMetadata
}

enum AnalysisConfidence {
    case high
    case medium
    case low
}

struct DetectedColor {
    let name: String
    let hex: String
    let prominence: Double
}

struct DetectedStyle {
    let primary: String
    let secondary: [String]
    let occasion: [String]
}

struct CaptureMetadata {
    let lighting: String
    let angle: String
    let quality: String
    let completeness: String
}

struct SavedItem {
    let id: String
    let name: String
    let category: String
    let tags: [String]
    let addedToCollection: String
}

struct CaptureSuggestion {
    let title: String
    let description: String
    let actionType: SuggestionActionType
    let priority: SuggestionPriority
}

enum SuggestionActionType {
    case retake
    case addTags
    case matchItems
    case createOutfit
    case improvePhoto
}

enum SuggestionPriority {
    case high
    case medium
    case low
}

class QuickCaptureService {
    static let shared = QuickCaptureService()

    func initiateCaptureSession(_ session: QuickCaptureSession) async -> QuickCaptureResult {

        await Task.sleep(nanoseconds: 2_000_000_000)


        let mockAnalysis = generateMockAnalysis(for: session.type)
        let mockSavedItem = session.saveToWardrobe ? generateMockSavedItem(for: session.type) : nil
        let mockSuggestions = generateMockSuggestions(for: session)

        return QuickCaptureResult(
            status: .captured,
            analysis: session.autoAnalyze ? mockAnalysis : nil,
            savedItem: mockSavedItem,
            suggestions: mockSuggestions
        )
    }

    private func generateMockAnalysis(for type: CaptureType) -> CaptureAnalysis {
        switch type {
        case .outfit:
            return CaptureAnalysis(
                detectedItems: ["Navy Blazer", "White Shirt", "Dark Jeans", "Brown Loafers"],
                colors: [
                    DetectedColor(name: "Navy Blue", hex: "#1e3a8a", prominence: 0.4),
                    DetectedColor(name: "White", hex: "#ffffff", prominence: 0.3),
                    DetectedColor(name: "Brown", hex: "#8b5a2b", prominence: 0.2),
                    DetectedColor(name: "Dark Blue", hex: "#1e40af", prominence: 0.1)
                ],
                style: DetectedStyle(
                    primary: "Smart Casual",
                    secondary: ["Business Casual", "Weekend"],
                    occasion: ["Work", "Dinner", "Meeting"]
                ),
                confidence: .high,
                metadata: CaptureMetadata(
                    lighting: "Good natural light",
                    angle: "Full body frontal",
                    quality: "Sharp and clear",
                    completeness: "Complete outfit visible"
                )
            )

        case .single_item:
            return CaptureAnalysis(
                detectedItems: ["Cashmere Sweater"],
                colors: [
                    DetectedColor(name: "Sage Green", hex: "#87a96b", prominence: 0.9),
                    DetectedColor(name: "Cream", hex: "#f5f5dc", prominence: 0.1)
                ],
                style: DetectedStyle(
                    primary: "Casual Elegant",
                    secondary: ["Minimalist", "Classic"],
                    occasion: ["Weekend", "Casual Work", "Brunch"]
                ),
                confidence: .high,
                metadata: CaptureMetadata(
                    lighting: "Soft even lighting",
                    angle: "Flat lay",
                    quality: "High detail visible",
                    completeness: "Item fully visible"
                )
            )

        case .inspiration:
            return CaptureAnalysis(
                detectedItems: ["Street Style Look"],
                colors: [
                    DetectedColor(name: "Black", hex: "#000000", prominence: 0.5),
                    DetectedColor(name: "White", hex: "#ffffff", prominence: 0.3),
                    DetectedColor(name: "Red", hex: "#dc2626", prominence: 0.2)
                ],
                style: DetectedStyle(
                    primary: "Edgy Modern",
                    secondary: ["Street Style", "Contemporary"],
                    occasion: ["Night Out", "Creative Events", "Weekend"]
                ),
                confidence: .medium,
                metadata: CaptureMetadata(
                    lighting: "Variable street lighting",
                    angle: "Candid capture",
                    quality: "Good overall",
                    completeness: "Style elements visible"
                )
            )

        case .accessory:
            return CaptureAnalysis(
                detectedItems: ["Leather Handbag"],
                colors: [
                    DetectedColor(name: "Cognac Brown", hex: "#a0522d", prominence: 0.8),
                    DetectedColor(name: "Gold", hex: "#ffd700", prominence: 0.2)
                ],
                style: DetectedStyle(
                    primary: "Classic",
                    secondary: ["Timeless", "Elegant"],
                    occasion: ["Work", "Dinner", "Shopping"]
                ),
                confidence: .high,
                metadata: CaptureMetadata(
                    lighting: "Well-lit product shot",
                    angle: "Three-quarter view",
                    quality: "Crisp details",
                    completeness: "Accessory fully shown"
                )
            )

        default:
            return CaptureAnalysis(
                detectedItems: ["Fashion Item"],
                colors: [DetectedColor(name: "Neutral", hex: "#9ca3af", prominence: 1.0)],
                style: DetectedStyle(primary: "General", secondary: [], occasion: []),
                confidence: .medium,
                metadata: CaptureMetadata(
                    lighting: "Standard",
                    angle: "Front view",
                    quality: "Good",
                    completeness: "Visible"
                )
            )
        }
    }

    private func generateMockSavedItem(for type: CaptureType) -> SavedItem {
        switch type {
        case .outfit:
            return SavedItem(
                id: UUID().uuidString,
                name: "Smart Casual Outfit",
                category: "Complete Outfits",
                tags: ["work", "versatile", "smart-casual"],
                addedToCollection: "My Wardrobe"
            )

        case .single_item:
            return SavedItem(
                id: UUID().uuidString,
                name: "Sage Green Sweater",
                category: "Tops",
                tags: ["cashmere", "green", "sweater"],
                addedToCollection: "Sweaters"
            )

        case .accessory:
            return SavedItem(
                id: UUID().uuidString,
                name: "Brown Leather Bag",
                category: "Accessories",
                tags: ["leather", "brown", "handbag"],
                addedToCollection: "Bags"
            )

        default:
            return SavedItem(
                id: UUID().uuidString,
                name: "New Item",
                category: "General",
                tags: [],
                addedToCollection: "My Collection"
            )
        }
    }

    private func generateMockSuggestions(for session: QuickCaptureSession) -> [CaptureSuggestion] {
        var suggestions: [CaptureSuggestion] = []

        if session.autoAnalyze {
            suggestions.append(CaptureSuggestion(
                title: "Create Outfit",
                description: "Use this item to create a complete outfit",
                actionType: .createOutfit,
                priority: .high
            ))

            suggestions.append(CaptureSuggestion(
                title: "Find Matches",
                description: "Find similar items in your wardrobe",
                actionType: .matchItems,
                priority: .medium
            ))
        }

        if session.addTags {
            suggestions.append(CaptureSuggestion(
                title: "Add More Tags",
                description: "Tag this item for better organization",
                actionType: .addTags,
                priority: .medium
            ))
        }

        return suggestions
    }
}

struct QuickCaptureResultView: View {
    let result: QuickCaptureResult
    let session: QuickCaptureSession

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Capture")
                        .font(.headline)
                        .fontWeight(.bold)

                    Text(session.type.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: session.type.icon)
                    .font(.title2)
                    .foregroundColor(.blue)
            }


            if let savedItem = result.savedItem {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Saved Item")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(savedItem.name)
                                .font(.body)
                                .fontWeight(.medium)

                            Text("Added to \(savedItem.addedToCollection)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                }
            }


            if let analysis = result.analysis {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Analysis")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if !analysis.detectedItems.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Detected Items")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(analysis.detectedItems, id: \.self) { item in
                                        Text(item)
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.horizontal, 1)
                            }
                        }
                    }

                    if !analysis.colors.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Color Palette")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                ForEach(analysis.colors.prefix(4), id: \.name) { color in
                                    ColorPaletteSwatch(color: color)
                                }
                                Spacer()
                            }
                        }
                    }

                    ConfidenceBadge(confidence: analysis.confidence)
                }
            }


            if !result.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggestions")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(result.suggestions.prefix(2), id: \.title) { suggestion in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(suggestion.priority == .high ? Color.red : (suggestion.priority == .medium ? Color.orange : Color.green))
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(.caption)
                                    .fontWeight(.semibold)

                                Text(suggestion.description)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
}

struct ColorPaletteSwatch: View {
    let color: DetectedColor

    private var swatchColor: Color {
        Color(hex: color.hex) ?? .gray
    }

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(swatchColor)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            Text(color.name)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: AnalysisConfidence

    private var badgeColor: Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }

    private var confidenceText: String {
        switch confidence {
        case .high: return "High Confidence"
        case .medium: return "Medium Confidence"
        case .low: return "Low Confidence"
        }
    }

    var body: some View {
        Text(confidenceText)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.1))
            .foregroundColor(badgeColor)
            .clipShape(Capsule())
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}