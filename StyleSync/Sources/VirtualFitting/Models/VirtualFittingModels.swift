import Foundation
import simd
import ARKit

// MARK: - Core Virtual Fitting Models

public struct VirtualGarment: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let brand: String
    public let type: GarmentType
    public let style: GarmentStyle
    public let color: GarmentColor
    public let pattern: GarmentPattern
    public let finish: GarmentFinish
    public let weathering: WeatheringLevel
    public let fitType: FitType
    public let fabricProperties: FabricProperties
    public let careInstructions: CareInstructions
    public let availableSizes: [Size]
    public let priceRange: PriceRange
    public let seasonality: [Season]
    public let occasions: [Occasion]

    public init(
        id: UUID = UUID(),
        name: String,
        brand: String,
        type: GarmentType,
        style: GarmentStyle,
        color: GarmentColor,
        pattern: GarmentPattern = .solid,
        finish: GarmentFinish = .standard,
        weathering: WeatheringLevel = .none,
        fitType: FitType,
        fabricProperties: FabricProperties,
        careInstructions: CareInstructions,
        availableSizes: [Size],
        priceRange: PriceRange,
        seasonality: [Season] = Season.allCases,
        occasions: [Occasion] = []
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.type = type
        self.style = style
        self.color = color
        self.pattern = pattern
        self.finish = finish
        self.weathering = weathering
        self.fitType = fitType
        self.fabricProperties = fabricProperties
        self.careInstructions = careInstructions
        self.availableSizes = availableSizes
        self.priceRange = priceRange
        self.seasonality = seasonality
        self.occasions = occasions
    }

    public var publicInfo: GarmentPublicInfo {
        return GarmentPublicInfo(
            type: type,
            style: style,
            color: color,
            pattern: pattern,
            occasions: occasions
        )
    }

    public var description: String {
        return "\(brand) \(name) - \(type.displayName)"
    }
}

public enum GarmentType: String, Codable, CaseIterable {
    case shirt, blouse, tShirt, sweater, jacket, coat
    case pants, jeans, shorts, skirt, dress
    case underwear, bra, socks
    case shoes, boots, sneakers
    case accessories

    public var displayName: String {
        switch self {
        case .shirt: return "Shirt"
        case .blouse: return "Blouse"
        case .tShirt: return "T-Shirt"
        case .sweater: return "Sweater"
        case .jacket: return "Jacket"
        case .coat: return "Coat"
        case .pants: return "Pants"
        case .jeans: return "Jeans"
        case .shorts: return "Shorts"
        case .skirt: return "Skirt"
        case .dress: return "Dress"
        case .underwear: return "Underwear"
        case .bra: return "Bra"
        case .socks: return "Socks"
        case .shoes: return "Shoes"
        case .boots: return "Boots"
        case .sneakers: return "Sneakers"
        case .accessories: return "Accessories"
        }
    }

    public var rawValue: Int {
        return GarmentType.allCases.firstIndex(of: self) ?? 0
    }
}

public enum GarmentStyle: String, Codable {
    case casual, formal, business, athletic, vintage, modern, bohemian, minimalist
}

public struct GarmentColor: Codable {
    public let primary: ColorInfo
    public let secondary: ColorInfo?
    public let accent: ColorInfo?

    public init(primary: ColorInfo, secondary: ColorInfo? = nil, accent: ColorInfo? = nil) {
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
    }
}

public struct ColorInfo: Codable {
    public let hex: String
    public let name: String
    public let family: ColorFamily
    public let intensity: Double // 0.0 to 1.0
    public let warmth: Double // -1.0 (cool) to 1.0 (warm)

    public init(hex: String, name: String, family: ColorFamily, intensity: Double = 0.5, warmth: Double = 0.0) {
        self.hex = hex
        self.name = name
        self.family = family
        self.intensity = intensity
        self.warmth = warmth
    }
}

public enum ColorFamily: String, Codable {
    case red, orange, yellow, green, blue, purple, pink, brown, black, white, gray
}

public enum GarmentPattern: String, Codable {
    case solid, stripes, checks, polkaDots, floral, geometric, abstract, plaid
}

public enum GarmentFinish: String, Codable {
    case standard, matte, glossy, metallic, distressed, washed, pressed
}

public enum WeatheringLevel: String, Codable {
    case none, light, medium, heavy, vintage
}

public enum FitType: String, Codable {
    case skinny, slim, fitted, regular, relaxed, loose, oversized

    public var rawValue: Int {
        return FitType.allCases.firstIndex(of: self) ?? 3
    }
}

// MARK: - Fabric Properties

