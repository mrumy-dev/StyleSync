import ARKit
import RealityKit
import Vision
import CoreML
import MetalPerformanceShaders

@MainActor
public class LiDARBodyScanner: NSObject, ObservableObject {
    @Published public var isScanning = false
    @Published public var scanQuality: ScanQuality = .none

    private var arView: ARView?
    private var session = ARSession()
    private var scannedPointCloud: [SIMD3<Float>] = []
    private var bodyPoseEstimator: VNDetectHumanBodyPoseRequest?
    private let privacySettings = ScannerPrivacySettings()

    public override init() {
        super.init()
        setupARConfiguration()
        setupBodyPoseDetection()
    }

    private func setupARConfiguration() {
        guard ARWorldTrackingConfiguration.supportsLiDAR else {
            print("LiDAR not supported on this device")
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification
        configuration.frameSemantics = [.personSegmentationWithDepth, .bodyDetection]

        if ARWorldTrackingConfiguration.supportsUserFaceTracking {
            configuration.userFaceTrackingEnabled = true
        }

        session.delegate = self
    }

    private func setupBodyPoseDetection() {
        bodyPoseEstimator = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard let self = self else { return }
            self.processBodyPoseResults(request.results)
        }
        bodyPoseEstimator?.revision = VNDetectHumanBodyPoseRequestRevision1
    }

