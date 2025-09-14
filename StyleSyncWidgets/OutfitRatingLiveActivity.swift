import ActivityKit
import SwiftUI
import WidgetKit

struct OutfitRatingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentRating: Double
        var totalRatings: Int
        var recentVotes: [Vote]
        var timeRemaining: TimeInterval
        var isActive: Bool
    }

    var outfitId: String
    var outfitName: String
    var startTime: Date
    var sessionDuration: TimeInterval
}

struct Vote: Codable, Hashable {
    let id: String
    let rating: Int
    let timestamp: Date
    let category: String
}

struct OutfitRatingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OutfitRatingAttributes.self) { context in
            OutfitRatingLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.outfitName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: Double(star) <= context.state.currentRating ? "star.fill" : "star")
                                    .font(.caption2)
                                    .foregroundColor(Double(star) <= context.state.currentRating ? .yellow : .gray)
                            }

                            Text(String(format: "%.1f", context.state.currentRating))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(context.state.totalRatings)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text("votes")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 6) {
                        Text("Rate This Outfit")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { rating in
                                Button(intent: SubmitRatingIntent(outfitId: context.attributes.outfitId, rating: rating)) {
                                    Image(systemName: "star.fill")
                                        .font(.title3)
                                        .foregroundColor(.yellow)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        ProgressView(value: (context.attributes.sessionDuration - context.state.timeRemaining) / context.attributes.sessionDuration)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .frame(height: 4)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if !context.state.recentVotes.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Recent Votes")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                HStack(spacing: 4) {
                                    ForEach(context.state.recentVotes.prefix(3), id: \.id) { vote in
                                        HStack(spacing: 2) {
                                            ForEach(1...vote.rating, id: \.self) { _ in
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 8))
                                                    .foregroundColor(.yellow)
                                            }
                                        }
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(.yellow.opacity(0.2))
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Time Left")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Text(timeString(from: context.state.timeRemaining))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
            } compactTrailing: {
                Text(String(format: "%.1f", context.state.currentRating))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            } minimal: {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
            }
        }
    }
}

struct OutfitRatingLockScreenView: View {
    let context: ActivityViewContext<OutfitRatingAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rating Session")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(context.attributes.outfitName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: Double(star) <= context.state.currentRating ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundColor(Double(star) <= context.state.currentRating ? .yellow : .gray)
                        }
                    }

                    Text("\(context.state.totalRatings) votes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Rate this outfit:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Spacer()

                    Text(timeString(from: context.state.timeRemaining))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.1))
                        .clipShape(Capsule())
                }

                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { rating in
                        Button(intent: SubmitRatingIntent(outfitId: context.attributes.outfitId, rating: rating)) {
                            VStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.title2)
                                    .foregroundColor(.yellow)

                                Text("\(rating)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                ProgressView(value: (context.attributes.sessionDuration - context.state.timeRemaining) / context.attributes.sessionDuration)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(height: 6)
            }

            if !context.state.recentVotes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Activity")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(context.state.recentVotes.prefix(5), id: \.id) { vote in
                                VStack(spacing: 2) {
                                    HStack(spacing: 1) {
                                        ForEach(1...vote.rating, id: \.self) { _ in
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(.yellow)
                                        }
                                    }

                                    Text(vote.category)
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
    }
}

struct SubmitRatingIntent: AppIntent {
    static var title: LocalizedStringResource = "Submit Rating"
    static var description = IntentDescription("Submit a rating for the current outfit")

    @Parameter(title: "Outfit ID")
    var outfitId: String

    @Parameter(title: "Rating")
    var rating: Int

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

private func timeString(from timeInterval: TimeInterval) -> String {
    let minutes = Int(timeInterval) / 60
    let seconds = Int(timeInterval) % 60
    return String(format: "%02d:%02d", minutes, seconds)
}