public struct FabricProperties: Codable {
    public let type: FabricType
    public let composition: FabricComposition
    public let weight: Double // grams per square meter
    public let thickness: Double // millimeters
    public let tensileStrength: Double // N/cm
    public let elasticity: Double // 0.0 to 1.0
    public let shearStrength: Double
    public let bendingResistance: Double
    public let friction: Double // 0.0 to 1.0
    public let airPermeability: Double // 0.0 to 1.0
    public let moistureWicking: Double // 0.0 to 1.0
    public let stretchRecovery: Double // 0.0 to 1.0
    public let wrinkleResistance: Double // 0.0 to 1.0
    public let pilling: Double // 0.0 to 1.0 (higher = more prone)
    public let colorfastness: Double // 0.0 to 1.0
    public let shrinkage: Double // 0.0 to 1.0
    public let drape: Double // 0.0 to 1.0
    public let stiffness: Double // 0.0 to 1.0
    public let airResistance: Double
    public let breathability: Double

    public init(
        type: FabricType,
        composition: FabricComposition,
        weight: Double,
        thickness: Double = 0.5,
        tensileStrength: Double = 100.0,
        elasticity: Double = 0.1,
        shearStrength: Double = 50.0,
        bendingResistance: Double = 0.3,
        friction: Double = 0.4,
        airPermeability: Double = 0.5,
        moistureWicking: Double = 0.3,
        stretchRecovery: Double = 0.8,
        wrinkleResistance: Double = 0.6,
        pilling: Double = 0.2,
        colorfastness: Double = 0.9,
        shrinkage: Double = 0.02,
        drape: Double = 0.7,
        stiffness: Double = 0.3,
        airResistance: Double = 0.1,
        breathability: Double = 0.6
    ) {
        self.type = type
        self.composition = composition
        self.weight = weight
        self.thickness = thickness
        self.tensileStrength = tensileStrength
        self.elasticity = elasticity
        self.shearStrength = shearStrength
        self.bendingResistance = bendingResistance
        self.friction = friction
        self.airPermeability = airPermeability
        self.moistureWicking = moistureWicking
        self.stretchRecovery = stretchRecovery
        self.wrinkleResistance = wrinkleResistance
        self.pilling = pilling
        self.colorfastness = colorfastness
        self.shrinkage = shrinkage
        self.drape = drape
        self.stiffness = stiffness
        self.airResistance = airResistance
        self.breathability = breathability
    }
}

public enum FabricType: String, Codable {
    case cotton, silk, wool, linen, polyester, nylon, spandex, denim, leather, synthetic
}

public struct FabricComposition: Codable {
    public let materials: [FabricMaterial]

    public init(materials: [FabricMaterial]) {
        self.materials = materials
    }

    public init(_ material: FabricType, percentage: Double = 100.0) {
        self.materials = [FabricMaterial(type: material, percentage: percentage)]
    }
}

public struct FabricMaterial: Codable {
    public let type: FabricType
    public let percentage: Double

    public init(type: FabricType, percentage: Double) {
        self.type = type
        self.percentage = percentage
    }
}

// MARK: - Size System

public struct Size: Codable, Hashable, Comparable {
    public let system: SizeSystem
    public let value: String
    public let numericValue: Double

    public init(system: SizeSystem, value: String, numericValue: Double) {
        self.system = system
        self.value = value
        self.numericValue = numericValue
    }

    public static func < (lhs: Size, rhs: Size) -> Bool {
        return lhs.numericValue < rhs.numericValue
    }

    public func smaller() -> Size? {
        let newValue = numericValue - 1
        guard newValue >= 0 else { return nil }
        return Size(system: system, value: "\(Int(newValue))", numericValue: newValue)
    }

    public func larger() -> Size? {
        let newValue = numericValue + 1
        return Size(system: system, value: "\(Int(newValue))", numericValue: newValue)
    }

    public static func fromNumericValue(_ value: Double) -> Size {
        return Size(system: .us, value: "\(Int(value))", numericValue: value)
    }
}

public enum SizeSystem: String, Codable {
    case us, uk, eu, jp, international
}

public struct EaseAllowance: Codable {
    public let shoulder: Double
    public let chest: Double
    public let waist: Double
    public let hip: Double
    public let leg: Double

    public init(shoulder: Double, chest: Double, waist: Double, hip: Double, leg: Double) {
        self.shoulder = shoulder
        self.chest = chest
        self.waist = waist
        self.hip = hip
        self.leg = leg
    }

