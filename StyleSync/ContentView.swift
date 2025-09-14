import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var styleItems: [StyleItem]
    @State private var appState = AppState()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                HeaderView()

                if styleItems.isEmpty {
                    EmptyStateView()
                } else {
                    StyleGridView(items: styleItems)
                }

                Spacer()
            }
            .padding()
            .background(DesignSystem.Colors.background)
        }
        .environment(appState)
    }
}

struct HeaderView: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("StyleSync")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(DesignSystem.Colors.primary)

                Text("Curate your style")
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(DesignSystem.Colors.accent)
            }
            .buttonStyle(PremiumButtonStyle())
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(DesignSystem.Colors.accent.gradient)

            Text("Start Your Style Journey")
                .font(.title2.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.primary)

            Text("Create collections and discover your unique style")
                .font(.body)
                .foregroundStyle(DesignSystem.Colors.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct StyleGridView: View {
    let items: [StyleItem]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            ForEach(items) { item in
                StyleItemCard(item: item)
            }
        }
    }
}

struct StyleItemCard: View {
    let item: StyleItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.accent.opacity(0.3))
                .aspectRatio(4/3, contentMode: .fit)
                .overlay(
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(DesignSystem.Colors.accent)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(DesignSystem.Colors.primary)
                    .lineLimit(1)

                Text(item.category)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.secondary)
            }
        }
        .padding(12)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: DesignSystem.Colors.shadow, radius: 8, y: 4)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [StyleItem.self, Collection.self], inMemory: true)
}