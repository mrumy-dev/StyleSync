import SwiftUI
import AVFoundation
import Photos

// MARK: - Main Content Creator View
struct ContentCreatorView: View {
    @StateObject private var creatorManager = ContentCreatorManager.shared
    @StateObject private var cameraManager = CameraManager()
    @Environment(\.theme) private var theme
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedCreationType: CreationType = .photo
    @State private var showingEditor = false
    @State private var capturedMedia: CapturedMedia?

    var body: some View {
        NavigationView {
            ZStack {
                // Camera Preview
                CameraPreviewView(cameraManager: cameraManager)
                    .ignoresSafeArea()

                // Overlay UI
                VStack {
                    // Top Controls
                    ContentCreatorTopBar(
                        cameraManager: cameraManager,
                        selectedType: $selectedCreationType,
                        onClose: {
                            presentationMode.wrappedValue.dismiss()
                        }
                    )

                    Spacer()

                    // Bottom Controls
                    ContentCreatorBottomBar(
                        cameraManager: cameraManager,
                        selectedType: selectedCreationType,
                        onCapture: { media in
                            capturedMedia = media
                            showingEditor = true
                        }
                    )
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
        .fullScreenCover(isPresented: $showingEditor) {
            if let media = capturedMedia {
                ContentEditorView(capturedMedia: media, creationType: selectedCreationType)
            }
        }
        .onAppear {
            cameraManager.requestPermissions()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
}

// MARK: - Creation Types
enum CreationType: String, CaseIterable {
    case photo = "photo"
    case video = "video"
    case story = "story"
    case reel = "reel"
    case outfit = "outfit"
    case beforeAfter = "before_after"
    case timelapse = "timelapse"
    case boomerang = "boomerang"

    var displayName: String {
        switch self {
        case .photo: return "Photo"
        case .video: return "Video"
        case .story: return "Story"
        case .reel: return "Reel"
        case .outfit: return "Outfit"
        case .beforeAfter: return "Before/After"
        case .timelapse: return "Timelapse"
        case .boomerang: return "Boomerang"
        }
    }

    var icon: String {
        switch self {
        case .photo: return "camera"
        case .video: return "video"
        case .story: return "circle.dashed"
        case .reel: return "play.rectangle"
        case .outfit: return "tshirt"
        case .beforeAfter: return "arrow.left.arrow.right"
        case .timelapse: return "clock.arrow.circlepath"
        case .boomerang: return "repeat"
        }
    }

    var maxDuration: TimeInterval? {
        switch self {
        case .story: return 15
        case .reel: return 60
        case .timelapse: return 10
        case .boomerang: return 3
        default: return nil
        }
    }
}

// MARK: - Captured Media
struct CapturedMedia {
    let type: MediaType
    let data: Data?
    let url: URL?
    let thumbnail: UIImage?

    enum MediaType {
        case image(UIImage)
        case video(URL)
    }
}

// MARK: - Content Creator Top Bar
struct ContentCreatorTopBar: View {
    let cameraManager: CameraManager
    @Binding var selectedType: CreationType
    let onClose: () -> Void
    @Environment(\.theme) private var theme
    @State private var showingTypeSelector = false

    var body: some View {
        HStack {
            // Close Button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(Circle().fill(.ultraThinMaterial))
            }

            Spacer()

            // Creation Type Selector
            Button {
                showingTypeSelector = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: selectedType.icon)
                        .font(.caption)
                    Text(selectedType.displayName)
                        .typography(.caption1, theme: .system)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(.ultraThinMaterial))
            }

            Spacer()

            // Camera Controls
            VStack(spacing: 8) {
                // Flash Toggle
                Button {
                    cameraManager.toggleFlash()
                } label: {
                    Image(systemName: flashIcon)
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Circle().fill(.ultraThinMaterial))
                }

                // Camera Flip
                Button {
                    cameraManager.flipCamera()
                } label: {
                    Image(systemName: "camera.rotate")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Circle().fill(.ultraThinMaterial))
                }
            }
        }
        .padding()
        .actionSheet(isPresented: $showingTypeSelector) {
            ActionSheet(
                title: Text("Content Type"),
                buttons: CreationType.allCases.map { type in
                    .default(Text(type.displayName)) {
                        selectedType = type
                    }
                } + [.cancel()]
            )
        }
    }

    private var flashIcon: String {
        switch cameraManager.flashMode {
        case .off: return "bolt.slash"
        case .on: return "bolt"
        case .auto: return "bolt.badge.a"
        @unknown default: return "bolt"
        }
    }
}

// MARK: - Content Creator Bottom Bar
struct ContentCreatorBottomBar: View {
    let cameraManager: CameraManager
    let selectedType: CreationType
    let onCapture: (CapturedMedia) -> Void
    @Environment(\.theme) private var theme
    @State private var isRecording = false
    @State private var recordingProgress: Double = 0
    @State private var recordingTimer: Timer?

    var body: some View {
        HStack(spacing: 40) {
            // Gallery Button
            Button {
                // Open photo library
            } label: {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "photo.on.rectangle")
                            .foregroundColor(.white)
                    )
            }

            // Capture Button
            CaptureButton(
                creationType: selectedType,
                isRecording: $isRecording,
                recordingProgress: recordingProgress,
                onTap: handleCapture,
                onLongPress: handleLongPress
            )

