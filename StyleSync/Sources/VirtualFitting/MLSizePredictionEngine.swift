import CoreML
import CreateML
import TensorFlow
import Foundation

public class MLSizePredictionEngine: ObservableObject {
    private let sizeRecommendationModel: MLModel
    private let brandSizingModel: MLModel
    private let fitPreferenceModel: MLModel
    private let returnPredictionModel: MLModel
    private let shrinkageModel: MLModel
    private let stretchModel: MLModel

    @Published public var isProcessing = false
    @Published public var learningProgress: Double = 0.0

    private let modelCache: ModelCache
    private let userPreferenceEngine: UserPreferenceEngine
    private let sizingDatabase: SizingDatabase

    public init() throws {
        // Initialize pre-trained models
        self.sizeRecommendationModel = try MLModel(contentsOf: Bundle.main.url(forResource: "SizeRecommendationModel", withExtension: "mlmodelc")!)
        self.brandSizingModel = try MLModel(contentsOf: Bundle.main.url(forResource: "BrandSizingModel", withExtension: "mlmodelc")!)
        self.fitPreferenceModel = try MLModel(contentsOf: Bundle.main.url(forResource: "FitPreferenceModel", withExtension: "mlmodelc")!)
        self.returnPredictionModel = try MLModel(contentsOf: Bundle.main.url(forResource: "ReturnPredictionModel", withExtension: "mlmodelc")!)
        self.shrinkageModel = try MLModel(contentsOf: Bundle.main.url(forResource: "ShrinkageModel", withExtension: "mlmodelc")!)
        self.stretchModel = try MLModel(contentsOf: Bundle.main.url(forResource: "StretchModel", withExtension: "mlmodelc")!)

        self.modelCache = ModelCache()
        self.userPreferenceEngine = UserPreferenceEngine()
        self.sizingDatabase = SizingDatabase()
    }

    public func predictSize(
        for garment: VirtualGarment,
        bodyMeasurements: BodyMeasurements,
        preferences: FitPreferences
    ) async throws -> SizeRecommendation {

        isProcessing = true
        defer { isProcessing = false }

        // Get brand-specific sizing adjustments
        let brandAdjustments = try await getBrandSizingAdjustments(
            brand: garment.brand,
            garmentType: garment.type
        )

        // Predict fabric behavior over time
        let fabricPredictions = try await predictFabricChanges(
            fabricProperties: garment.fabricProperties,
            care: garment.careInstructions
        )

        // Calculate base size recommendation
        let baseSizeInput = createBaseSizeInput(
            measurements: bodyMeasurements,
            garment: garment,
            preferences: preferences,
            brandAdjustments: brandAdjustments
        )

        let baseSizeOutput = try await sizeRecommendationModel.prediction(from: baseSizeInput)
        let baseSize = try parseBaseSizeRecommendation(from: baseSizeOutput)

        // Adjust for user fit preferences
        let preferenceAdjustments = try await calculatePreferenceAdjustments(
            baseSize: baseSize,
            preferences: preferences,
            garment: garment
        )

        // Predict return likelihood for different sizes
        let returnRisks = try await predictReturnRisks(
            sizes: generateSizeOptions(around: baseSize),
            measurements: bodyMeasurements,
            garment: garment,
            preferences: preferences
        )

        // Calculate comfort scores for size options
        let comfortScores = try await calculateComfortScores(
            sizes: generateSizeOptions(around: baseSize),
            measurements: bodyMeasurements,
            garment: garment,
            fabricPredictions: fabricPredictions
        )

        // Find optimal size balancing fit, comfort, and return risk
        let optimalSize = findOptimalSize(
            baseSize: baseSize,
            returnRisks: returnRisks,
            comfortScores: comfortScores,
            preferences: preferences
        )

        // Generate comprehensive size recommendation
        let recommendation = SizeRecommendation(
            recommendedSize: optimalSize,
            confidence: calculateConfidence(optimalSize, returnRisks, comfortScores),
            alternativeSizes: generateAlternatives(optimalSize, returnRisks, comfortScores),
            fitPrediction: createFitPrediction(optimalSize, measurements: bodyMeasurements, garment: garment),
            returnRisk: returnRisks[optimalSize] ?? 0.0,
            comfortScore: comfortScores[optimalSize] ?? 0.0,
            fabricAdjustments: fabricPredictions,
            brandAdjustments: brandAdjustments,
            easeAllowance: calculateEaseAllowance(optimalSize, preferences: preferences),
            sizingNotes: generateSizingNotes(optimalSize, garment: garment, measurements: bodyMeasurements)
        )

        // Learn from this prediction for future improvements
        await updateUserPreferences(recommendation, measurements: bodyMeasurements, garment: garment)

        return recommendation
    }