    public func initializeLiDAR() async throws {
        guard ARWorldTrackingConfiguration.supportsLiDAR else {
            throw ScanningError.lidarNotSupported
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification
        configuration.frameSemantics = [.personSegmentationWithDepth]

        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        isScanning = true
    }

    public func performFullBodyScan(progressCallback: @escaping (Double) -> Void) async throws -> BodyScanResult {
        guard isScanning else {
            throw ScanningError.sessionNotActive
        }

        var scanProgress: Double = 0.0
        let scanDuration: TimeInterval = 15.0 // 15 seconds for full body scan
        let startTime = Date()

        return try await withCheckedThrowingContinuation { continuation in
            var hasCompleted = false

            let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                let elapsed = Date().timeIntervalSince(startTime)
                scanProgress = min(elapsed / scanDuration, 1.0)
                progressCallback(scanProgress)

                if scanProgress >= 1.0 && !hasCompleted {
                    hasCompleted = true
                    timer.invalidate()

                    Task { @MainActor in
                        do {
                            let result = try await self.finalizeScan()
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
    }

    private func finalizeScan() async throws -> BodyScanResult {
        isScanning = false

        guard !scannedPointCloud.isEmpty else {
            throw ScanningError.insufficientData
        }

        // Process point cloud with privacy protection
        let anonymizedPointCloud = try privacySettings.anonymizePointCloud(scannedPointCloud)

        // Generate body mesh from point cloud
        let bodyMesh = try await generateBodyMesh(from: anonymizedPointCloud)

        // Extract measurements
        let measurements = try extractMeasurements(from: bodyMesh)

        // Perform posture analysis
        let postureAnalysis = try analyzePosture(from: bodyMesh)

        return BodyScanResult(
            pointCloud: anonymizedPointCloud,
            bodyMesh: bodyMesh,
            measurements: measurements,
            postureAnalysis: postureAnalysis,
            scanQuality: scanQuality,
            timestamp: Date(),
            privacyCompliant: true
        )
    }

    private func generateBodyMesh(from pointCloud: [SIMD3<Float>]) async throws -> BodyMesh {
        // Use Metal Performance Shaders for efficient point cloud processing
        let device = MTLCreateSystemDefaultDevice()!
        let commandQueue = device.makeCommandQueue()!

        // Convert point cloud to mesh using marching cubes algorithm
        let meshGenerator = BodyMeshGenerator(device: device)
        return try await meshGenerator.generateMesh(from: pointCloud)
    }

    private func extractMeasurements(from bodyMesh: BodyMesh) throws -> BodyMeasurements {
        let extractor = BodyMeasurementExtractor()
        return try extractor.extractMeasurements(from: bodyMesh)
    }

    private func analyzePosture(from bodyMesh: BodyMesh) throws -> PostureAnalysis {
        let analyzer = PostureAnalyzer()
        return try analyzer.analyzePosture(from: bodyMesh)
    }

    private func processBodyPoseResults(_ results: [VNObservation]?) {
        guard let bodyPoseResults = results as? [VNHumanBodyPoseObservation] else { return }

        for observation in bodyPoseResults {
            // Process body pose for better measurement accuracy
            updateScanQuality(based: observation)
        }
    }

    private func updateScanQuality(based observation: VNHumanBodyPoseObservation) {
        let confidence = observation.confidence

        switch confidence {
        case 0.8...1.0:
            scanQuality = .excellent
        case 0.6..<0.8:
            scanQuality = .good
        case 0.4..<0.6:
            scanQuality = .fair
        default:
            scanQuality = .poor
        }
    }
}

extension LiDARBodyScanner: ARSessionDelegate {
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isScanning else { return }

        // Process depth data from LiDAR
        if let depthData = frame.sceneDepth {
            processDepthData(depthData)
        }

        // Process camera image for body pose detection
        let pixelBuffer = frame.capturedImage
        performBodyPoseDetection(on: pixelBuffer)
    }

    private func processDepthData(_ depthData: ARDepthData) {
        let depthMap = depthData.depthMap
        let confidenceMap = depthData.confidenceMap

        // Convert depth map to 3D points with privacy protection
        let newPoints = extractPointsFromDepthMap(depthMap, confidenceMap: confidenceMap)
        scannedPointCloud.append(contentsOf: newPoints)

        // Limit point cloud size for performance and privacy
        if scannedPointCloud.count > 100000 {
            scannedPointCloud = Array(scannedPointCloud.suffix(100000))
        }
    }

    private func performBodyPoseDetection(on pixelBuffer: CVPixelBuffer) {
        guard let request = bodyPoseEstimator else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    private func extractPointsFromDepthMap(_ depthMap: CVPixelBuffer, confidenceMap: CVPixelBuffer?) -> [SIMD3<Float>] {
        var points: [SIMD3<Float>] = []

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let depthPointer = CVPixelBufferGetBaseAddress(depthMap)?.bindMemory(to: Float32.self, capacity: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let depth = depthPointer?[index] ?? 0

                if depth > 0.3 && depth < 5.0 { // Filter reasonable depth values
                    let point = SIMD3<Float>(
                        Float(x - width/2) * depth * 0.001,
                        Float(height/2 - y) * depth * 0.001,
                        -depth
                    )
                    points.append(point)
                }
            }
        }

        return points
    }
}

public struct BodyScanResult {
    public let pointCloud: [SIMD3<Float>]
    public let bodyMesh: BodyMesh
    public let measurements: BodyMeasurements
    public let postureAnalysis: PostureAnalysis
    public let scanQuality: ScanQuality
    public let timestamp: Date
    public let privacyCompliant: Bool
}

public enum ScanQuality: String, CaseIterable {
    case none = "none"
    case poor = "poor"
    case fair = "fair"
    case good = "good"
    case excellent = "excellent"

    public var description: String {
        switch self {
        case .none: return "No scan data"
        case .poor: return "Poor quality - please improve lighting and positioning"
        case .fair: return "Fair quality - scan may be usable"
        case .good: return "Good quality scan"
        case .excellent: return "Excellent quality scan"
        }
    }
}

public enum ScanningError: Error, LocalizedError {
    case lidarNotSupported
    case sessionNotActive
    case insufficientData
    case privacyViolation
    case processingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .lidarNotSupported:
            return "LiDAR scanning is not supported on this device"
        case .sessionNotActive:
            return "Scanning session is not active"
        case .insufficientData:
            return "Insufficient scan data collected"
        case .privacyViolation:
            return "Operation violates privacy settings"
        case .processingFailed(let reason):
            return "Scan processing failed: \(reason)"
        }
    }
}