    public static let standard = EaseAllowance(
        shoulder: 0.02, // 2cm ease
        chest: 0.05,    // 5cm ease
        waist: 0.03,    // 3cm ease
        hip: 0.04,      // 4cm ease
        leg: 0.02       // 2cm ease
    )
}

// MARK: - Care Instructions

public struct CareInstructions: Codable {
    public let washingTemperature: WashingTemperature
    public let dryingMethod: DryingMethod
    public let ironingTemperature: IroningTemperature
    public let dryCleanOnly: Bool
    public let bleachSafe: Bool
    public let specialInstructions: [String]

    public init(
        washingTemperature: WashingTemperature = .cold,
        dryingMethod: DryingMethod = .airDry,
        ironingTemperature: IroningTemperature = .low,
        dryCleanOnly: Bool = false,
        bleachSafe: Bool = false,
        specialInstructions: [String] = []
    ) {
        self.washingTemperature = washingTemperature
        self.dryingMethod = dryingMethod
        self.ironingTemperature = ironingTemperature
        self.dryCleanOnly = dryCleanOnly
        self.bleachSafe = bleachSafe
        self.specialInstructions = specialInstructions
    }
}

public enum WashingTemperature: String, Codable {
    case cold, warm, hot, handWashOnly
}

public enum DryingMethod: String, Codable {
    case airDry, lowHeat, mediumHeat, highHeat, dryCleanOnly
}

public enum IroningTemperature: String, Codable {
    case none, low, medium, high
}

// MARK: - Body Mesh and Geometry

public struct BodyMesh: Codable {
    public let vertices: [SIMD3<Float>]
    public let faces: [SIMD3<UInt32>]
    public let normals: [SIMD3<Float>]
    public let isAnonymized: Bool

    public init(vertices: [SIMD3<Float>], faces: [SIMD3<UInt32>], normals: [SIMD3<Float>], isAnonymized: Bool = false) {
        self.vertices = vertices
        self.faces = faces
        self.normals = normals
        self.isAnonymized = isAnonymized
    }

    // Body landmark extraction methods
    public var shoulderHeight: Float {
        return vertices.map { $0.y }.max() ?? 0
    }

    public var chestHeight: Float {
        return shoulderHeight * 0.8
    }

    public var waistHeight: Float {
        return shoulderHeight * 0.6
    }

    public var hipHeight: Float {
        return shoulderHeight * 0.4
    }

    public func extractSpinePoints() -> [SIMD3<Float>] {
        // Extract spine curve points from mesh
        return vertices.filter { vertex in
            abs(vertex.x) < 0.05 // Points near centerline
        }.sorted { $0.y > $1.y } // Top to bottom
    }

    public func extractShoulderPoints() -> [SIMD3<Float>] {
        let shoulderY = shoulderHeight
        return vertices.filter { vertex in
            abs(vertex.y - shoulderY) < 0.03
        }.sorted { $0.x < $1.x }
    }

    public func extractPelvisPoints() -> [SIMD3<Float>] {
        let hipY = hipHeight
        return vertices.filter { vertex in
            abs(vertex.y - hipY) < 0.03
        }.sorted { $0.x < $1.x }
    }

    public func extractMuscleRegions() -> [MuscleRegion] {
        // Identify muscle definition from mesh geometry
        return []
    }

    public func extractFatRegions() -> [FatRegion] {
        // Identify fat distribution patterns
        return []
    }

    public var shoulderPoints: [SIMD3<Float>] { extractShoulderPoints() }
    public var neckPoint: SIMD3<Float> { SIMD3<Float>(0, shoulderHeight + 0.1, 0) }
    public var waistPoint: SIMD3<Float> { SIMD3<Float>(0, waistHeight, 0) }
    public var hipPoints: [SIMD3<Float>] { extractPelvisPoints() }
}

public struct GarmentMesh: Codable {
    public let vertices: [SIMD3<Float>]
    public let faces: [SIMD3<UInt32>]
    public let uvCoordinates: [SIMD2<Float>]
    public let attachmentPoints: [AttachmentPoint]
    public let stretchZones: [StretchZone]

    public init(
        vertices: [SIMD3<Float>],
        faces: [SIMD3<UInt32>],
        uvCoordinates: [SIMD2<Float>],
        attachmentPoints: [AttachmentPoint],
        stretchZones: [StretchZone]
    ) {
        self.vertices = vertices
        self.faces = faces
        self.uvCoordinates = uvCoordinates
        self.attachmentPoints = attachmentPoints
        self.stretchZones = stretchZones
    }
}

public struct AttachmentPoint: Codable {
    public let position: SIMD3<Float>
    public let type: AttachmentType

