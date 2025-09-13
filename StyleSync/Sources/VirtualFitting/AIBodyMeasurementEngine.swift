import CoreML
import Vision
import CreateML
import MetalPerformanceShaders

public class AIBodyMeasurementEngine: ObservableObject {
    private let bodyMeasurementModel: MLModel
    private let postureAnalysisModel: MLModel
    private let bodyCompositionModel: MLModel
    private let adaptiveMetricsEngine: AdaptiveMetricsEngine

    public init() throws {
        self.bodyMeasurementModel = try MLModel(contentsOf: Bundle.main.url(forResource: "BodyMeasurementModel", withExtension: "mlmodelc")!)
        self.postureAnalysisModel = try MLModel(contentsOf: Bundle.main.url(forResource: "PostureAnalysisModel", withExtension: "mlmodelc")!)
        self.bodyCompositionModel = try MLModel(contentsOf: Bundle.main.url(forResource: "BodyCompositionModel", withExtension: "mlmodelc")!)
        self.adaptiveMetricsEngine = AdaptiveMetricsEngine()
    }

    public func extractMeasurements(from scanResult: BodyScanResult) async throws -> BodyMeasurements {
        // Prepare input for Core ML model
        let preprocessedMesh = try preprocessBodyMesh(scanResult.bodyMesh)
        let modelInput = try createMLInput(from: preprocessedMesh)

        // Run body measurement extraction
        let measurementOutput = try await bodyMeasurementModel.prediction(from: modelInput)
        let baseMeasurements = try parseBaseMeasurements(from: measurementOutput)

        // Enhance with posture analysis
        let postureAnalysis = try await analyzePosture(from: scanResult.bodyMesh)

        // Add adaptive metrics for better fit prediction
        let adaptiveMetrics = try await adaptiveMetricsEngine.calculateMetrics(
            mesh: scanResult.bodyMesh,
            baseMeasurements: baseMeasurements,
            postureAnalysis: postureAnalysis
        )

        // Apply body-positive adjustments
        let adjustedMeasurements = applyBodyPositiveAdjustments(
            measurements: baseMeasurements,
            adaptiveMetrics: adaptiveMetrics
        )

        return BodyMeasurements(
            chest: adjustedMeasurements.chest,
            waist: adjustedMeasurements.waist,
            hips: adjustedMeasurements.hips,
            shoulderWidth: adjustedMeasurements.shoulderWidth,
            armLength: adjustedMeasurements.armLength,
            torsoLength: adjustedMeasurements.torsoLength,
            legLength: adjustedMeasurements.legLength,
            neckCircumference: adjustedMeasurements.neckCircumference,
            bodyMesh: scanResult.bodyMesh,
            postureAnalysis: postureAnalysis,
            adaptiveMetrics: adaptiveMetrics
        )
    }

    private func preprocessBodyMesh(_ mesh: BodyMesh) throws -> PreprocessedMesh {
        // Normalize mesh coordinates
        let normalizedVertices = normalizeMeshCoordinates(mesh.vertices)

        // Apply smoothing filter to reduce noise
        let smoothedVertices = applySmoothingFilter(normalizedVertices)

        // Extract key anatomical landmarks
        let landmarks = try extractAnatomicalLandmarks(from: smoothedVertices, faces: mesh.faces)

        // Create feature vectors for ML model
        let featureVectors = createFeatureVectors(from: smoothedVertices, landmarks: landmarks)

        return PreprocessedMesh(
            vertices: smoothedVertices,
            landmarks: landmarks,
            featureVectors: featureVectors
        )
    }

