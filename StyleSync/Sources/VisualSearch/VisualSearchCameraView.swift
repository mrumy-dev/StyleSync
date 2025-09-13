import SwiftUI
import AVFoundation
import Vision
import Combine

struct VisualSearchCameraView: View {
    @StateObject private var cameraManager = VisualSearchCameraManager()
    @StateObject private var searchEngine = VisualSearchEngine()
    @State private var showingResults = false
    @State private var searchResults: [VisualSearchResult] = []
    @State private var isSearching = false
    @State private var showingSettings = false
    @State private var selectedSearchMode: SearchMode = .photoSearch

    enum SearchMode: CaseIterable {
        case photoSearch
        case sketchSearch
        case colorPalette
        case multiItem

        var title: String {
            switch self {
            case .photoSearch: return "Photo Search"
            case .sketchSearch: return "Sketch Search"
            case .colorPalette: return "Color Search"
            case .multiItem: return "Multi-Item"
            }
        }

        var icon: String {
            switch self {
            case .photoSearch: return "camera.fill"
            case .sketchSearch: return "pencil.and.outline"
            case .colorPalette: return "paintpalette.fill"
            case .multiItem: return "rectangle.3.group.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()

            VisualSearchOverlayView(
                detections: cameraManager.detections,
                isSearching: isSearching,
                searchMode: selectedSearchMode
            )

            VStack {
                TopControlsView(
                    selectedMode: $selectedSearchMode,
                    onSettingsTapped: { showingSettings = true },
                    privacyMetrics: cameraManager.privacyMetrics
                )

                Spacer()

                BottomControlsView(
                    isSearching: isSearching,
                    searchMode: selectedSearchMode,
                    onCapture: { captureAndSearch() },
                    onSketchMode: { selectedSearchMode = .sketchSearch },
                    onColorMode: { selectedSearchMode = .colorPalette }
                )
            }
        }
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .sheet(isPresented: $showingResults) {
            VisualSearchResultsView(results: searchResults)
        }
        .sheet(isPresented: $showingSettings) {
            VisualSearchSettingsView(cameraManager: cameraManager)
        }
        .alert("Privacy Alert", isPresented: .constant(cameraManager.privacyViolationDetected)) {
            Button("OK") {
                cameraManager.privacyViolationDetected = false
            }
        } message: {
            Text("Potential privacy concern detected. Face blurring applied automatically.")
        }
    }

    private func captureAndSearch() {
        guard !isSearching else { return }

        isSearching = true

        cameraManager.capturePhoto { result in
            switch result {
            case .success(let imageData):
                Task {
                    await performSearch(with: imageData)
                }
            case .failure(let error):
                print("Capture failed: \(error)")
                isSearching = false
            }
        }
    }

    @MainActor
    private func performSearch(with imageData: Data) async {
        do {
            let results = try await searchEngine.searchByPhoto(
                imageData: imageData,
                mode: selectedSearchMode,
                privacySettings: cameraManager.privacySettings
            )

            searchResults = results
            showingResults = true
        } catch {
            print("Search failed: \(error)")
        }

        isSearching = false
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: VisualSearchCameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView()

        DispatchQueue.main.async {
            if let previewLayer = cameraManager.previewLayer {
                previewLayer.frame = view.bounds
                view.layer.addSublayer(previewLayer)
            }
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let previewLayer = cameraManager.previewLayer {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

struct VisualSearchOverlayView: View {
    let detections: [DetectionBox]
    let isSearching: Bool
    let searchMode: VisualSearchCameraView.SearchMode

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(detections, id: \.id) { detection in
                    DetectionBoxView(
                        detection: detection,
                        frameSize: geometry.size
                    )
                }

                if isSearching {
                    SearchingOverlayView()
                }

                SearchModeIndicatorView(mode: searchMode)
            }
        }
    }
}

struct DetectionBoxView: View {
    let detection: DetectionBox
    let frameSize: CGSize