    private func getBrandSizingAdjustments(
        brand: String,
        garmentType: GarmentType
    ) async throws -> BrandSizingAdjustments {

        let brandInput = createBrandSizingInput(brand: brand, garmentType: garmentType)
        let brandOutput = try await brandSizingModel.prediction(from: brandInput)

        guard let adjustmentArray = brandOutput.featureValue(for: "brand_adjustments")?.multiArrayValue else {
            throw SizePredictionError.invalidBrandOutput
        }

        return BrandSizingAdjustments(
            generalSizing: BrandSizingTendency(rawValue: Int(truncating: adjustmentArray[0])) ?? .runsTrue,
            chestAdjustment: Double(truncating: adjustmentArray[1]),
            waistAdjustment: Double(truncating: adjustmentArray[2]),
            hipAdjustment: Double(truncating: adjustmentArray[3]),
            lengthAdjustment: Double(truncating: adjustmentArray[4]),
            shoulderAdjustment: Double(truncating: adjustmentArray[5]),
            armLengthAdjustment: Double(truncating: adjustmentArray[6]),
            qualityConsistency: Double(truncating: adjustmentArray[7]),
            seasonalVariation: Double(truncating: adjustmentArray[8])
        )
    }

    private func predictFabricChanges(
        fabricProperties: FabricProperties,
        care: CareInstructions
    ) async throws -> FabricPredictions {

        // Predict shrinkage
        let shrinkageInput = createShrinkageInput(fabric: fabricProperties, care: care)
        let shrinkageOutput = try await shrinkageModel.prediction(from: shrinkageInput)

        guard let shrinkageArray = shrinkageOutput.featureValue(for: "shrinkage_prediction")?.multiArrayValue else {
            throw SizePredictionError.invalidShrinkageOutput
        }

        // Predict stretch over time
        let stretchInput = createStretchInput(fabric: fabricProperties, care: care)
        let stretchOutput = try await stretchModel.prediction(from: stretchInput)

        guard let stretchArray = stretchOutput.featureValue(for: "stretch_prediction")?.multiArrayValue else {
            throw SizePredictionError.invalidStretchOutput
        }

        return FabricPredictions(
            shrinkageX: Double(truncating: shrinkageArray[0]),
            shrinkageY: Double(truncating: shrinkageArray[1]),
            stretchX: Double(truncating: stretchArray[0]),
            stretchY: Double(truncating: stretchArray[1]),
            stretchRecovery: Double(truncating: stretchArray[2]),
            durabilityFactor: Double(truncating: stretchArray[3]),
            comfortDegradation: Double(truncating: stretchArray[4]),
            expectedLifespan: Int(truncating: stretchArray[5])
        )
    }

    private func calculatePreferenceAdjustments(
        baseSize: Size,
        preferences: FitPreferences,
        garment: VirtualGarment
    ) async throws -> PreferenceAdjustments {

        let preferenceInput = createPreferenceInput(
            size: baseSize,
            preferences: preferences,
            garment: garment
        )

        let preferenceOutput = try await fitPreferenceModel.prediction(from: preferenceInput)

        guard let adjustmentArray = preferenceOutput.featureValue(for: "preference_adjustments")?.multiArrayValue else {
            throw SizePredictionError.invalidPreferenceOutput
        }

        return PreferenceAdjustments(
            fitAdjustment: FitAdjustment(rawValue: Int(truncating: adjustmentArray[0])) ?? .none,
            comfortPriority: Double(truncating: adjustmentArray[1]),
            stylePriority: Double(truncating: adjustmentArray[2]),
            functionalityPriority: Double(truncating: adjustmentArray[3]),
            sizeModification: SizeModification(
                chest: Double(truncating: adjustmentArray[4]),
                waist: Double(truncating: adjustmentArray[5]),
                hip: Double(truncating: adjustmentArray[6]),
                length: Double(truncating: adjustmentArray[7])
            )
        )
    }

    private func predictReturnRisks(
        sizes: [Size],
        measurements: BodyMeasurements,
        garment: VirtualGarment,
        preferences: FitPreferences
    ) async throws -> [Size: Double] {

        var returnRisks: [Size: Double] = [:]

        for size in sizes {
            let riskInput = createReturnRiskInput(
                size: size,
                measurements: measurements,
                garment: garment,
                preferences: preferences
            )

            let riskOutput = try await returnPredictionModel.prediction(from: riskInput)

            if let riskValue = riskOutput.featureValue(for: "return_probability")?.doubleValue {
                returnRisks[size] = riskValue
            }
        }

        return returnRisks
    }