    private func normalizeMeshCoordinates(_ vertices: [SIMD3<Float>]) -> [SIMD3<Float>] {
        guard !vertices.isEmpty else { return vertices }

        // Find bounding box
        let minX = vertices.map { $0.x }.min()!
        let maxX = vertices.map { $0.x }.max()!
        let minY = vertices.map { $0.y }.min()!
        let maxY = vertices.map { $0.y }.max()!
        let minZ = vertices.map { $0.z }.min()!
        let maxZ = vertices.map { $0.z }.max()!

        let center = SIMD3<Float>(
            (minX + maxX) / 2,
            (minY + maxY) / 2,
            (minZ + maxZ) / 2
        )

        let scale = max(maxX - minX, max(maxY - minY, maxZ - minZ))

        return vertices.map { vertex in
            (vertex - center) / scale
        }
    }

    private func applySmoothingFilter(_ vertices: [SIMD3<Float>]) -> [SIMD3<Float>] {
        // Apply Gaussian smoothing to reduce measurement noise
        var smoothedVertices = vertices

        for _ in 0..<3 { // 3 iterations of smoothing
            smoothedVertices = applySingleSmoothingPass(smoothedVertices)
        }

        return smoothedVertices
    }

    private func applySingleSmoothingPass(_ vertices: [SIMD3<Float>]) -> [SIMD3<Float>] {
        let neighborRadius: Float = 0.05
        var smoothed = vertices

        for i in 0..<vertices.count {
            var neighborSum = SIMD3<Float>(0, 0, 0)
            var neighborCount = 0

            for j in 0..<vertices.count {
                let distance = distance(vertices[i], vertices[j])
                if distance < neighborRadius {
                    neighborSum += vertices[j]
                    neighborCount += 1
                }
            }

            if neighborCount > 0 {
                smoothed[i] = neighborSum / Float(neighborCount)
            }
        }

        return smoothed
    }

    private func extractAnatomicalLandmarks(from vertices: [SIMD3<Float>], faces: [SIMD3<UInt32>]) throws -> AnatomicalLandmarks {
        let landmarkExtractor = AnatomicalLandmarkExtractor()
        return try landmarkExtractor.extractLandmarks(vertices: vertices, faces: faces)
    }

    private func createFeatureVectors(from vertices: [SIMD3<Float>], landmarks: AnatomicalLandmarks) -> [Float] {
        var features: [Float] = []

        // Add vertex statistics
        features.append(Float(vertices.count))
        features.append(vertices.map { $0.x }.max() ?? 0)
        features.append(vertices.map { $0.x }.min() ?? 0)
        features.append(vertices.map { $0.y }.max() ?? 0)
        features.append(vertices.map { $0.y }.min() ?? 0)
        features.append(vertices.map { $0.z }.max() ?? 0)
        features.append(vertices.map { $0.z }.min() ?? 0)

        // Add landmark-based features
        features.append(contentsOf: landmarks.shoulderPoints.flatMap { [$0.x, $0.y, $0.z] })
        features.append(contentsOf: landmarks.waistPoints.flatMap { [$0.x, $0.y, $0.z] })
        features.append(contentsOf: landmarks.hipPoints.flatMap { [$0.x, $0.y, $0.z] })

        // Add geometric ratios
        let shoulderWidth = distance(landmarks.shoulderPoints[0], landmarks.shoulderPoints[1])
        let waistWidth = distance(landmarks.waistPoints[0], landmarks.waistPoints[1])
        let hipWidth = distance(landmarks.hipPoints[0], landmarks.hipPoints[1])

        features.append(shoulderWidth / waistWidth)
        features.append(waistWidth / hipWidth)
        features.append(shoulderWidth / hipWidth)

        return features
    }

    private func createMLInput(from mesh: PreprocessedMesh) throws -> MLFeatureProvider {
        let inputArray = try MLMultiArray(shape: [NSNumber(value: mesh.featureVectors.count)], dataType: .float32)

        for (index, value) in mesh.featureVectors.enumerated() {
            inputArray[index] = NSNumber(value: value)
        }

        let featureDict: [String: Any] = ["input": inputArray]
        return try MLDictionaryFeatureProvider(dictionary: featureDict)
    }

