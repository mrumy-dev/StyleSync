import SwiftUI
import Foundation
import CoreLocation
import PDFKit

@MainActor
class TravelProManager: ObservableObject {
    @Published var trips: [TravelTrip] = []
    @Published var currentTrip: TravelTrip?
    @Published var isLoading = false
    @Published var weatherData: [String: WeatherForecast] = [:]
    @Published var airlineRestrictions: [AirlineRestriction] = []

    private let weatherService = WeatherService()
    private let airlineService = AirlineService()

    func createTrip(destinations: [Destination], tripType: TripType, duration: DateInterval) async {
        isLoading = true

        let trip = TravelTrip(
            id: UUID(),
            destinations: destinations,
            type: tripType,
            duration: duration,
            createdAt: Date()
        )

        trips.append(trip)
        currentTrip = trip

        await loadTripData(for: trip)
        isLoading = false
    }

    private func loadTripData(for trip: TravelTrip) async {
        await withTaskGroup(of: Void.self) { group in
            // Load weather for each destination
            for destination in trip.destinations {
                group.addTask {
                    await self.loadWeather(for: destination)
                }
            }

            // Load airline restrictions
            group.addTask {
                await self.loadAirlineRestrictions()
            }
        }

        generatePackingRecommendations(for: trip)
    }

    private func loadWeather(for destination: Destination) async {
        do {
            let forecast = try await weatherService.getForecast(
                for: destination.coordinate,
                during: currentTrip?.duration ?? DateInterval(start: Date(), duration: 604800)
            )
            weatherData[destination.id.uuidString] = forecast
        } catch {
            print("Failed to load weather for \(destination.name): \(error)")
        }
    }

    private func loadAirlineRestrictions() async {
        do {
            airlineRestrictions = try await airlineService.getRestrictions()
        } catch {
            print("Failed to load airline restrictions: \(error)")
        }
    }

    private func generatePackingRecommendations(for trip: TravelTrip) {
        guard var trip = currentTrip else { return }

        let packingEngine = PackingEngine()
        trip.packingList = packingEngine.generatePackingList(
            for: trip,
            weather: weatherData,
            restrictions: airlineRestrictions
        )

        currentTrip = trip
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
        }
    }
}

// MARK: - Travel Models
struct TravelTrip: Identifiable, Codable {
    let id: UUID
    var destinations: [Destination]
    let type: TripType
    let duration: DateInterval
    let createdAt: Date
    var packingList: PackingList?
    var outfitSchedule: [OutfitScheduleDay] = []
    var suitcaseLayout: SuitcaseLayout?
    var emergencyOutfit: EmergencyOutfit?
}

struct Destination: Identifiable, Codable {
    let id: UUID
    let name: String
    let country: String
    let coordinate: CLLocationCoordinate2D
    let activities: [Activity]
    let culturalNorms: [CulturalNorm]
}

enum TripType: String, CaseIterable, Codable {
    case business = "Business"
    case leisure = "Leisure"
    case mixed = "Mixed"
    case adventure = "Adventure"
    case luxury = "Luxury"

    var icon: String {
        switch self {
        case .business: return "briefcase.fill"
        case .leisure: return "beach.umbrella.fill"
        case .mixed: return "suitcase.rolling.fill"
        case .adventure: return "mountain.2.fill"
        case .luxury: return "crown.fill"
        }
    }
}

struct Activity: Identifiable, Codable {
    let id: UUID
    let name: String
    let category: ActivityCategory
    let dressCode: DressCode
    let weatherDependency: Bool
}

enum ActivityCategory: String, CaseIterable, Codable {
    case dining = "Dining"
    case sightseeing = "Sightseeing"
    case business = "Business"
    case outdoor = "Outdoor"
    case nightlife = "Nightlife"
    case cultural = "Cultural"
    case sports = "Sports"
    case shopping = "Shopping"
}

enum DressCode: String, CaseIterable, Codable {
    case casual = "Casual"
    case smartCasual = "Smart Casual"
    case business = "Business"
    case formal = "Formal"
    case activewear = "Activewear"
    case swimwear = "Swimwear"
}

