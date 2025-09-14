import SwiftUI
import AVFoundation
import Vision
import CoreImage
import PhotosUI

struct ProCameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var aiCaptureAssistant = AICaptureAssistant()
    @State private var selectedFilter: CameraFilter = .none
    @State private var isGridVisible = false
    @State private var zoomFactor: CGFloat = 1.0
    @State private var isBatchCapturing = false
    @State private var captureCount = 0
    @State private var showingPhotoEdit = false
    @State private var capturedImage: UIImage?
    @State private var isRecording = false
    @State private var focusPoint: CGPoint?
    @State private var exposurePoint: CGPoint?

    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()
                .scaleEffect(zoomFactor)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                                zoomFactor = max(1.0, min(value * cameraManager.baseZoom, 10.0))
                            }
                        }
                        .onEnded { value in
                            cameraManager.setZoom(zoomFactor)
                        }
                )
                .onTapGesture { location in
                    focusAndExpose(at: location)
                }

            // AI Overlay Elements
            if aiCaptureAssistant.isClothingDetected {
                ClothingDetectionOverlay(
                    boundingBoxes: aiCaptureAssistant.clothingBounds,
                    suggestions: aiCaptureAssistant.smartCropSuggestions
                )
            }

            // Grid Overlay
            if isGridVisible {
                GridOverlay()
            }

            // Focus Indicator
            if let focusPoint = focusPoint {
                FocusIndicator(point: focusPoint)
                    .transition(.scale.combined(with: .opacity))
            }

            // Top Controls
            VStack {
                HStack {
                    // Flash Control
                    FlashButton(flashMode: $cameraManager.flashMode)

                    Spacer()

                    // Grid Toggle
                    GridToggleButton(isGridVisible: $isGridVisible)

                    // Filter Selection
                    FilterButton(selectedFilter: $selectedFilter)
                }
                .padding(.horizontal)
                .padding(.top)

                Spacer()

                // Bottom Controls
                CameraBottomControls(
                    cameraManager: cameraManager,
                    isBatchCapturing: $isBatchCapturing,
                    captureCount: $captureCount,
                    onCapture: { image in
                        capturedImage = image
                        showingPhotoEdit = true
                    }
                )
            }

            // AI Assistance UI
            if aiCaptureAssistant.showingGuidance {
                AIGuidanceOverlay(assistant: aiCaptureAssistant)
            }

            // Quality Assessment
            if let qualityScore = aiCaptureAssistant.currentQualityScore {
                QualityIndicator(score: qualityScore)
                    .position(x: UIScreen.main.bounds.width - 60, y: 120)
            }
        }
        .onAppear {
            setupCamera()
        }
        .sheet(isPresented: $showingPhotoEdit) {
            if let image = capturedImage {
                PhotoEditView(image: image) { editedImage in
                    // Save edited image
                    saveToPhotoLibrary(editedImage)
                    capturedImage = nil
                }
            }
        }
        .onChange(of: selectedFilter) { filter in
            cameraManager.applyFilter(filter)
        }
    }

    private func setupCamera() {
        cameraManager.requestPermissions()
        cameraManager.startSession()
        aiCaptureAssistant.start()
    }

    private func focusAndExpose(at point: CGPoint) {
        cameraManager.focus(at: point)
        cameraManager.expose(at: point)

        withAnimation(.easeInOut(duration: 0.3)) {
            focusPoint = point
        }

        HapticManager.HapticType.subtleNudge.trigger()
        SoundManager.SoundType.subtleBeep.play(volume: 0.3)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                focusPoint = nil
            }
        }
    }

    private func saveToPhotoLibrary(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        HapticManager.HapticType.success.trigger()
        SoundManager.SoundType.success.play(volume: 0.6)
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: CameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        cameraManager.previewLayer.frame = view.layer.bounds
        cameraManager.previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(cameraManager.previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        cameraManager.previewLayer.frame = uiView.bounds
    }
}

// MARK: - Camera Manager