    private var boxFrame: CGRect {
        CGRect(
            x: detection.bounds.x * frameSize.width,
            y: detection.bounds.y * frameSize.height,
            width: detection.bounds.width * frameSize.width,
            height: detection.bounds.height * frameSize.height
        )
    }

    var body: some View {
        Rectangle()
            .stroke(detection.confidence > 0.7 ? Color.green : Color.yellow, lineWidth: 2)
            .frame(width: boxFrame.width, height: boxFrame.height)
            .position(x: boxFrame.midX, y: boxFrame.midY)
            .overlay(
                VStack {
                    Text(detection.label)
                        .font(.caption)
                        .padding(4)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(4)

                    Text("\(Int(detection.confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(2)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(2)
                }
                .position(x: boxFrame.midX, y: boxFrame.minY - 20),
                alignment: .top
            )
    }
}

struct TopControlsView: View {
    @Binding var selectedMode: VisualSearchCameraView.SearchMode
    let onSettingsTapped: () -> Void
    let privacyMetrics: PrivacyMetrics?

    var body: some View {
        HStack {
            Button(action: onSettingsTapped) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }

            SearchModePickerView(selectedMode: $selectedMode)

            Spacer()

            PrivacyIndicatorView(metrics: privacyMetrics)
        }
        .padding()
    }
}

struct SearchModePickerView: View {
    @Binding var selectedMode: VisualSearchCameraView.SearchMode

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(VisualSearchCameraView.SearchMode.allCases, id: \.self) { mode in
                    Button(action: { selectedMode = mode }) {
                        VStack(spacing: 4) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 16, weight: .medium))
                            Text(mode.title)
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundColor(selectedMode == mode ? .black : .white)
                        .background(
                            selectedMode == mode ?
                            Color.white.opacity(0.9) :
                            Color.black.opacity(0.3)
                        )
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct PrivacyIndicatorView: View {
    let metrics: PrivacyMetrics?

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "lock.shield.fill")
                .font(.caption)
                .foregroundColor(.green)

            if let metrics = metrics {
                Text("Budget: \(Int(metrics.privacyBudgetRemaining * 100))%")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }
}

struct SearchingOverlayView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 4)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: isAnimating ? 1 : 0)
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
            }

            Text("Searching...")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
        .onAppear {
            isAnimating = true
        }
    }
}

struct SearchModeIndicatorView: View {
    let mode: VisualSearchCameraView.SearchMode

    var body: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: mode.icon)
                        .font(.title2)
                        .foregroundColor(.white)

                    Text(mode.title)
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(12)
                .padding(.trailing)
                .padding(.bottom, 100)
            }
        }
    }
}

struct BottomControlsView: View {
    let isSearching: Bool
    let searchMode: VisualSearchCameraView.SearchMode
    let onCapture: () -> Void
    let onSketchMode: () -> Void
    let onColorMode: () -> Void

    var body: some View {
        HStack(spacing: 40) {
            Button(action: onSketchMode) {
                Image(systemName: "pencil.and.outline")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }

            Button(action: onCapture) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)

                    if isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    } else {
                        Circle()
                            .stroke(Color.black, lineWidth: 3)
                            .frame(width: 60, height: 60)
                    }
                }
            }
            .disabled(isSearching)

            Button(action: onColorMode) {
                Image(systemName: "paintpalette.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
        }
        .padding(.bottom, 40)
    }
}

struct DetectionBox {
    let id: String
    let type: String
    let bounds: CGRect
    let confidence: Double
    let label: String
}

struct VisualSearchResult {
    let id: String
    let products: [Product]
    let confidence: Double
    let searchType: String
}

struct Product {
    let id: String
    let name: String
    let imageURL: URL
    let price: Double
    let brand: String
}

struct PrivacyMetrics {
    let privacyBudgetRemaining: Double
    let onDeviceProcessingOnly: Bool
    let encryptionEnabled: Bool
    let faceBlurringEnabled: Bool
}

#Preview {
    VisualSearchCameraView()
}