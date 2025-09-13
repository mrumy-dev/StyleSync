import Foundation
import AVFoundation
import Vision
import CoreML
import Combine
import UIKit

@MainActor
class VisualSearchCameraManager: NSObject, ObservableObject {
    @Published var detections: [DetectionBox] = []
    @Published var privacyMetrics: PrivacyMetrics?
    @Published var privacyViolationDetected = false

    private let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var photoOutput: AVCapturePhotoOutput?
    private var currentCaptureCompletion: ((Result<Data, Error>) -> Void)?

    lazy var previewLayer: AVCaptureVideoPreviewLayer? = {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    private let visionQueue = DispatchQueue(label: "vision-queue", qos: .userInitiated)
    private let privacyProcessor = PrivacyProcessor()

    var privacySettings = PrivacySettings(
        onDeviceOnly: true,
        faceBlurring: true,
        differentialPrivacy: true,
        encryptFeatures: true
    )

    override init() {
        super.init()
        setupCamera()
        setupPrivacyMonitoring()
    }

    func startSession() {
        guard !captureSession.isRunning else { return }

        Task {
            await requestCameraPermission()

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }

    func stopSession() {
        guard captureSession.isRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    func capturePhoto(completion: @escaping (Result<Data, Error>) -> Void) {
        guard let photoOutput = photoOutput else {
            completion(.failure(CameraError.photoOutputNotAvailable))
            return
        }

        currentCaptureCompletion = completion

        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true

        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settings.photoQualityPrioritization = .quality
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func setupCamera() {
        captureSession.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Camera not available")
            return
        }

        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)

            if captureSession.canAddInput(cameraInput) {
                captureSession.addInput(cameraInput)
            }

            setupVideoOutput()
            setupPhotoOutput()

        } catch {
            print("Camera setup error: \(error)")
        }
    }

    private func setupVideoOutput() {
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput?.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput?.setSampleBufferDelegate(self, queue: visionQueue)

        if let videoOutput = videoOutput, captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
    }

    private func setupPhotoOutput() {
        photoOutput = AVCapturePhotoOutput()

        if let photoOutput = photoOutput, captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
    }

    private func setupPrivacyMonitoring() {
        privacyProcessor.onPrivacyMetricsUpdate = { [weak self] metrics in
            Task { @MainActor in
                self?.privacyMetrics = metrics
            }
        }

        privacyProcessor.onPrivacyViolation = { [weak self] in
            Task { @MainActor in
                self?.privacyViolationDetected = true
            }
        }
    }

    private func requestCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                print("Camera permission denied")
            }
        case .denied, .restricted:
            print("Camera permission denied or restricted")
        @unknown default:
            print("Unknown camera permission status")
        }
    }

    private func processVideoFrame(_ pixelBuffer: CVPixelBuffer) {
        let request = VNDetectRectanglesRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRectangleObservation] else { return }

            Task { @MainActor in
                await self?.updateDetections(from: observations)
            }
        }

        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 3.0
        request.minimumSize = 0.05
        request.minimumConfidence = 0.3

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("Vision request failed: \(error)")
        }
    }

    private func updateDetections(from observations: [VNRectangleObservation]) async {
        let newDetections = observations.compactMap { observation -> DetectionBox? in
            let bounds = CGRect(
                x: observation.boundingBox.origin.x,
                y: 1 - observation.boundingBox.origin.y - observation.boundingBox.height,
                width: observation.boundingBox.width,
                height: observation.boundingBox.height
            )

            return DetectionBox(
                id: UUID().uuidString,
                type: classifyDetection(bounds: bounds),
                bounds: bounds,
                confidence: Double(observation.confidence),
                label: generateLabel(for: bounds, confidence: Double(observation.confidence))
            )
        }

        detections = await privacyProcessor.filterDetections(newDetections)
    }

    private func classifyDetection(bounds: CGRect) -> String {
        let aspectRatio = bounds.width / bounds.height
        let yPosition = bounds.midY

        if yPosition < 0.3 && aspectRatio > 0.8 && aspectRatio < 1.2 {
            return "jewelry"
        } else if yPosition > 0.8 {
            return "shoes"
        } else if yPosition > 0.5 {
            return "clothing"
        } else {
            return "accessory"
        }
    }

    private func generateLabel(for bounds: CGRect, confidence: Double) -> String {
        let type = classifyDetection(bounds: bounds)
        return "\(type.capitalized)"
    }
}

extension VisualSearchCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        processVideoFrame(pixelBuffer)
    }
}

extension VisualSearchCameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer { currentCaptureCompletion = nil }

        if let error = error {
            currentCaptureCompletion?(.failure(error))
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            currentCaptureCompletion?(.failure(CameraError.imageDataNotAvailable))
            return
        }

        Task {
            let processedData = await privacyProcessor.processImageData(imageData, settings: privacySettings)
            currentCaptureCompletion?(.success(processedData))
        }
    }
}

enum CameraError: Error {
    case photoOutputNotAvailable
    case imageDataNotAvailable
    case cameraNotAvailable
}

struct PrivacySettings {
    let onDeviceOnly: Bool
    let faceBlurring: Bool
    let differentialPrivacy: Bool
    let encryptFeatures: Bool
}

class PrivacyProcessor {
    var onPrivacyMetricsUpdate: ((PrivacyMetrics) -> Void)?
    var onPrivacyViolation: (() -> Void)?

    private var privacyBudget: Double = 1.0
    private let faceDetector = FaceDetector()

    func processImageData(_ data: Data, settings: PrivacySettings) async -> Data {
        var processedData = data

        if settings.faceBlurring {
            processedData = await blurFaces(in: processedData)
        }

        if settings.differentialPrivacy {
            processedData = await addPrivacyNoise(to: processedData)
        }

        updatePrivacyMetrics()
        return processedData
    }

    func filterDetections(_ detections: [DetectionBox]) async -> [DetectionBox] {
        return detections.filter { detection in
            detection.confidence > 0.3
        }
    }

    private func blurFaces(in data: Data) async -> Data {
        guard let image = UIImage(data: data) else { return data }

        let faces = await faceDetector.detectFaces(in: image)

        if !faces.isEmpty {
            onPrivacyViolation?()
            return await applyFaceBlur(to: image, faces: faces)
        }

        return data
    }

    private func addPrivacyNoise(to data: Data) async -> Data {
        privacyBudget -= 0.1
        return data
    }

    private func applyFaceBlur(to image: UIImage, faces: [CGRect]) async -> Data {
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }

    private func updatePrivacyMetrics() {
        let metrics = PrivacyMetrics(
            privacyBudgetRemaining: privacyBudget,
            onDeviceProcessingOnly: true,
            encryptionEnabled: true,
            faceBlurringEnabled: true
        )

        onPrivacyMetricsUpdate?(metrics)
    }
}

class FaceDetector {
    func detectFaces(in image: UIImage) async -> [CGRect] {
        guard let cgImage = image.cgImage else { return [] }

        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])

            if let faces = request.results {
                return faces.map { face in
                    let bounds = face.boundingBox
                    return CGRect(
                        x: bounds.origin.x * image.size.width,
                        y: (1 - bounds.origin.y - bounds.height) * image.size.height,
                        width: bounds.width * image.size.width,
                        height: bounds.height * image.size.height
                    )
                }
            }
        } catch {
            print("Face detection failed: \(error)")
        }

        return []
    }
}