            // Filters/Effects Button
            NavigationLink(destination: FilterMarketplaceView()) {
                Image(systemName: "camera.filters")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.ultraThinMaterial))
            }
        }
        .padding(.bottom, 40)
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            if isRecording, let maxDuration = selectedType.maxDuration {
                recordingProgress += 0.1 / maxDuration
                if recordingProgress >= 1.0 {
                    stopRecording()
                }
            }
        }
    }

    private func handleCapture() {
        switch selectedType {
        case .photo, .outfit:
            capturePhoto()
        case .story, .reel:
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        case .beforeAfter:
            captureBeforeAfter()
        case .boomerang:
            captureBoomerang()
        case .timelapse:
            captureTimelapse()
        default:
            capturePhoto()
        }
    }

    private func handleLongPress() {
        switch selectedType {
        case .photo:
            // Start video recording on long press
            startRecording()
        default:
            break
        }
    }

    private func capturePhoto() {
        cameraManager.capturePhoto { image in
            let media = CapturedMedia(
                type: .image(image),
                data: image.jpegData(compressionQuality: 0.9),
                url: nil,
                thumbnail: image
            )
            onCapture(media)
        }
    }

    private func startRecording() {
        isRecording = true
        recordingProgress = 0
        cameraManager.startRecording()
    }

    private func stopRecording() {
        isRecording = false
        recordingProgress = 0
        recordingTimer?.invalidate()

        cameraManager.stopRecording { url in
            let media = CapturedMedia(
                type: .video(url),
                data: nil,
                url: url,
                thumbnail: generateVideoThumbnail(url)
            )
            onCapture(media)
        }
    }

    private func captureBeforeAfter() {
        // Would capture two photos in sequence
        capturePhoto()
    }

    private func captureBoomerang() {
        // Would capture short video and create boomerang effect
        startRecording()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            stopRecording()
        }
    }

    private func captureTimelapse() {
        // Would capture timelapse video
        startRecording()
    }

    private func generateVideoThumbnail(_ url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}

// MARK: - Capture Button
struct CaptureButton: View {
    let creationType: CreationType
    @Binding var isRecording: Bool
    let recordingProgress: Double
    let onTap: () -> Void
    let onLongPress: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            onTap()
        } label: {
            ZStack {
                // Outer Ring (Progress for video)
                if creationType != .photo && creationType != .outfit {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 6)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: recordingProgress)
                        .stroke(
                            LinearGradient(
                                colors: [theme.colors.primary, theme.colors.accent1],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: recordingProgress)
                }

                // Inner Button
                Circle()
                    .fill(isRecording ? Color.red : Color.white)
                    .frame(width: isRecording ? 40 : 70, height: isRecording ? 40 : 70)
                    .scaleEffect(isRecording ? 0.8 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isRecording)

                // Recording indicator
                if isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isRecording ? 1.1 : 1.0)
        .onLongPressGesture(minimumDuration: 0.5) {
            onLongPress()
        }
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: CameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        if let previewLayer = cameraManager.previewLayer {
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = cameraManager.previewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}

// MARK: - Camera Manager
class CameraManager: NSObject, ObservableObject {
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    @Published var isSessionRunning = false

    private let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var videoOutput = AVCaptureMovieFileOutput()
    private var currentCamera: AVCaptureDevice?
    private var photoCompletion: ((UIImage) -> Void)?
    private var videoCompletion: ((URL) -> Void)?

    lazy var previewLayer: AVCaptureVideoPreviewLayer? = {
        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.videoGravity = .resizeAspectFill
        return preview
    }()

    override init() {
        super.init()
        setupCaptureSession()
    }

    func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.startSession()
                }
            }
        }
    }

    private func setupCaptureSession() {
        captureSession.sessionPreset = .photo

        // Add camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        currentCamera = camera

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }

            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }

        } catch {
            print("Camera setup error: \(error)")
        }
    }

    func startSession() {
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = true
                }
            }
        }
    }

    func stopSession() {
        if captureSession.isRunning {
            captureSession.stopRunning()
            isSessionRunning = false
        }
    }

    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        photoCompletion = completion

        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func startRecording() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let fileUrl = paths[0].appendingPathComponent("video_\(Date().timeIntervalSince1970).mov")
        videoOutput.startRecording(to: fileUrl, recordingDelegate: self)
    }

    func stopRecording(completion: @escaping (URL) -> Void) {
        videoCompletion = completion
        videoOutput.stopRecording()
    }

    func toggleFlash() {
        switch flashMode {
        case .off:
            flashMode = .on
        case .on:
            flashMode = .auto
        case .auto:
            flashMode = .off
        @unknown default:
            flashMode = .off
        }
    }

    func flipCamera() {
        captureSession.beginConfiguration()

        // Remove current input
        if let input = captureSession.inputs.first as? AVCaptureDeviceInput {
            captureSession.removeInput(input)
        }

        // Switch camera position
        cameraPosition = cameraPosition == .back ? .front : .back

        // Add new input
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) else {
            captureSession.commitConfiguration()
            return
        }

        currentCamera = newCamera

        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            if captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)
            }
        } catch {
            print("Error switching camera: \(error)")
        }

        captureSession.commitConfiguration()
    }
}

// MARK: - Camera Delegates
extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { return }

        DispatchQueue.main.async {
            self.photoCompletion?(image)
            self.photoCompletion = nil
        }
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            if error == nil {
                self.videoCompletion?(outputFileURL)
            }
            self.videoCompletion = nil
        }
    }
}

// MARK: - Filter Marketplace View (Placeholder)
struct FilterMarketplaceView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationView {
            ScrollView {
                Text("Filter Marketplace")
                    .typography(.heading2, theme: .modern)
                    .foregroundColor(theme.colors.onSurface)
                    .padding()

                Text("Premium filters and effects coming soon!")
                    .typography(.body1, theme: .system)
                    .foregroundColor(theme.colors.onSurfaceVariant)
            }
            .navigationTitle("Filters")
        }
    }
}