    public init(position: SIMD3<Float>, type: AttachmentType) {
        self.position = position
        self.type = type
    }
}

public enum AttachmentType: String, Codable {
    case shoulder, neck, waist, hip, wrist, ankle
}

public struct AttachmentAnchor {
    public let point: SIMD3<Float>
    public let type: AttachmentType

    public init(point: SIMD3<Float>, type: AttachmentType) {
        self.point = point
        self.type = type
    }
}

public struct StretchZone: Codable {
    public let vertices: [Int]
    public let stretchFactor: Double
    public let direction: SIMD3<Float>

    public init(vertices: [Int], stretchFactor: Double, direction: SIMD3<Float>) {
        self.vertices = vertices
        self.stretchFactor = stretchFactor
        self.direction = direction
    }
}

// MARK: - Posture Analysis

public struct PostureAnalysis: Codable {
    public let shoulderAlignment: AlignmentMetric
    public let spinalCurvature: CurvatureMetric
    public let pelvisAlignment: AlignmentMetric
    public let bodySymmetry: SymmetryMetric
    public let isGeneralized: Bool

    public init(
        shoulderAlignment: AlignmentMetric,
        spinalCurvature: CurvatureMetric,
        pelvisAlignment: AlignmentMetric,
        bodySymmetry: SymmetryMetric,
        isGeneralized: Bool = false
    ) {
        self.shoulderAlignment = shoulderAlignment
        self.spinalCurvature = spinalCurvature
        self.pelvisAlignment = pelvisAlignment
        self.bodySymmetry = bodySymmetry
        self.isGeneralized = isGeneralized
    }
}

public struct AlignmentMetric: Codable {
    public let leftSide: Double
    public let rightSide: Double
    public let asymmetry: Double

    public init(leftSide: Double, rightSide: Double, asymmetry: Double) {
        self.leftSide = leftSide
        self.rightSide = rightSide
        self.asymmetry = asymmetry
    }

    public var generalized: AlignmentMetric {
        return AlignmentMetric(
            leftSide: (leftSide / 0.1).rounded() * 0.1,
            rightSide: (rightSide / 0.1).rounded() * 0.1,
            asymmetry: (asymmetry / 0.1).rounded() * 0.1
        )
    }
}

public struct CurvatureMetric: Codable {
    public let cervical: Double
    public let thoracic: Double
    public let lumbar: Double

    public init(cervical: Double, thoracic: Double, lumbar: Double) {
        self.cervical = cervical
        self.thoracic = thoracic
        self.lumbar = lumbar
    }

    public var generalized: CurvatureMetric {
        return CurvatureMetric(
            cervical: (cervical / 0.1).rounded() * 0.1,
            thoracic: (thoracic / 0.1).rounded() * 0.1,
            lumbar: (lumbar / 0.1).rounded() * 0.1
        )
    }
}

public struct SymmetryMetric: Codable {
    public let overall: Double
    public let torso: Double
    public let limbs: Double

    public init(overall: Double, torso: Double, limbs: Double) {
        self.overall = overall
        self.torso = torso
        self.limbs = limbs
    }

    public var generalized: SymmetryMetric {
        return SymmetryMetric(
            overall: (overall / 0.1).rounded() * 0.1,
            torso: (torso / 0.1).rounded() * 0.1,
            limbs: (limbs / 0.1).rounded() * 0.1
        )
    }
}

// MARK: - Anatomical Landmarks

public struct AnatomicalLandmarks: Codable {
    public let shoulderPoints: [SIMD3<Float>]
    public let waistPoints: [SIMD3<Float>]
    public let hipPoints: [SIMD3<Float>]

    public init(shoulderPoints: [SIMD3<Float>], waistPoints: [SIMD3<Float>], hipPoints: [SIMD3<Float>]) {
        self.shoulderPoints = shoulderPoints
        self.waistPoints = waistPoints
        self.hipPoints = hipPoints
    }
}

// MARK: - Fit Preferences

public struct FitPreferences: Codable {
    public let preferredFit: PreferredFit
    public let activityLevel: ActivityLevel
    public let comfortPriority: Priority
    public let stylePreference: StylePreference
    public let returnRiskTolerance: RiskTolerance

    public init(
        preferredFit: PreferredFit,
        activityLevel: ActivityLevel,
        comfortPriority: Priority,
        stylePreference: StylePreference,
        returnRiskTolerance: RiskTolerance = .medium
    ) {
        self.preferredFit = preferredFit
        self.activityLevel = activityLevel
        self.comfortPriority = comfortPriority
        self.stylePreference = stylePreference
        self.returnRiskTolerance = returnRiskTolerance
    }
}