    private func parseBaseMeasurements(from output: MLFeatureProvider) throws -> BaseMeasurements {
        guard let outputArray = output.featureValue(for: "measurements")?.multiArrayValue else {
            throw MeasurementError.invalidModelOutput
        }

        return BaseMeasurements(
            chest: Double(truncating: outputArray[0]),
            waist: Double(truncating: outputArray[1]),
            hips: Double(truncating: outputArray[2]),
            shoulderWidth: Double(truncating: outputArray[3]),
            armLength: Double(truncating: outputArray[4]),
            torsoLength: Double(truncating: outputArray[5]),
            legLength: Double(truncating: outputArray[6]),
            neckCircumference: Double(truncating: outputArray[7])
        )
    }

    private func analyzePosture(from mesh: BodyMesh) async throws -> PostureAnalysis {
        let postureInput = try createPostureInput(from: mesh)
        let postureOutput = try await postureAnalysisModel.prediction(from: postureInput)

        guard let postureArray = postureOutput.featureValue(for: "posture_metrics")?.multiArrayValue else {
            throw MeasurementError.invalidPostureOutput
        }

        return PostureAnalysis(
            shoulderAlignment: AlignmentMetric(
                leftSide: Double(truncating: postureArray[0]),
                rightSide: Double(truncating: postureArray[1]),
                asymmetry: Double(truncating: postureArray[2])
            ),
            spinalCurvature: CurvatureMetric(
                cervical: Double(truncating: postureArray[3]),
                thoracic: Double(truncating: postureArray[4]),
                lumbar: Double(truncating: postureArray[5])
            ),
            pelvisAlignment: AlignmentMetric(
                leftSide: Double(truncating: postureArray[6]),
                rightSide: Double(truncating: postureArray[7]),
                asymmetry: Double(truncating: postureArray[8])
            ),
            bodySymmetry: SymmetryMetric(
                overall: Double(truncating: postureArray[9]),
                torso: Double(truncating: postureArray[10]),
                limbs: Double(truncating: postureArray[11])
            )
        )
    }

    private func createPostureInput(from mesh: BodyMesh) throws -> MLFeatureProvider {
        // Extract posture-specific features
        let postureFeatures = extractPostureFeatures(from: mesh)
        let inputArray = try MLMultiArray(shape: [NSNumber(value: postureFeatures.count)], dataType: .float32)

        for (index, value) in postureFeatures.enumerated() {
            inputArray[index] = NSNumber(value: value)
        }

        let featureDict: [String: Any] = ["posture_input": inputArray]
        return try MLDictionaryFeatureProvider(dictionary: featureDict)
    }

    private func extractPostureFeatures(from mesh: BodyMesh) -> [Float] {
        var features: [Float] = []

        // Extract spine curve features
        let spinePoints = mesh.extractSpinePoints()
        features.append(contentsOf: calculateSpineCurvature(spinePoints))

        // Extract shoulder alignment features
        let shoulderPoints = mesh.extractShoulderPoints()
        features.append(contentsOf: calculateShoulderAlignment(shoulderPoints))

        // Extract pelvis alignment features
        let pelvisPoints = mesh.extractPelvisPoints()
        features.append(contentsOf: calculatePelvisAlignment(pelvisPoints))

        return features
    }

    private func calculateSpineCurvature(_ spinePoints: [SIMD3<Float>]) -> [Float] {
        guard spinePoints.count >= 3 else { return [0, 0, 0] }

        var curvatures: [Float] = []

        for i in 1..<(spinePoints.count - 1) {
            let p1 = spinePoints[i - 1]
            let p2 = spinePoints[i]
            let p3 = spinePoints[i + 1]

            let curvature = calculateCurvatureAt(p1: p1, p2: p2, p3: p3)
            curvatures.append(curvature)
        }

        // Return cervical, thoracic, and lumbar curvature measurements
        let segments = curvatures.count / 3
        return [
            curvatures[0..<segments].reduce(0, +) / Float(segments),
            curvatures[segments..<(segments * 2)].reduce(0, +) / Float(segments),
            curvatures[(segments * 2)...].reduce(0, +) / Float(curvatures.count - segments * 2)
        ]
    }

