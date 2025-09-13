import Foundation
import Vision
import CoreML
import UIKit
import Combine

@MainActor
class VisualSearchEngine: ObservableObject {
    @Published var isSearching = false
    @Published var searchHistory: [VisualSearchHistoryItem] = []

    private let networkService = VisualSearchNetworkService()
    private let privacyManager = VisualSearchPrivacyManager()
    private let cacheManager = VisualSearchCacheManager()

    func searchByPhoto(
        imageData: Data,
        mode: VisualSearchCameraView.SearchMode,
        privacySettings: PrivacySettings
    ) async throws -> [VisualSearchResult] {
        isSearching = true
        defer { isSearching = false }

        let processedImageData = await privacyManager.processImage(imageData, settings: privacySettings)

        let searchRequest = VisualSearchRequest(
            imageData: processedImageData,
            searchType: mode.searchType,
            privacySettings: privacySettings
        )

        let results = try await performOnDeviceSearch(request: searchRequest)

        let historyItem = VisualSearchHistoryItem(
            id: UUID().uuidString,
            imageData: processedImageData,
            searchType: mode.searchType,
            results: results,
            timestamp: Date(),
            privacyCompliant: true
        )

        await saveToHistory(historyItem)
        return results
    }

    func searchBySketch(
        sketch: SketchData,
        privacySettings: PrivacySettings
    ) async throws -> [VisualSearchResult] {
        isSearching = true
        defer { isSearching = false }

        let searchRequest = VisualSearchRequest(
            sketchData: sketch,
            searchType: .sketch,
            privacySettings: privacySettings
        )

        return try await performOnDeviceSearch(request: searchRequest)
    }

    func searchByColorPalette(
        colors: [UIColor],
        privacySettings: PrivacySettings
    ) async throws -> [VisualSearchResult] {
        isSearching = true
        defer { isSearching = false }

        let colorData = ColorPaletteData(colors: colors.map { $0.hexString })

        let searchRequest = VisualSearchRequest(
            colorData: colorData,
            searchType: .colorPalette,
            privacySettings: privacySettings
        )

        return try await performOnDeviceSearch(request: searchRequest)
    }

    private func performOnDeviceSearch(request: VisualSearchRequest) async throws -> [VisualSearchResult] {
        let cacheKey = generateCacheKey(for: request)

        if let cachedResults = await cacheManager.getCachedResults(for: cacheKey) {
            return cachedResults
        }

        let features = try await extractVisualFeatures(from: request)
        let matches = await findSimilarProducts(features: features)

        let results = matches.map { match in
            VisualSearchResult(
                id: UUID().uuidString,
                products: match.products,
                confidence: match.confidence,
                searchType: request.searchType.rawValue
            )
        }

        await cacheManager.cacheResults(results, for: cacheKey)
        return results
    }

    private func extractVisualFeatures(from request: VisualSearchRequest) async throws -> VisualFeatures {
        switch request.searchType {
        case .photo:
            return try await extractImageFeatures(request.imageData)
        case .sketch:
            return try await extractSketchFeatures(request.sketchData!)
        case .colorPalette:
            return try await extractColorFeatures(request.colorData!)
        case .multiItem:
            return try await extractMultiItemFeatures(request.imageData)
        }
    }

