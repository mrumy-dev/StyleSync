import SwiftUI
import Foundation
import Combine

struct OptimizedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let scale: CGFloat
    let transaction: Transaction
    @ViewBuilder let content: (AsyncImagePhase) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @StateObject private var imageLoader = ImageLoader()
    @State private var phase: AsyncImagePhase = .empty

    init(
        url: URL?,
        scale: CGFloat = 1.0,
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder = { EmptyView() }
    ) {
        self.url = url
        self.scale = scale
        self.transaction = transaction
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        content(phase)
            .onAppear {
                if let url = url {
                    loadImage(from: url)
                }
            }
            .onChange(of: url) { newURL in
                if let newURL = newURL {
                    loadImage(from: newURL)
                } else {
                    phase = .empty
                }
            }
    }

    private func loadImage(from url: URL) {
        phase = .empty

        imageLoader.loadImage(from: url) { result in
            withTransaction(transaction) {
                switch result {
                case .success(let image):
                    phase = .success(image)
                case .failure(let error):
                    phase = .failure(error)
                }
            }
        }
    }
}

extension OptimizedAsyncImage where Content == Image, Placeholder == EmptyView {
    init(url: URL?, scale: CGFloat = 1.0) {
        self.init(url: url, scale: scale) { phase in
            phase.image ?? Image(systemName: "photo")
        } placeholder: {
            EmptyView()
        }
    }
}

extension OptimizedAsyncImage where Placeholder == EmptyView {
    init(url: URL?, scale: CGFloat = 1.0, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.init(url: url, scale: scale, content: content) {
            EmptyView()
        }
    }
}

@MainActor
class ImageLoader: ObservableObject {
    private static let cache = NSCache<NSString, UIImage>()
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024, diskPath: "images")
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()

    private var cancellables = Set<AnyCancellable>()

    func loadImage(from url: URL, completion: @escaping (Result<Image, Error>) -> Void) {
        let cacheKey = NSString(string: url.absoluteString)

        if let cachedImage = Self.cache.object(forKey: cacheKey) {
            completion(.success(Image(uiImage: cachedImage)))
            return
        }

        Self.session.dataTaskPublisher(for: url)
            .tryMap { data, response -> UIImage in
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let image = UIImage(data: data) else {
                    throw URLError(.badServerResponse)
                }

                Self.cache.setObject(image, forKey: cacheKey)
                return image
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        completion(.failure(error))
                    }
                },
                receiveValue: { uiImage in
                    completion(.success(Image(uiImage: uiImage)))
                }
            )
            .store(in: &cancellables)
    }

    static func clearCache() {
        cache.removeAllObjects()
    }

    static func preloadImage(from url: URL) {
        let loader = ImageLoader()
        loader.loadImage(from: url) { _ in }
    }
}

struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    let contentMode: ContentMode
    @ViewBuilder let content: (AsyncImagePhase) -> Content

    init(
        url: URL?,
        contentMode: ContentMode = .fit,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.contentMode = contentMode
        self.content = content
    }

    var body: some View {
        OptimizedAsyncImage(url: url) { phase in
            content(phase)
        }
    }
}

extension CachedAsyncImage where Content == Image {
    init(url: URL?, contentMode: ContentMode = .fit) {
        self.init(url: url, contentMode: contentMode) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            case .failure(_):
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
            case .empty:
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .shimmer()
            @unknown default:
                EmptyView()
            }
        }
    }
}

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.4),
                        .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase)
                .animation(
                    .linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                    value: phase
                )
            )
            .clipped()
            .onAppear {
                phase = 300
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

struct PreloadImageModifier: ViewModifier {
    let urls: [URL]

    func body(content: Content) -> some View {
        content
            .onAppear {
                urls.forEach { url in
                    ImageLoader.preloadImage(from: url)
                }
            }
    }
}

extension View {
    func preloadImages(urls: [URL]) -> some View {
        modifier(PreloadImageModifier(urls: urls))
    }
}