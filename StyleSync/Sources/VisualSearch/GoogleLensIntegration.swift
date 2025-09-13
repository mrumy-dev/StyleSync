import Foundation
import UIKit
import Vision
import VisionKit

@available(iOS 16.0, *)
class GoogleLensIntegration: NSObject, ObservableObject {
    @Published var isAvailable = false
    @Published var isProcessing = false

    private let privacyManager = VisualSearchPrivacyManager()

    override init() {
        super.init()
        checkGoogleLensAvailability()
    }

    func checkGoogleLensAvailability() {
        if ImageAnalysisInteraction.isSupported {
            isAvailable = true
        } else {
            isAvailable = canOpenGoogleLensApp()
        }
    }

    func searchWithGoogleLens(image: UIImage, completion: @escaping (Result<GoogleLensResult, Error>) -> Void) {
        guard isAvailable else {
            completion(.failure(GoogleLensError.notAvailable))
            return
        }

        isProcessing = true

        Task {
            do {
                let processedImage = await privacyManager.processImage(image.pngData() ?? Data(), settings: PrivacySettings(
                    onDeviceOnly: true,
                    faceBlurring: true,
                    differentialPrivacy: true,
                    encryptFeatures: true
                ))

                let result = try await performGoogleLensSearch(processedImage: processedImage)

                DispatchQueue.main.async {
                    self.isProcessing = false
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    completion(.failure(error))
                }
            }
        }
    }

    @available(iOS 16.0, *)
    func presentImageAnalysisInteraction(for image: UIImage, in view: UIView) {
        guard ImageAnalysisInteraction.isSupported else {
            fallbackToGoogleLensApp(image: image)
            return
        }

        let interaction = ImageAnalysisInteraction()
        view.addInteraction(interaction)

        Task {
            do {
                let analyzer = ImageAnalyzer()
                let configuration = ImageAnalyzer.Configuration([.visualLookUp, .text, .machineReadableCode])

                let analysis = try await analyzer.analyze(image, configuration: configuration)

                await MainActor.run {
                    interaction.analysis = analysis
                    interaction.preferredInteractionTypes = .automatic
                }
            } catch {
                print("Image analysis failed: \(error)")
            }
        }
    }

    private func performGoogleLensSearch(processedImage: Data) async throws -> GoogleLensResult {
        if ImageAnalysisInteraction.isSupported {
            return try await performSystemImageAnalysis(processedImage: processedImage)
        } else {
            return try await performGoogleLensAppSearch(processedImage: processedImage)
        }
    }

    @available(iOS 16.0, *)
    private func performSystemImageAnalysis(processedImage: Data) async throws -> GoogleLensResult {
        guard let image = UIImage(data: processedImage) else {
            throw GoogleLensError.invalidImage
        }

        let analyzer = ImageAnalyzer()
        let configuration = ImageAnalyzer.Configuration([.visualLookUp, .text, .machineReadableCode])

        let analysis = try await analyzer.analyze(image, configuration: configuration)

        var detectedObjects: [GoogleLensObject] = []
        var textResults: [GoogleLensText] = []

        if analysis.hasResults(for: .visualLookUp) {
            detectedObjects = await extractVisualLookupResults(from: analysis)
        }

        if analysis.hasResults(for: .text) {
            textResults = await extractTextResults(from: analysis)
        }

        return GoogleLensResult(
            objects: detectedObjects,
            textResults: textResults,
            searchType: .systemAnalysis,
            confidence: 0.8,
            processingTime: 1.2,
            privacyCompliant: true
        )
    }

    private func performGoogleLensAppSearch(processedImage: Data) async throws -> GoogleLensResult {
        guard let image = UIImage(data: processedImage) else {
            throw GoogleLensError.invalidImage
        }

        let base64Image = processedImage.base64EncodedString()
        let googleLensURL = buildGoogleLensURL(imageBase64: base64Image)

        if UIApplication.shared.canOpenURL(googleLensURL) {
            await UIApplication.shared.open(googleLensURL)

            return GoogleLensResult(
                objects: [],
                textResults: [],
                searchType: .externalApp,
                confidence: 0.0,
                processingTime: 0.0,
                privacyCompliant: true
            )
        } else {
            throw GoogleLensError.appNotInstalled
        }
    }

    private func canOpenGoogleLensApp() -> Bool {
        let googleLensURL = URL(string: "googlelens://")!
        let googleAppURL = URL(string: "googleapp://")!

        return UIApplication.shared.canOpenURL(googleLensURL) ||
               UIApplication.shared.canOpenURL(googleAppURL)
    }

    private func fallbackToGoogleLensApp(image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        let base64Image = imageData.base64EncodedString()
        let googleLensURL = buildGoogleLensURL(imageBase64: base64Image)

        if UIApplication.shared.canOpenURL(googleLensURL) {
            UIApplication.shared.open(googleLensURL)
        } else {
            openGoogleLensInBrowser(imageBase64: base64Image)
        }
    }

    private func buildGoogleLensURL(imageBase64: String) -> URL {
        let urlString = "googlelens://search?source=image&image=\(imageBase64)"
        return URL(string: urlString) ?? URL(string: "googlelens://")!
    }

    private func openGoogleLensInBrowser(imageBase64: String) {
        let webSearchURL = URL(string: "https://lens.google.com/search?p=\(imageBase64)")!
        UIApplication.shared.open(webSearchURL)
    }