@MainActor
class CameraManager: NSObject, ObservableObject {
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var isCapturing = false

    private let session = AVCaptureSession()
    let previewLayer = AVCaptureVideoPreviewLayer()
    private var photoOutput = AVCapturePhotoOutput()
    private var videoOutput = AVCaptureVideoDataOutput()
    private var currentCamera: AVCaptureDevice?
    var baseZoom: CGFloat = 1.0

    private var photoCompletion: ((UIImage?) -> Void)?

    override init() {
        super.init()
        previewLayer.session = session
    }

    func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    self.configureSession()
                }
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        // Add camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            session.commitConfiguration()
            return
        }

        currentCamera = camera
        if session.canAddInput(input) {
            session.addInput(input)
        }

        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.maxPhotoQualityPrioritization = .quality
        }

        // Add video output for AI processing
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.video.queue"))
        }

        session.commitConfiguration()
    }

    func startSession() {
        DispatchQueue.global(qos: .background).async {
            self.session.startRunning()
        }
    }

    func stopSession() {
        session.stopRunning()
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        photoCompletion = completion
        isCapturing = true

        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        settings.isHighResolutionPhotoEnabled = true

        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settings.photoCodecType = .hevc
        }

        photoOutput.capturePhoto(with: settings, delegate: self)

        HapticManager.HapticType.cameraShutter.trigger()
        SoundManager.SoundType.cameraShutter.play(volume: 0.8)
    }

    func setZoom(_ factor: CGFloat) {
        guard let camera = currentCamera else { return }

        do {
            try camera.lockForConfiguration()
            camera.videoZoomFactor = min(factor, camera.activeFormat.videoMaxZoomFactor)
            camera.unlockForConfiguration()
            baseZoom = factor
        } catch {
            print("Error setting zoom: \(error)")
        }
    }

    func focus(at point: CGPoint) {
        guard let camera = currentCamera else { return }

        do {
            try camera.lockForConfiguration()
            if camera.isFocusPointOfInterestSupported {
                camera.focusPointOfInterest = point
                camera.focusMode = .autoFocus
            }
            camera.unlockForConfiguration()
        } catch {
            print("Error setting focus: \(error)")
        }
    }

    func expose(at point: CGPoint) {
        guard let camera = currentCamera else { return }

        do {
            try camera.lockForConfiguration()
            if camera.isExposurePointOfInterestSupported {
                camera.exposurePointOfInterest = point
                camera.exposureMode = .autoExpose
            }
            camera.unlockForConfiguration()
        } catch {
            print("Error setting exposure: \(error)")
        }
    }

    func applyFilter(_ filter: CameraFilter) {
        // Filter implementation would be added here
    }
}

// MARK: - Photo Capture Delegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        isCapturing = false

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            photoCompletion?(nil)
            return
        }

        photoCompletion?(image)
    }
}

// MARK: - Video Output Delegate for AI Processing

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // AI processing would happen here
        NotificationCenter.default.post(name: .newCameraFrame, object: sampleBuffer)
    }
}

extension Notification.Name {
    static let newCameraFrame = Notification.Name("newCameraFrame")
}

// MARK: - Camera Filters

enum CameraFilter: String, CaseIterable {
    case none = "None"
    case vintage = "Vintage"
    case blackAndWhite = "Black & White"
    case vivid = "Vivid"
    case portrait = "Portrait"
    case fashion = "Fashion"

    var displayName: String { rawValue }

    var ciFilter: CIFilter? {
        switch self {
        case .none:
            return nil
        case .vintage:
            return CIFilter(name: "CISepiaTone")
        case .blackAndWhite:
            return CIFilter(name: "CIColorMonochrome")
        case .vivid:
            return CIFilter(name: "CIVibrance")
        case .portrait:
            return CIFilter(name: "CIDepthOfField")
        case .fashion:
            return CIFilter(name: "CIColorControls")
        }
    }
}

// MARK: - UI Components

struct FlashButton: View {
    @Binding var flashMode: AVCaptureDevice.FlashMode