    private func calculateComfortScores(
        sizes: [Size],
        measurements: BodyMeasurements,
        garment: VirtualGarment,
        fabricPredictions: FabricPredictions
    ) async throws -> [Size: Double] {

        var comfortScores: [Size: Double] = [:]
        let comfortCalculator = ComfortScoreCalculator()

        for size in sizes {
            let score = try await comfortCalculator.calculateScore(
                size: size,
                measurements: measurements,
                garment: garment,
                fabricPredictions: fabricPredictions
            )
            comfortScores[size] = score
        }

        return comfortScores
    }

    private func findOptimalSize(
        baseSize: Size,
        returnRisks: [Size: Double],
        comfortScores: [Size: Double],
        preferences: FitPreferences
    ) -> Size {

        let sizeOptions = Array(returnRisks.keys)
        var bestSize = baseSize
        var bestScore = 0.0

        for size in sizeOptions {
            let returnRisk = returnRisks[size] ?? 1.0
            let comfortScore = comfortScores[size] ?? 0.0

            // Weight factors based on user preferences
            let riskWeight = preferences.returnRiskTolerance == .low ? 0.4 : 0.2
            let comfortWeight = preferences.comfortPriority == .high ? 0.6 : 0.4
            let fitWeight = 1.0 - riskWeight - comfortWeight

            // Calculate composite score
            let fitScore = calculateFitScore(size, baseSize: baseSize)
            let compositeScore = fitScore * fitWeight +
                               comfortScore * comfortWeight +
                               (1.0 - returnRisk) * riskWeight

            if compositeScore > bestScore {
                bestScore = compositeScore
                bestSize = size
            }
        }

        return bestSize
    }

    private func calculateEaseAllowance(
        _ size: Size,
        preferences: FitPreferences
    ) -> EaseAllowance {

        let baseEase = EaseAllowance.standard

        // Adjust based on fit preferences
        var adjustmentFactor = 1.0

        switch preferences.preferredFit {
        case .tight:
            adjustmentFactor = 0.8
        case .fitted:
            adjustmentFactor = 0.9
        case .regular:
            adjustmentFactor = 1.0
        case .relaxed:
            adjustmentFactor = 1.2
        case .loose:
            adjustmentFactor = 1.4
        }

        // Adjust based on activity level
        switch preferences.activityLevel {
        case .sedentary:
            adjustmentFactor *= 0.9
        case .moderate:
            adjustmentFactor *= 1.0
        case .active:
            adjustmentFactor *= 1.1
        case .athletic:
            adjustmentFactor *= 1.2
        }

        return EaseAllowance(
            shoulder: baseEase.shoulder * adjustmentFactor,
            chest: baseEase.chest * adjustmentFactor,
            waist: baseEase.waist * adjustmentFactor,
            hip: baseEase.hip * adjustmentFactor,
            leg: baseEase.leg * adjustmentFactor
        )
    }

    private func generateSizingNotes(
        _ size: Size,
        garment: VirtualGarment,
        measurements: BodyMeasurements
    ) -> [SizingNote] {

        var notes: [SizingNote] = []

        // Check for potential fit issues
        if measurements.adaptiveMetrics["shoulder_slope"] ?? 0 > 0.3 {
            notes.append(.shoulderFitConsideration)
        }

        if measurements.adaptiveMetrics["body_shape_factor"] ?? 0 > 0.8 {
            notes.append(.bodyShapeConsideration)
        }

        // Brand-specific notes
        if garment.brand == "Luxury Brand" {
            notes.append(.luxuryBrandSizing)
        }

        // Fabric-specific notes
        if garment.fabricProperties.stretchRecovery < 0.7 {
            notes.append(.stretchWarning)
        }

        if garment.fabricProperties.shrinkage > 0.03 {
            notes.append(.shrinkageWarning)
        }

        return notes
    }

    private func updateUserPreferences(
        _ recommendation: SizeRecommendation,
        measurements: BodyMeasurements,
        garment: VirtualGarment
    ) async {

        // Learn from user interactions and feedback
        await userPreferenceEngine.recordSizeRecommendation(
            recommendation,
            measurements: measurements,
            garment: garment
        )

        // Update models with new data point
        await modelCache.updateWithNewDataPoint(
            recommendation,
            measurements: measurements,
            garment: garment
        )
    }

    // MARK: - Input Creation Methods