struct CulturalNorm: Codable {
    let description: String
    let clothingImplication: String
}

// MARK: - Weather Service
struct WeatherForecast: Codable {
    let dailyForecasts: [DailyForecast]
    let overallTrend: WeatherTrend
}

struct DailyForecast: Codable {
    let date: Date
    let minTemp: Double
    let maxTemp: Double
    let condition: WeatherCondition
    let precipitation: Double
    let humidity: Double
    let windSpeed: Double
}

enum WeatherCondition: String, CaseIterable, Codable {
    case sunny = "Sunny"
    case partlyCloudy = "Partly Cloudy"
    case cloudy = "Cloudy"
    case rainy = "Rainy"
    case stormy = "Stormy"
    case snowy = "Snowy"
    case foggy = "Foggy"
}

struct WeatherTrend: Codable {
    let averageTemp: Double
    let rainDays: Int
    let extremeWeatherAlerts: [WeatherAlert]
}

struct WeatherAlert: Codable {
    let type: String
    let description: String
    let packingAdvice: String
}

class WeatherService {
    func getForecast(for coordinate: CLLocationCoordinate2D, during interval: DateInterval) async throws -> WeatherForecast {
        // Simulate API call - In production, use actual weather service
        await Task.sleep(nanoseconds: 1_000_000_000)

        let calendar = Calendar.current
        var dailyForecasts: [DailyForecast] = []

        let startDate = interval.start
        let days = Int(interval.duration / 86400)

        for day in 0..<days {
            if let date = calendar.date(byAdding: .day, value: day, to: startDate) {
                dailyForecasts.append(DailyForecast(
                    date: date,
                    minTemp: Double.random(in: 15...25),
                    maxTemp: Double.random(in: 20...30),
                    condition: WeatherCondition.allCases.randomElement() ?? .sunny,
                    precipitation: Double.random(in: 0...10),
                    humidity: Double.random(in: 40...80),
                    windSpeed: Double.random(in: 5...20)
                ))
            }
        }

        return WeatherForecast(
            dailyForecasts: dailyForecasts,
            overallTrend: WeatherTrend(
                averageTemp: dailyForecasts.map(\.maxTemp).reduce(0, +) / Double(dailyForecasts.count),
                rainDays: dailyForecasts.filter { $0.condition == .rainy || $0.condition == .stormy }.count,
                extremeWeatherAlerts: []
            )
        )
    }
}

// MARK: - Airline Service
struct AirlineRestriction: Identifiable, Codable {
    let id: UUID
    let airline: String
    let carryOnWeight: Double
    let carryOnDimensions: Dimensions
    let checkedBagWeight: Double
    let checkedBagDimensions: Dimensions
    let prohibitedItems: [String]
    let liquidRestrictions: LiquidRestriction
}

struct Dimensions: Codable {
    let length: Double
    let width: Double
    let height: Double

    var volume: Double {
        length * width * height
    }
}

struct LiquidRestriction: Codable {
    let maxContainerSize: Double // in ml
    let maxTotalVolume: Double // in ml
    let requiresClearBag: Bool
}

class AirlineService {
    func getRestrictions() async throws -> [AirlineRestriction] {
        // Simulate API call - In production, use actual airline databases
        await Task.sleep(nanoseconds: 500_000_000)

        return [
            AirlineRestriction(
                id: UUID(),
                airline: "Standard International",
                carryOnWeight: 8.0,
                carryOnDimensions: Dimensions(length: 55, width: 40, height: 20),
                checkedBagWeight: 23.0,
                checkedBagDimensions: Dimensions(length: 158, width: 50, height: 30),
                prohibitedItems: ["Sharp objects", "Liquids over 100ml", "Batteries"],
                liquidRestrictions: LiquidRestriction(
                    maxContainerSize: 100,
                    maxTotalVolume: 1000,
                    requiresClearBag: true
                )
            )
        ]
    }
}

// MARK: - Packing Engine
struct PackingList: Codable {
    var categories: [PackingCategory]
    var totalWeight: Double
    var spaceOptimization: SpaceOptimization
    var laundryPlan: LaundryPlan?
}