    var body: some View {
        Button(action: {
            switch flashMode {
            case .off: flashMode = .on
            case .on: flashMode = .auto
            case .auto: flashMode = .off
            @unknown default: flashMode = .off
            }
            HapticManager.HapticType.selection.trigger()
        }) {
            Image(systemName: flashIcon)
                .font(.title2)
                .foregroundStyle(.white)
                .padding(12)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    private var flashIcon: String {
        switch flashMode {
        case .off: return "bolt.slash"
        case .on: return "bolt"
        case .auto: return "bolt.badge.automatic"
        @unknown default: return "bolt.slash"
        }
    }
}

struct GridToggleButton: View {
    @Binding var isGridVisible: Bool

    var body: some View {
        Button(action: {
            isGridVisible.toggle()
            HapticManager.HapticType.selection.trigger()
        }) {
            Image(systemName: "grid")
                .font(.title2)
                .foregroundStyle(isGridVisible ? .yellow : .white)
                .padding(12)
                .background(.ultraThinMaterial, in: Circle())
        }
    }
}

struct FilterButton: View {
    @Binding var selectedFilter: CameraFilter

    var body: some View {
        Button(action: {
            // Show filter selection
            HapticManager.HapticType.selection.trigger()
        }) {
            Image(systemName: "camera.filters")
                .font(.title2)
                .foregroundStyle(.white)
                .padding(12)
                .background(.ultraThinMaterial, in: Circle())
        }
    }
}

struct GridOverlay: View {
    var body: some View {
        VStack {
            ForEach(0..<2) { _ in
                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(height: 1)
                Spacer()
            }
            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(height: 1)
        }
        .overlay(
            HStack {
                ForEach(0..<2) { _ in
                    Rectangle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 1)
                    Spacer()
                }
                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 1)
            }
        )
        .padding()
    }
}

struct FocusIndicator: View {
    let point: CGPoint

    var body: some View {
        Circle()
            .strokeBorder(.yellow, lineWidth: 2)
            .frame(width: 80, height: 80)
            .position(point)
            .animation(.easeInOut(duration: 0.3), value: point)
    }
}

struct CameraBottomControls: View {
    let cameraManager: CameraManager
    @Binding var isBatchCapturing: Bool
    @Binding var captureCount: Int
    let onCapture: (UIImage) -> Void

    @State private var batchTimer: Timer?

    var body: some View {
        HStack(spacing: 40) {
            // Gallery Access
            Button(action: {}) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "photo.stack")
                            .foregroundStyle(.black)
                    )
            }

            // Capture Button
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 80, height: 80)

                Circle()
                    .strokeBorder(.black, lineWidth: 4)
                    .frame(width: 65, height: 65)

                if isBatchCapturing {
                    Text("\(captureCount)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                }
            }
            .scaleEffect(isBatchCapturing ? 1.2 : 1.0)
            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: isBatchCapturing)
            .onTapGesture {
                capturePhoto()
            }
            .onLongPressGesture(
                minimumDuration: 0.5,
                maximumDistance: 50,
                pressing: { pressing in
                    if pressing {
                        startBatchCapture()
                    } else {
                        stopBatchCapture()
                    }
                },
                perform: {}
            )

            // Camera Switch
            Button(action: {}) {
                Image(systemName: "camera.rotate")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.bottom, 40)
    }

    private func capturePhoto() {
        cameraManager.capturePhoto { image in
            guard let image = image else { return }
            onCapture(image)
        }
    }

    private func startBatchCapture() {
        isBatchCapturing = true
        captureCount = 0
        HapticManager.HapticType.medium.trigger()

        batchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            capturePhoto()
            captureCount += 1
            HapticManager.HapticType.light.trigger()

            if captureCount >= 10 {
                stopBatchCapture()
            }
        }
    }

    private func stopBatchCapture() {
        isBatchCapturing = false
        batchTimer?.invalidate()
        batchTimer = nil
        HapticManager.HapticType.success.trigger()
    }
}

#Preview {
    ProCameraView()
}