    private func calculateCurvatureAt(p1: SIMD3<Float>, p2: SIMD3<Float>, p3: SIMD3<Float>) -> Float {
        let v1 = p2 - p1
        let v2 = p3 - p2

        let crossProduct = cross(v1, v2)
        let crossMagnitude = length(crossProduct)
        let dotProduct = dot(v1, v2)

        return atan2(crossMagnitude, dotProduct)
    }

    private func calculateShoulderAlignment(_ shoulderPoints: [SIMD3<Float>]) -> [Float] {
        guard shoulderPoints.count >= 2 else { return [0, 0, 0] }

        let leftShoulder = shoulderPoints[0]
        let rightShoulder = shoulderPoints[1]

        let heightDifference = abs(leftShoulder.y - rightShoulder.y)
        let forwardBackDifference = abs(leftShoulder.z - rightShoulder.z)

        return [leftShoulder.y, rightShoulder.y, heightDifference + forwardBackDifference]
    }

    private func calculatePelvisAlignment(_ pelvisPoints: [SIMD3<Float>]) -> [Float] {
        guard pelvisPoints.count >= 2 else { return [0, 0, 0] }

        let leftHip = pelvisPoints[0]
        let rightHip = pelvisPoints[1]

        let heightDifference = abs(leftHip.y - rightHip.y)
        let rotationDifference = abs(leftHip.z - rightHip.z)

        return [leftHip.y, rightHip.y, heightDifference + rotationDifference]
    }

    private func applyBodyPositiveAdjustments(
        measurements: BaseMeasurements,
        adaptiveMetrics: [String: Double]
    ) -> BaseMeasurements {
        // Apply inclusive sizing adjustments that work for all body types
        var adjusted = measurements

        // Add comfort allowances based on body composition
        if let musculature = adaptiveMetrics["musculature"] {
            adjusted.chest += musculature * 2.0 // Extra room for muscular builds
            adjusted.shoulderWidth += musculature * 1.0
        }

        // Adjust for posture considerations
        if let postureAdjustment = adaptiveMetrics["posture_adjustment"] {
            adjusted.torsoLength += postureAdjustment
        }

        // Add adaptive sizing for different body shapes
        if let bodyShape = adaptiveMetrics["body_shape_factor"] {
            adjusted.waist = max(adjusted.waist, adjusted.hips * 0.7) // Ensure realistic ratios
            adjusted.hips = max(adjusted.hips, adjusted.waist * 1.1)
        }

        return adjusted
    }
}

public class AdaptiveMetricsEngine {
    public func calculateMetrics(
        mesh: BodyMesh,
        baseMeasurements: BaseMeasurements,
        postureAnalysis: PostureAnalysis
    ) async throws -> [String: Double] {
        var metrics: [String: Double] = [:]

        // Calculate body composition metrics
        metrics["musculature"] = calculateMusculature(from: mesh)
        metrics["body_fat_distribution"] = calculateBodyFatDistribution(from: mesh)

        // Calculate fit-specific metrics
        metrics["shoulder_slope"] = calculateShoulderSlope(from: mesh)
        metrics["torso_taper"] = calculateTorsoTaper(from: baseMeasurements)
        metrics["limb_proportions"] = calculateLimbProportions(from: baseMeasurements)

        // Calculate posture adjustments
        metrics["posture_adjustment"] = calculatePostureAdjustment(from: postureAnalysis)
        metrics["asymmetry_factor"] = calculateAsymmetryFactor(from: postureAnalysis)

        // Calculate body shape factor
        metrics["body_shape_factor"] = calculateBodyShapeFactor(from: baseMeasurements)

        // Calculate comfort preferences
        metrics["preferred_ease"] = calculatePreferredEase(from: metrics)

        return metrics
    }

    private func calculateMusculature(from mesh: BodyMesh) -> Double {
        // Analyze muscle definition from mesh geometry
        let muscleRegions = mesh.extractMuscleRegions()
        let definition = calculateMuscleDefinition(muscleRegions)
        return min(max(definition, 0.0), 1.0)
    }