struct PackingCategory: Identifiable, Codable {
    let id: UUID
    let name: String
    let items: [PackingItem]
    let priority: Priority

    enum Priority: String, CaseIterable, Codable {
        case essential = "Essential"
        case recommended = "Recommended"
        case optional = "Optional"
    }
}

struct PackingItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let quantity: Int
    let weight: Double
    let dimensions: Dimensions?
    let weatherSpecific: Bool
    let activitySpecific: [ActivityCategory]
    let versatilityScore: Double
    let imageURL: String?
    var isPacked: Bool = false
}

struct SpaceOptimization: Codable {
    let recommendedPackingOrder: [UUID] // Item IDs
    let foldingTechniques: [FoldingTechnique]
    let spaceUtilization: Double
    let weightDistribution: WeightDistribution
}

struct FoldingTechnique: Codable {
    let itemType: String
    let technique: String
    let spaceSavings: Double
    let instructionURL: String?
}

struct WeightDistribution: Codable {
    let carryOnWeight: Double
    let checkedBagWeight: Double
    let isOptimal: Bool
}

struct LaundryPlan: Codable {
    let recommendedWashDays: [Date]
    let essentialsToPackMultiple: [String]
    let laundryServiceLocations: [LaundryService]
}

struct LaundryService: Codable {
    let name: String
    let location: String
    let estimatedCost: Double
    let turnaroundTime: String
}

class PackingEngine {
    func generatePackingList(
        for trip: TravelTrip,
        weather: [String: WeatherForecast],
        restrictions: [AirlineRestriction]
    ) -> PackingList {
        var categories: [PackingCategory] = []

        // Essential clothing
        categories.append(generateClothingCategory(for: trip, weather: weather))

        // Toiletries & Personal Care
        categories.append(generateToiletriesCategory(restrictions: restrictions))

        // Electronics & Documents
        categories.append(generateElectronicsCategory(for: trip))

        // Activity-specific gear
        categories.append(generateActivityGearCategory(for: trip))

        // Calculate total weight and optimization
        let totalWeight = categories.flatMap(\.items).reduce(0) { $0 + $1.weight }

        let spaceOptimization = optimizeSpace(
            items: categories.flatMap(\.items),
            restrictions: restrictions
        )

        let laundryPlan = generateLaundryPlan(for: trip)

        return PackingList(
            categories: categories,
            totalWeight: totalWeight,
            spaceOptimization: spaceOptimization,
            laundryPlan: laundryPlan
        )
    }

    private func generateClothingCategory(
        for trip: TravelTrip,
        weather: [String: WeatherForecast]
    ) -> PackingCategory {
        var items: [PackingItem] = []

        // Base clothing calculation
        let days = Int(trip.duration.duration / 86400)
        let clothingMultiplier = trip.type == .business ? 1.2 : 0.8

        // Weather-adaptive clothing
        let avgTemp = weather.values.first?.overallTrend.averageTemp ?? 20
        let rainDays = weather.values.first?.overallTrend.rainDays ?? 0

        // Tops
        let topCount = max(3, Int(Double(days) * 0.7 * clothingMultiplier))
        items.append(PackingItem(
            id: UUID(),
            name: "Shirts/Tops",
            quantity: topCount,
            weight: Double(topCount) * 0.2,
            dimensions: nil,
            weatherSpecific: false,
            activitySpecific: [],
            versatilityScore: 0.9,
            imageURL: nil
        ))

        // Weather-specific items
        if avgTemp < 15 {
            items.append(PackingItem(
                id: UUID(),
                name: "Warm Jacket",
                quantity: 1,
                weight: 0.8,
                dimensions: nil,
                weatherSpecific: true,
                activitySpecific: [.outdoor],
                versatilityScore: 0.7,
                imageURL: nil
            ))
        }

        if rainDays > 2 {
            items.append(PackingItem(
                id: UUID(),
                name: "Rain Jacket",
                quantity: 1,
                weight: 0.3,
                dimensions: nil,
                weatherSpecific: true,
                activitySpecific: [.outdoor, .sightseeing],
                versatilityScore: 0.6,
                imageURL: nil
            ))
        }

        return PackingCategory(
            id: UUID(),
            name: "Clothing",
            items: items,
            priority: .essential
        )
    }