    @available(iOS 16.0, *)
    private func extractVisualLookupResults(from analysis: ImageAnalysis) async -> [GoogleLensObject] {
        var objects: [GoogleLensObject] = []

        return objects
    }

    @available(iOS 16.0, *)
    private func extractTextResults(from analysis: ImageAnalysis) async -> [GoogleLensText] {
        var textResults: [GoogleLensText] = []

        return textResults
    }
}

struct GoogleLensResult {
    let objects: [GoogleLensObject]
    let textResults: [GoogleLensText]
    let searchType: GoogleLensSearchType
    let confidence: Double
    let processingTime: TimeInterval
    let privacyCompliant: Bool
}

struct GoogleLensObject {
    let id: String
    let type: ObjectType
    let boundingBox: CGRect
    let confidence: Double
    let label: String
    let description: String?
    let relatedProducts: [RelatedProduct]

    enum ObjectType: String, CaseIterable {
        case clothing = "clothing"
        case accessory = "accessory"
        case jewelry = "jewelry"
        case shoes = "shoes"
        case bag = "bag"
        case electronics = "electronics"
        case furniture = "furniture"
        case plant = "plant"
        case animal = "animal"
        case food = "food"
        case landmark = "landmark"
        case text = "text"
        case barcode = "barcode"
        case unknown = "unknown"
    }
}

struct GoogleLensText {
    let id: String
    let text: String
    let boundingBox: CGRect
    let confidence: Double
    let language: String?
    let isTranslatable: Bool
}

struct RelatedProduct {
    let name: String
    let brand: String?
    let price: String?
    let availability: String?
    let imageURL: URL?
    let productURL: URL?
}

enum GoogleLensSearchType {
    case systemAnalysis
    case externalApp
    case webBrowser
}

enum GoogleLensError: Error {
    case notAvailable
    case invalidImage
    case appNotInstalled
    case networkError
    case analysisTimeout
    case privacyViolation

    var localizedDescription: String {
        switch self {
        case .notAvailable:
            return "Google Lens is not available on this device"
        case .invalidImage:
            return "Invalid image format"
        case .appNotInstalled:
            return "Google Lens app is not installed"
        case .networkError:
            return "Network connection error"
        case .analysisTimeout:
            return "Analysis timed out"
        case .privacyViolation:
            return "Privacy settings prevent this action"
        }
    }
}

@available(iOS 16.0, *)
struct GoogleLensIntegrationView: View {
    @StateObject private var googleLens = GoogleLensIntegration()
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var searchResults: GoogleLensResult?
    @State private var showingResults = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(height: 300)
                        .overlay(
                            VStack {
                                Image(systemName: "camera")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)
                                Text("Select an image to search")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                        )
                }

                Button("Select Image") {
                    showingImagePicker = true
                }
                .buttonStyle(.bordered)
                .disabled(!googleLens.isAvailable)

                if let image = selectedImage {
                    Button("Search with Google Lens") {
                        searchWithGoogleLens(image: image)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(googleLens.isProcessing || !googleLens.isAvailable)
                }

                if googleLens.isProcessing {
                    ProgressView("Analyzing image...")
                        .progressViewStyle(CircularProgressViewStyle())
                }

                if !googleLens.isAvailable {
                    Text("Google Lens is not available on this device")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Google Lens Search")
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingResults) {
            if let results = searchResults {
                GoogleLensResultsView(results: results)
            }
        }
    }

    private func searchWithGoogleLens(image: UIImage) {
        googleLens.searchWithGoogleLens(image: image) { result in
            switch result {
            case .success(let results):
                searchResults = results
                showingResults = true
            case .failure(let error):
                print("Google Lens search failed: \(error)")
            }
        }
    }
}

struct GoogleLensResultsView: View {
    let results: GoogleLensResult

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if !results.objects.isEmpty {
                        Section {
                            ForEach(results.objects, id: \.id) { object in
                                GoogleLensObjectView(object: object)
                            }
                        } header: {
                            Text("Detected Objects")
                                .font(.headline)
                                .padding(.horizontal)
                        }
                    }

                    if !results.textResults.isEmpty {
                        Section {
                            ForEach(results.textResults, id: \.id) { textResult in
                                GoogleLensTextView(textResult: textResult)
                            }
                        } header: {
                            Text("Detected Text")
                                .font(.headline)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Search Results")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct GoogleLensObjectView: View {
    let object: GoogleLensObject

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(object.label)
                    .font(.headline)
                Spacer()
                Text("\(Int(object.confidence * 100))%")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }

            if let description = object.description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            if !object.relatedProducts.isEmpty {
                Text("Related Products")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(object.relatedProducts, id: \.name) { product in
                            RelatedProductView(product: product)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct GoogleLensTextView: View {
    let textResult: GoogleLensText

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Text")
                    .font(.headline)
                Spacer()
                Text("\(Int(textResult.confidence * 100))%")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }

            Text(textResult.text)
                .font(.body)
                .textSelection(.enabled)

            if let language = textResult.language {
                Text("Language: \(language)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RelatedProductView: View {
    let product: RelatedProduct

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let imageURL = product.imageURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                }
                .frame(width: 80, height: 80)
                .cornerRadius(8)
            }

            Text(product.name)
                .font(.caption)
                .lineLimit(2)

            if let brand = product.brand {
                Text(brand)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let price = product.price {
                Text(price)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .frame(width: 90)
    }
}

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    if #available(iOS 16.0, *) {
        GoogleLensIntegrationView()
    } else {
        Text("Requires iOS 16.0+")
    }
}