    private func calculateBodyFatDistribution(from mesh: BodyMesh) -> Double {
        // Analyze fat distribution patterns
        let fatRegions = mesh.extractFatRegions()
        return calculateDistributionPattern(fatRegions)
    }

    private func calculateShoulderSlope(from mesh: BodyMesh) -> Double {
        let shoulderPoints = mesh.extractShoulderPoints()
        guard shoulderPoints.count >= 2 else { return 0.0 }

        let slope = (shoulderPoints[1].y - shoulderPoints[0].y) / (shoulderPoints[1].x - shoulderPoints[0].x)
        return Double(atan(slope))
    }

    private func calculateTorsoTaper(from measurements: BaseMeasurements) -> Double {
        return (measurements.chest - measurements.waist) / measurements.chest
    }

    private func calculateLimbProportions(from measurements: BaseMeasurements) -> Double {
        let armToTorsoRatio = measurements.armLength / measurements.torsoLength
        let legToTorsoRatio = measurements.legLength / measurements.torsoLength
        return (armToTorsoRatio + legToTorsoRatio) / 2.0
    }

    private func calculatePostureAdjustment(from posture: PostureAnalysis) -> Double {
        let spinalDeviation = (posture.spinalCurvature.cervical + posture.spinalCurvature.thoracic + posture.spinalCurvature.lumbar) / 3.0
        return spinalDeviation * 0.02 // Small adjustment based on posture
    }

    private func calculateAsymmetryFactor(from posture: PostureAnalysis) -> Double {
        return (posture.shoulderAlignment.asymmetry + posture.pelvisAlignment.asymmetry) / 2.0
    }

    private func calculateBodyShapeFactor(from measurements: BaseMeasurements) -> Double {
        let waistToHipRatio = measurements.waist / measurements.hips
        let waistToChestRatio = measurements.waist / measurements.chest

        return (waistToHipRatio + waistToChestRatio) / 2.0
    }

    private func calculatePreferredEase(from metrics: [String: Double]) -> Double {
        var baseEase = 0.05 // 5% ease by default

        if let musculature = metrics["musculature"], musculature > 0.7 {
            baseEase += 0.03 // More ease for muscular builds
        }

        if let asymmetry = metrics["asymmetry_factor"], asymmetry > 0.1 {
            baseEase += 0.02 // More ease for asymmetrical bodies
        }

        return baseEase
    }

    private func calculateMuscleDefinition(_ regions: [MuscleRegion]) -> Double {
        // Implement muscle definition calculation
        return regions.reduce(0.0) { sum, region in
            sum + region.definition
        } / Double(regions.count)
    }

    private func calculateDistributionPattern(_ regions: [FatRegion]) -> Double {
        // Implement fat distribution pattern calculation
        return regions.reduce(0.0) { sum, region in
            sum + region.density
        } / Double(regions.count)
    }
}

public struct PreprocessedMesh {
    public let vertices: [SIMD3<Float>]
    public let landmarks: AnatomicalLandmarks
    public let featureVectors: [Float]
}

public struct BaseMeasurements {
    public let chest: Double
    public let waist: Double
    public let hips: Double
    public let shoulderWidth: Double
    public let armLength: Double
    public let torsoLength: Double
    public let legLength: Double
    public let neckCircumference: Double
}

public enum MeasurementError: Error, LocalizedError {
    case invalidModelOutput
    case invalidPostureOutput
    case preprocessingFailed
    case landmarkExtractionFailed

    public var errorDescription: String? {
        switch self {
        case .invalidModelOutput:
            return "AI model produced invalid measurement output"
        case .invalidPostureOutput:
            return "AI model produced invalid posture analysis output"
        case .preprocessingFailed:
            return "Failed to preprocess body mesh for analysis"
        case .landmarkExtractionFailed:
            return "Failed to extract anatomical landmarks from body mesh"
        }
    }
}