    private func generateToiletriesCategory(restrictions: [AirlineRestriction]) -> PackingCategory {
        let liquidLimit = restrictions.first?.liquidRestrictions.maxContainerSize ?? 100

        let items = [
            PackingItem(
                id: UUID(),
                name: "Toothbrush & Toothpaste",
                quantity: 1,
                weight: 0.1,
                dimensions: nil,
                weatherSpecific: false,
                activitySpecific: [],
                versatilityScore: 1.0,
                imageURL: nil
            ),
            PackingItem(
                id: UUID(),
                name: "Shampoo (\(Int(liquidLimit))ml)",
                quantity: 1,
                weight: 0.1,
                dimensions: nil,
                weatherSpecific: false,
                activitySpecific: [],
                versatilityScore: 0.8,
                imageURL: nil
            )
        ]

        return PackingCategory(
            id: UUID(),
            name: "Toiletries",
            items: items,
            priority: .essential
        )
    }

    private func generateElectronicsCategory(for trip: TravelTrip) -> PackingCategory {
        var items = [
            PackingItem(
                id: UUID(),
                name: "Phone Charger",
                quantity: 1,
                weight: 0.2,
                dimensions: nil,
                weatherSpecific: false,
                activitySpecific: [],
                versatilityScore: 1.0,
                imageURL: nil
            ),
            PackingItem(
                id: UUID(),
                name: "Passport & Documents",
                quantity: 1,
                weight: 0.1,
                dimensions: nil,
                weatherSpecific: false,
                activitySpecific: [],
                versatilityScore: 1.0,
                imageURL: nil
            )
        ]

        if trip.type == .business {
            items.append(PackingItem(
                id: UUID(),
                name: "Laptop & Charger",
                quantity: 1,
                weight: 2.0,
                dimensions: Dimensions(length: 35, width: 25, height: 3),
                weatherSpecific: false,
                activitySpecific: [.business],
                versatilityScore: 0.9,
                imageURL: nil
            ))
        }

        return PackingCategory(
            id: UUID(),
            name: "Electronics & Documents",
            items: items,
            priority: .essential
        )
    }

    private func generateActivityGearCategory(for trip: TravelTrip) -> PackingCategory {
        var items: [PackingItem] = []

        let allActivities = trip.destinations.flatMap(\.activities)
        let uniqueCategories = Set(allActivities.map(\.category))

        for category in uniqueCategories {
            switch category {
            case .outdoor:
                items.append(PackingItem(
                    id: UUID(),
                    name: "Hiking Shoes",
                    quantity: 1,
                    weight: 1.2,
                    dimensions: nil,
                    weatherSpecific: false,
                    activitySpecific: [.outdoor],
                    versatilityScore: 0.6,
                    imageURL: nil
                ))
            case .swimming:
                items.append(PackingItem(
                    id: UUID(),
                    name: "Swimwear",
                    quantity: 2,
                    weight: 0.2,
                    dimensions: nil,
                    weatherSpecific: false,
                    activitySpecific: [.sports],
                    versatilityScore: 0.3,
                    imageURL: nil
                ))
            case .business:
                items.append(PackingItem(
                    id: UUID(),
                    name: "Business Shoes",
                    quantity: 1,
                    weight: 1.0,
                    dimensions: nil,
                    weatherSpecific: false,
                    activitySpecific: [.business],
                    versatilityScore: 0.7,
                    imageURL: nil
                ))
            default:
                break
            }
        }

        return PackingCategory(
            id: UUID(),
            name: "Activity Gear",
            items: items,
            priority: .recommended
        )
    }

