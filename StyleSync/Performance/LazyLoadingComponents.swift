import SwiftUI
import Foundation

struct LazyScrollView<Content: View>: View {
    let axes: Axis.Set
    let showsIndicators: Bool
    let content: () -> Content

    init(
        _ axes: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.content = content
    }

    var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            LazyVStack(spacing: 0) {
                content()
            }
        }
    }
}

struct LazyGrid<Item: Identifiable, ItemView: View>: View {
    let items: [Item]
    let columns: [GridItem]
    let spacing: CGFloat?
    let itemContent: (Item) -> ItemView

    @State private var visibleItems: Set<Item.ID> = []

    init(
        items: [Item],
        columns: [GridItem],
        spacing: CGFloat? = nil,
        @ViewBuilder itemContent: @escaping (Item) -> ItemView
    ) {
        self.items = items
        self.columns = columns
        self.spacing = spacing
        self.itemContent = itemContent
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(items) { item in
                LazyItemView(
                    item: item,
                    isVisible: visibleItems.contains(item.id),
                    onVisibilityChange: { isVisible in
                        if isVisible {
                            visibleItems.insert(item.id)
                        } else {
                            visibleItems.remove(item.id)
                        }
                    }
                ) {
                    itemContent(item)
                }
            }
        }
    }
}

struct LazyItemView<Item: Identifiable, Content: View>: View {
    let item: Item
    let isVisible: Bool
    let onVisibilityChange: (Bool) -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .onAppear {
                onVisibilityChange(true)
            }
            .onDisappear {
                onVisibilityChange(false)
            }
    }
}

struct LazyOutfitGrid<OutfitItem: Identifiable>: View {
    let outfits: [OutfitItem]
    let onOutfitTap: (OutfitItem) -> Void

    @State private var loadedOutfits: Set<OutfitItem.ID> = []

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 16
        ) {
            ForEach(outfits) { outfit in
                LazyOutfitCard(
                    outfit: outfit,
                    isLoaded: loadedOutfits.contains(outfit.id),
                    onLoad: {
                        loadedOutfits.insert(outfit.id)
                    },
                    onTap: {
                        onOutfitTap(outfit)
                    }
                )
            }
        }
        .padding(.horizontal)
    }
}

struct LazyOutfitCard<OutfitItem: Identifiable>: View {
    let outfit: OutfitItem
    let isLoaded: Bool
    let onLoad: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                if isLoaded {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(height: 180)
                        .overlay(
                            VStack {
                                Image(systemName: "tshirt.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                Text("Outfit")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 180)
                        .shimmer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    if isLoaded {
                        Text("Style Look #\(outfit.id)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text("Perfect for any occasion")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 16)
                            .shimmer()

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)
                            .shimmer()
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            if !isLoaded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        onLoad()
                    }
                }
            }
        }
    }
}

struct VirtualizedList<Data: RandomAccessCollection, RowContent: View>: View
where Data.Element: Identifiable {
    let data: Data
    let rowHeight: CGFloat
    let rowContent: (Data.Element) -> RowContent

    @State private var scrollOffset: CGFloat = 0

    var visibleRange: Range<Int> {
        let startIndex = max(0, Int(scrollOffset / rowHeight) - 2)
        let endIndex = min(data.count, startIndex + Int(UIScreen.main.bounds.height / rowHeight) + 4)
        return startIndex..<endIndex
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                        if visibleRange.contains(index) {
                            rowContent(item)
                                .frame(height: rowHeight)
                                .id(item.id)
                        } else {
                            Color.clear
                                .frame(height: rowHeight)
                                .id(item.id)
                        }
                    }
                }
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geometry.frame(in: .named("scroll")).minY
                            )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = -value
            }
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

struct LazyLoadingModifier<LoadedContent: View, PlaceholderContent: View>: ViewModifier {
    let shouldLoad: Bool
    @ViewBuilder let loadedContent: () -> LoadedContent
    @ViewBuilder let placeholder: () -> PlaceholderContent

    func body(content: Content) -> some View {
        Group {
            if shouldLoad {
                loadedContent()
            } else {
                placeholder()
            }
        }
    }
}

extension View {
    func lazyLoad<LoadedContent: View, PlaceholderContent: View>(
        when shouldLoad: Bool,
        @ViewBuilder loadedContent: @escaping () -> LoadedContent,
        @ViewBuilder placeholder: @escaping () -> PlaceholderContent
    ) -> some View {
        modifier(LazyLoadingModifier(
            shouldLoad: shouldLoad,
            loadedContent: loadedContent,
            placeholder: placeholder
        ))
    }
}

struct InfiniteScrollView<Content: View>: View {
    let threshold: CGFloat
    let onLoadMore: () -> Void
    @ViewBuilder let content: () -> Content

    init(
        threshold: CGFloat = 100,
        onLoadMore: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.threshold = threshold
        self.onLoadMore = onLoadMore
        self.content = content
    }

    var body: some View {
        ScrollView {
            LazyVStack {
                content()

                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            if geometry.frame(in: .global).maxY < UIScreen.main.bounds.height + threshold {
                                onLoadMore()
                            }
                        }
                }
                .frame(height: 1)
            }
        }
    }
}

struct PaginatedGrid<Item: Identifiable, ItemView: View>: View {
    @ObservedObject var dataSource: PaginatedDataSource<Item>
    let columns: [GridItem]
    @ViewBuilder let itemContent: (Item) -> ItemView

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(dataSource.items) { item in
                    itemContent(item)
                        .onAppear {
                            if item.id == dataSource.items.last?.id {
                                dataSource.loadNextPage()
                            }
                        }
                }

                if dataSource.isLoading {
                    ForEach(0..<6, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 200)
                            .shimmer()
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

@MainActor
class PaginatedDataSource<Item: Identifiable>: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var hasMorePages = true

    private var currentPage = 0
    private let itemsPerPage = 20
    private let loadMore: (Int) -> AnyPublisher<[Item], Error>

    init(loadMore: @escaping (Int) -> AnyPublisher<[Item], Error>) {
        self.loadMore = loadMore
    }

    func loadNextPage() {
        guard !isLoading && hasMorePages else { return }

        isLoading = true

        loadMore(currentPage)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                },
                receiveValue: { [weak self] newItems in
                    self?.items.append(contentsOf: newItems)
                    self?.currentPage += 1
                    self?.hasMorePages = newItems.count >= (self?.itemsPerPage ?? 20)
                }
            )
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()
}

import Combine