    private func extractImageFeatures(_ imageData: Data?) async throws -> VisualFeatures {
        guard let imageData = imageData,
              let image = UIImage(data: imageData) else {
            throw VisualSearchError.invalidImageData
        }

        return try await withCheckedThrowingContinuation { continuation in
            processImageForFeatures(image) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func extractSketchFeatures(_ sketchData: SketchData) async throws -> VisualFeatures {
        return VisualFeatures(
            colors: extractColorsFromSketch(sketchData),
            shapes: analyzeSketchShapes(sketchData),
            textures: analyzeSketchTextures(sketchData),
            style: inferStyleFromSketch(sketchData)
        )
    }

    private func extractColorFeatures(_ colorData: ColorPaletteData) async throws -> VisualFeatures {
        let dominantColors = colorData.colors.map { ColorInfo(hex: $0, prominence: 1.0 / Double(colorData.colors.count)) }

        return VisualFeatures(
            colors: ColorFeatures(
                dominantColors: dominantColors,
                colorHarmony: analyzeColorHarmony(dominantColors),
                temperature: determineColorTemperature(dominantColors)
            ),
            shapes: ShapeFeatures(silhouette: .unknown, neckline: nil, sleeves: nil),
            textures: TextureFeatures(smoothness: 0.5, pattern: .solid, complexity: 0.3),
            style: StyleFeatures(category: .casual, mood: .neutral, season: .allSeason)
        )
    }

    private func extractMultiItemFeatures(_ imageData: Data?) async throws -> VisualFeatures {
        guard let imageData = imageData,
              let image = UIImage(data: imageData) else {
            throw VisualSearchError.invalidImageData
        }

        let detectedItems = try await detectMultipleItems(in: image)
        return combineFeatures(from: detectedItems)
    }

    private func processImageForFeatures(_ image: UIImage, completion: @escaping (Result<VisualFeatures, Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(VisualSearchError.invalidImageData))
            return
        }

        let colors = extractDominantColors(from: image)
        let shapes = analyzeImageShapes(cgImage)
        let textures = analyzeImageTextures(cgImage)
        let style = inferStyleFromImage(image)

        let features = VisualFeatures(
            colors: colors,
            shapes: shapes,
            textures: textures,
            style: style
        )

        completion(.success(features))
    }

    private func extractDominantColors(from image: UIImage) -> ColorFeatures {
        let colorAnalyzer = ColorAnalyzer()
        return colorAnalyzer.extractColors(from: image)
    }

    private func analyzeImageShapes(_ cgImage: CGImage) -> ShapeFeatures {
        let shapeAnalyzer = ShapeAnalyzer()
        return shapeAnalyzer.analyzeShapes(in: cgImage)
    }

    private func analyzeImageTextures(_ cgImage: CGImage) -> TextureFeatures {
        let textureAnalyzer = TextureAnalyzer()
        return textureAnalyzer.analyzeTextures(in: cgImage)
    }

    private func inferStyleFromImage(_ image: UIImage) -> StyleFeatures {
        let styleAnalyzer = StyleAnalyzer()
        return styleAnalyzer.inferStyle(from: image)
    }

    private func extractColorsFromSketch(_ sketchData: SketchData) -> ColorFeatures {
        let colors = sketchData.strokes.compactMap { stroke in
            ColorInfo(hex: stroke.color, prominence: stroke.thickness / 10.0)
        }

        return ColorFeatures(
            dominantColors: colors,
            colorHarmony: .complementary,
            temperature: .neutral
        )
    }

    private func analyzeSketchShapes(_ sketchData: SketchData) -> ShapeFeatures {
        let pathAnalyzer = SketchPathAnalyzer()
        return pathAnalyzer.analyzeShapes(in: sketchData)
    }

    private func analyzeSketchTextures(_ sketchData: SketchData) -> TextureFeatures {
        let complexity = Double(sketchData.strokes.count) / 50.0
        let smoothness = sketchData.strokes.reduce(0.0) { $0 + $1.smoothness } / Double(sketchData.strokes.count)

        return TextureFeatures(
            smoothness: smoothness,
            pattern: complexity > 0.5 ? .geometric : .solid,
            complexity: min(1.0, complexity)
        )
    }

    private func inferStyleFromSketch(_ sketchData: SketchData) -> StyleFeatures {
        return StyleFeatures(
            category: .casual,
            mood: .creative,
            season: .allSeason
        )
    }

    private func analyzeColorHarmony(_ colors: [ColorInfo]) -> ColorHarmony {
        guard colors.count >= 2 else { return .monochromatic }

        return .complementary
    }

    private func determineColorTemperature(_ colors: [ColorInfo]) -> ColorTemperature {
        return .neutral
    }

    private func detectMultipleItems(in image: UIImage) async throws -> [DetectedItem] {
        guard let cgImage = image.cgImage else {
            throw VisualSearchError.invalidImageData
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRectangleObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let detectedItems = observations.map { observation in
                    DetectedItem(
                        bounds: observation.boundingBox,
                        confidence: Double(observation.confidence),
                        type: .clothing
                    )
                }

                continuation.resume(returning: detectedItems)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    private func combineFeatures(from items: [DetectedItem]) -> VisualFeatures {
        return VisualFeatures(
            colors: ColorFeatures(dominantColors: [], colorHarmony: .monochromatic, temperature: .neutral),
            shapes: ShapeFeatures(silhouette: .fitted, neckline: nil, sleeves: nil),
            textures: TextureFeatures(smoothness: 0.5, pattern: .solid, complexity: 0.3),
            style: StyleFeatures(category: .casual, mood: .neutral, season: .allSeason)
        )
    }

    private func findSimilarProducts(features: VisualFeatures) async -> [ProductMatch] {
        return [
            ProductMatch(
                products: sampleProducts(),
                confidence: 0.85
            )
        ]
    }

    private func sampleProducts() -> [Product] {
        return [
            Product(
                id: "1",
                name: "Sample Product",
                imageURL: URL(string: "https://example.com/product.jpg")!,
                price: 29.99,
                brand: "Sample Brand"
            )
        ]
    }

    private func generateCacheKey(for request: VisualSearchRequest) -> String {
        var hasher = Hasher()

        if let imageData = request.imageData {
            hasher.combine(imageData)
        }
        hasher.combine(request.searchType.rawValue)

        return String(hasher.finalize())
    }

    private func saveToHistory(_ item: VisualSearchHistoryItem) async {
        searchHistory.append(item)

        if searchHistory.count > 100 {
            searchHistory.removeFirst(searchHistory.count - 100)
        }

        await cacheManager.saveSearchHistory(searchHistory)
    }
}

extension VisualSearchCameraView.SearchMode {
    var searchType: VisualSearchType {
        switch self {
        case .photoSearch: return .photo
        case .sketchSearch: return .sketch
        case .colorPalette: return .colorPalette
        case .multiItem: return .multiItem
        }
    }
}

struct VisualSearchRequest {
    let imageData: Data?
    let sketchData: SketchData?
    let colorData: ColorPaletteData?
    let searchType: VisualSearchType
    let privacySettings: PrivacySettings

    init(imageData: Data, searchType: VisualSearchType, privacySettings: PrivacySettings) {
        self.imageData = imageData
        self.sketchData = nil
        self.colorData = nil
        self.searchType = searchType
        self.privacySettings = privacySettings
    }

    init(sketchData: SketchData, searchType: VisualSearchType, privacySettings: PrivacySettings) {
        self.imageData = nil
        self.sketchData = sketchData
        self.colorData = nil
        self.searchType = searchType
        self.privacySettings = privacySettings
    }

    init(colorData: ColorPaletteData, searchType: VisualSearchType, privacySettings: PrivacySettings) {
        self.imageData = nil
        self.sketchData = nil
        self.colorData = colorData
        self.searchType = searchType
        self.privacySettings = privacySettings
    }
}

enum VisualSearchType: String, CaseIterable {
    case photo = "photo"
    case sketch = "sketch"
    case colorPalette = "color_palette"
    case multiItem = "multi_item"
}

struct VisualFeatures {
    let colors: ColorFeatures
    let shapes: ShapeFeatures
    let textures: TextureFeatures
    let style: StyleFeatures
}

struct ColorFeatures {
    let dominantColors: [ColorInfo]
    let colorHarmony: ColorHarmony
    let temperature: ColorTemperature
}

struct ColorInfo {
    let hex: String
    let prominence: Double
}

enum ColorHarmony: String {
    case monochromatic, analogous, complementary, triadic, tetradic
}

enum ColorTemperature: String {
    case warm, cool, neutral
}

struct ShapeFeatures {
    let silhouette: Silhouette
    let neckline: Neckline?
    let sleeves: SleeveType?
}

enum Silhouette: String {
    case fitted, loose, oversized, tailored, unknown
}

enum Neckline: String {
    case round, vNeck, scoop, high, offShoulder
}

enum SleeveType: String {
    case short, long, sleeveless, threeQuarter, cap
}

struct TextureFeatures {
    let smoothness: Double
    let pattern: Pattern
    let complexity: Double
}

enum Pattern: String {
    case solid, striped, checkered, floral, geometric, abstract
}

struct StyleFeatures {
    let category: StyleCategory
    let mood: StyleMood
    let season: Season
}

enum StyleCategory: String {
    case casual, formal, sporty, bohemian, minimalist, vintage
}

enum StyleMood: String {
    case playful, elegant, edgy, romantic, professional, neutral, creative
}

enum Season: String {
    case spring, summer, fall, winter, allSeason
}

struct SketchData {
    let strokes: [SketchStroke]
    let bounds: CGRect
}

struct SketchStroke {
    let points: [CGPoint]
    let color: String
    let thickness: Double
    let smoothness: Double
}

struct ColorPaletteData {
    let colors: [String]
}

struct DetectedItem {
    let bounds: CGRect
    let confidence: Double
    let type: ItemType
}

enum ItemType: String {
    case clothing, accessory, jewelry, shoes, bag, watch
}

struct ProductMatch {
    let products: [Product]
    let confidence: Double
}

struct VisualSearchHistoryItem {
    let id: String
    let imageData: Data
    let searchType: String
    let results: [VisualSearchResult]
    let timestamp: Date
    let privacyCompliant: Bool
}

enum VisualSearchError: Error {
    case invalidImageData
    case networkError
    case privacyViolation
    case cacheError
}

extension UIColor {
    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        getRed(&r, green: &g, blue: &b, alpha: &a)

        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}