    private func optimizeSpace(
        items: [PackingItem],
        restrictions: [AirlineRestriction]
    ) -> SpaceOptimization {
        // Sort items by versatility and space efficiency
        let sortedItems = items.sorted { item1, item2 in
            let efficiency1 = item1.versatilityScore / item1.weight
            let efficiency2 = item2.versatilityScore / item2.weight
            return efficiency1 > efficiency2
        }

        let techniques = [
            FoldingTechnique(
                itemType: "Shirts",
                technique: "Ranger Roll",
                spaceSavings: 0.4,
                instructionURL: "https://example.com/ranger-roll"
            ),
            FoldingTechnique(
                itemType: "Pants",
                technique: "Flat Fold",
                spaceSavings: 0.3,
                instructionURL: "https://example.com/flat-fold"
            )
        ]

        let totalWeight = items.reduce(0) { $0 + $1.weight }
        let carryOnLimit = restrictions.first?.carryOnWeight ?? 8.0
        let carryOnWeight = min(totalWeight * 0.6, carryOnLimit)

        return SpaceOptimization(
            recommendedPackingOrder: sortedItems.map(\.id),
            foldingTechniques: techniques,
            spaceUtilization: 0.85,
            weightDistribution: WeightDistribution(
                carryOnWeight: carryOnWeight,
                checkedBagWeight: totalWeight - carryOnWeight,
                isOptimal: carryOnWeight <= carryOnLimit
            )
        )
    }

    private func generateLaundryPlan(for trip: TravelTrip) -> LaundryPlan? {
        let days = Int(trip.duration.duration / 86400)
        guard days > 7 else { return nil }

        let washDays = stride(from: 7, to: days, by: 7).compactMap { day in
            Calendar.current.date(byAdding: .day, value: day, to: trip.duration.start)
        }

        return LaundryPlan(
            recommendedWashDays: washDays,
            essentialsToPackMultiple: ["Underwear", "Socks", "T-shirts"],
            laundryServiceLocations: [] // Would be populated with real data
        )
    }
}

// MARK: - Outfit Scheduling
struct OutfitScheduleDay: Identifiable, Codable {
    let id: UUID
    let date: Date
    let destination: Destination
    let activities: [Activity]
    let plannedOutfits: [PlannedOutfit]
    let weather: DailyForecast?
}

struct PlannedOutfit: Identifiable, Codable {
    let id: UUID
    let timeOfDay: TimeOfDay
    let activity: Activity
    let items: [PackingItem]
    let alternatives: [PackingItem]
    let culturalConsiderations: [String]
}

enum TimeOfDay: String, CaseIterable, Codable {
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"
    case night = "Night"
}

// MARK: - Emergency Outfit
struct EmergencyOutfit: Codable {
    let outfitCombination: [PackingItem]
    let scenarios: [EmergencyScenario]
    let storageLocation: String
}

struct EmergencyScenario: Codable {
    let situation: String
    let outfit: [PackingItem]
    let reasoning: String
}

// MARK: - 3D Suitcase Visualization
struct SuitcaseLayout: Codable {
    let suitcaseType: SuitcaseType
    let dimensions: Dimensions
    let layers: [PackingLayer]
    let weightDistribution: [WeightPoint]
}

enum SuitcaseType: String, CaseIterable, Codable {
    case carryOn = "Carry-On"
    case checkedMedium = "Checked Medium"
    case checkedLarge = "Checked Large"

    var standardDimensions: Dimensions {
        switch self {
        case .carryOn:
            return Dimensions(length: 55, width: 40, height: 20)
        case .checkedMedium:
            return Dimensions(length: 68, width: 48, height: 26)
        case .checkedLarge:
            return Dimensions(length: 78, width: 52, height: 30)
        }
    }
}

struct PackingLayer: Identifiable, Codable {
    let id: UUID
    let level: Int
    let items: [PlacedItem]
    let remainingSpace: Double
}

struct PlacedItem: Identifiable, Codable {
    let id: UUID
    let item: PackingItem
    let position: Position3D
    let rotation: Rotation3D
}

struct Position3D: Codable {
    let x: Double
    let y: Double
    let z: Double
}

struct Rotation3D: Codable {
    let x: Double
    let y: Double
    let z: Double
}

struct WeightPoint: Codable {
    let position: Position3D
    let weight: Double
}