    private func createBaseSizeInput(
        measurements: BodyMeasurements,
        garment: VirtualGarment,
        preferences: FitPreferences,
        brandAdjustments: BrandSizingAdjustments
    ) -> MLFeatureProvider {

        var features: [String: Double] = [:]

        // Body measurements
        features["chest"] = measurements.chest
        features["waist"] = measurements.waist
        features["hips"] = measurements.hips
        features["shoulder_width"] = measurements.shoulderWidth
        features["arm_length"] = measurements.armLength
        features["torso_length"] = measurements.torsoLength
        features["leg_length"] = measurements.legLength

        // Garment properties
        features["garment_type"] = Double(garment.type.rawValue)
        features["fit_type"] = Double(garment.fitType.rawValue)
        features["stretch_factor"] = garment.fabricProperties.elasticity

        // Brand adjustments
        features["brand_sizing"] = Double(brandAdjustments.generalSizing.rawValue)
        features["brand_chest_adj"] = brandAdjustments.chestAdjustment
        features["brand_waist_adj"] = brandAdjustments.waistAdjustment

        // Preferences
        features["preferred_fit"] = Double(preferences.preferredFit.rawValue)
        features["activity_level"] = Double(preferences.activityLevel.rawValue)

        // Adaptive metrics
        for (key, value) in measurements.adaptiveMetrics {
            features["adaptive_\(key)"] = value
        }

        do {
            return try MLDictionaryFeatureProvider(dictionary: features)
        } catch {
            fatalError("Failed to create ML feature provider: \(error)")
        }
    }

    private func createBrandSizingInput(brand: String, garmentType: GarmentType) -> MLFeatureProvider {
        let features: [String: Any] = [
            "brand_hash": brand.hash,
            "garment_type": garmentType.rawValue,
            "brand_name": brand
        ]

        do {
            return try MLDictionaryFeatureProvider(dictionary: features)
        } catch {
            fatalError("Failed to create brand sizing input: \(error)")
        }
    }

    // Additional input creation methods...

    private func generateSizeOptions(around baseSize: Size) -> [Size] {
        var options: [Size] = [baseSize]

        // Add smaller sizes
        if let smaller = baseSize.smaller() {
            options.append(smaller)
            if let muchSmaller = smaller.smaller() {
                options.append(muchSmaller)
            }
        }

        // Add larger sizes
        if let larger = baseSize.larger() {
            options.append(larger)
            if let muchLarger = larger.larger() {
                options.append(muchLarger)
            }
        }

        return options
    }

    private func calculateFitScore(_ size: Size, baseSize: Size) -> Double {
        let sizeDifference = abs(size.numericValue - baseSize.numericValue)
        return max(0.0, 1.0 - sizeDifference * 0.2)
    }

    // MARK: - Parsing Methods

    private func parseBaseSizeRecommendation(from output: MLFeatureProvider) throws -> Size {
        guard let sizeValue = output.featureValue(for: "recommended_size")?.doubleValue else {
            throw SizePredictionError.invalidSizeOutput
        }

        return Size.fromNumericValue(sizeValue)
    }
}

// MARK: - Supporting Types

public struct SizeRecommendation {
    public let recommendedSize: Size
    public let confidence: Double
    public let alternativeSizes: [AlternativeSize]
    public let fitPrediction: FitPrediction
    public let returnRisk: Double
    public let comfortScore: Double
    public let fabricAdjustments: FabricPredictions
    public let brandAdjustments: BrandSizingAdjustments
    public let easeAllowance: EaseAllowance
    public let sizingNotes: [SizingNote]
}

public struct BrandSizingAdjustments {
    public let generalSizing: BrandSizingTendency
    public let chestAdjustment: Double
    public let waistAdjustment: Double
    public let hipAdjustment: Double
    public let lengthAdjustment: Double
    public let shoulderAdjustment: Double
    public let armLengthAdjustment: Double
    public let qualityConsistency: Double
    public let seasonalVariation: Double
}

public enum BrandSizingTendency: Int {
    case runsVerySmall = 0
    case runsSmall = 1
    case runsTrue = 2
    case runsLarge = 3
    case runsVeryLarge = 4
}

public struct FabricPredictions {
    public let shrinkageX: Double
    public let shrinkageY: Double
    public let stretchX: Double
    public let stretchY: Double
    public let stretchRecovery: Double
    public let durabilityFactor: Double
    public let comfortDegradation: Double
    public let expectedLifespan: Int
}

public enum SizingNote {
    case shoulderFitConsideration
    case bodyShapeConsideration
    case luxuryBrandSizing
    case stretchWarning
    case shrinkageWarning
    case careInstructionImportant
    case seasonalFitVariation
}

public enum SizePredictionError: Error, LocalizedError {
    case invalidBrandOutput
    case invalidShrinkageOutput
    case invalidStretchOutput
    case invalidPreferenceOutput
    case invalidSizeOutput
    case modelNotAvailable(String)

    public var errorDescription: String? {
        switch self {
        case .invalidBrandOutput:
            return "Invalid brand sizing model output"
        case .invalidShrinkageOutput:
            return "Invalid shrinkage prediction model output"
        case .invalidStretchOutput:
            return "Invalid stretch prediction model output"
        case .invalidPreferenceOutput:
            return "Invalid preference model output"
        case .invalidSizeOutput:
            return "Invalid size recommendation model output"
        case .modelNotAvailable(let modelName):
            return "ML model not available: \(modelName)"
        }
    }
}