public enum PreferredFit: String, Codable, CaseIterable {
    case tight, fitted, regular, relaxed, loose

    public var rawValue: Int {
        return PreferredFit.allCases.firstIndex(of: self) ?? 2
    }
}

public enum ActivityLevel: String, Codable, CaseIterable {
    case sedentary, moderate, active, athletic

    public var rawValue: Int {
        return ActivityLevel.allCases.firstIndex(of: self) ?? 1
    }
}

public enum Priority: String, Codable {
    case low, medium, high
}

public enum StylePreference: String, Codable {
    case classic, trendy, edgy, bohemian, minimalist
}

public enum RiskTolerance: String, Codable {
    case low, medium, high
}

// MARK: - Seasonal and Occasion

public enum Season: String, Codable, CaseIterable {
    case spring, summer, fall, winter
}

public enum Occasion: String, Codable {
    case casual, work, formal, party, athletic, travel, date
}

// MARK: - Pricing

public struct PriceRange: Codable {
    public let min: Double
    public let max: Double
    public let currency: String

    public init(min: Double, max: Double, currency: String = "USD") {
        self.min = min
        self.max = max
        self.currency = currency
    }
}

// MARK: - Muscle and Fat Analysis

public struct MuscleRegion {
    public let definition: Double
}

public struct FatRegion {
    public let density: Double
}

// MARK: - Body Pose

public struct BodyPose: Codable {
    public let joints: [String: SIMD3<Float>]
    public let confidence: Float

    public init(joints: [String: SIMD3<Float>], confidence: Float) {
        self.joints = joints
        self.confidence = confidence
    }

    public init(from bodyAnchor: ARBodyAnchor) {
        var jointPositions: [String: SIMD3<Float>] = [:]

        // Extract joint positions from ARBodyAnchor
        let skeleton = bodyAnchor.skeleton
        for jointName in ARSkeletonDefinition.defaultBody3D.jointNames {
            if let transform = skeleton.modelTransform(for: ARSkeleton.JointName(rawValue: jointName)) {
                jointPositions[jointName] = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            }
        }

        self.joints = jointPositions
        self.confidence = 1.0 // ARKit provides high confidence poses
    }

    public static let standing = BodyPose(joints: [:], confidence: 1.0)
}

// MARK: - Physics Simulation Types

public struct PhysicsSimulation {
    public let steps: [SimulationStep]
    public let finalMesh: [SIMD3<Float>]
    public let stressAnalysis: StressAnalysis
    public let deformationMap: DeformationMap
    public let tensionPoints: [TensionPoint]

    public init(steps: [SimulationStep], finalMesh: [SIMD3<Float>], stressAnalysis: StressAnalysis, deformationMap: DeformationMap, tensionPoints: [TensionPoint]) {
        self.steps = steps
        self.finalMesh = finalMesh
        self.stressAnalysis = stressAnalysis
        self.deformationMap = deformationMap
        self.tensionPoints = tensionPoints
    }
}

public struct SimulationStep {
    public let timeIndex: Int
    public let vertices: [SIMD3<Float>]
    public let velocities: [SIMD3<Float>]
    public let forces: [SIMD3<Float>]
    public let collisions: [Collision]
    public let constraints: [Constraint]

    public init(timeIndex: Int, vertices: [SIMD3<Float>], velocities: [SIMD3<Float>], forces: [SIMD3<Float>], collisions: [Collision], constraints: [Constraint]) {
        self.timeIndex = timeIndex
        self.vertices = vertices
        self.velocities = velocities
        self.forces = forces
        self.collisions = collisions
        self.constraints = constraints
    }
}

public struct StressAnalysis {
    // Placeholder for stress analysis data
}

public struct DeformationMap {
    public let averageDeformation: Double

    public init(averageDeformation: Double) {
        self.averageDeformation = averageDeformation
    }
}

public struct TensionPoint {
    public let position: SIMD3<Float>
    public let tension: Double

    public init(position: SIMD3<Float>, tension: Double) {
        self.position = position
        self.tension = tension
    }
}

public struct Collision {
    // Placeholder for collision data
}

public struct Constraint {
    // Placeholder for constraint data
}

// MARK: - Additional Supporting Types

public struct GarmentPublicInfo: Codable {
    public let type: GarmentType
    public let style: GarmentStyle
    public let color: GarmentColor
    public let pattern: GarmentPattern
    public let occasions: [Occasion]
}

// More supporting types and extensions can be added as needed...