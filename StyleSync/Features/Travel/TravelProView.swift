import SwiftUI
import SceneKit
import PDFKit

struct TravelProView: View {
    @StateObject private var travelManager = TravelProManager()
    @State private var showingTripCreator = false
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack {
                if travelManager.trips.isEmpty {
                    emptyStateView
                } else {
                    TabView(selection: $selectedTab) {
                        TripOverviewView(travelManager: travelManager)
                            .tabItem {
                                Image(systemName: "suitcase.rolling.fill")
                                Text("Trips")
                            }
                            .tag(0)

                        PackingListView(travelManager: travelManager)
                            .tabItem {
                                Image(systemName: "checklist")
                                Text("Packing")
                            }
                            .tag(1)

                        SuitcaseVisualizationView(travelManager: travelManager)
                            .tabItem {
                                Image(systemName: "cube.transparent.fill")
                                Text("3D View")
                            }
                            .tag(2)

                        OutfitScheduleView(travelManager: travelManager)
                            .tabItem {
                                Image(systemName: "calendar.circle.fill")
                                Text("Schedule")
                            }
                            .tag(3)
                    }
                }
            }
            .navigationTitle("Travel Pro")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("New Trip") {
                        showingTripCreator = true
                    }
                    .premiumGate(
                        feature: .shoppingCompanion,
                        premiumManager: PremiumManager()
                    ) {
                        // Show paywall
                    }
                }
            }
            .sheet(isPresented: $showingTripCreator) {
                TripCreatorView { trip in
                    Task {
                        await travelManager.createTrip(
                            destinations: trip.destinations,
                            tripType: trip.type,
                            duration: trip.duration
                        )
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            VStack(spacing: 12) {
                Text("Plan Your Perfect Trip")
                    .font(.title)
                    .fontWeight(.bold)

                Text("AI-powered packing assistance with weather research, 3D visualization, and smart optimization")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("Create Your First Trip") {
                showingTripCreator = true
            }
            .buttonStyle(PremiumButtonStyle())

            VStack(spacing: 16) {
                Text("Premium Travel Features")
                    .font(.headline)
                    .fontWeight(.medium)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    featureCard(
                        icon: "cloud.sun.rain.fill",
                        title: "Weather Research",
                        description: "Real-time weather forecasts for all destinations"
                    )
                    featureCard(
                        icon: "cube.transparent.fill",
                        title: "3D Packing",
                        description: "Visualize your suitcase layout in 3D"
                    )
                    featureCard(
                        icon: "airplane.circle.fill",
                        title: "Airline Rules",
                        description: "Automatic restriction checking"
                    )
                    featureCard(
                        icon: "doc.pdf.fill",
                        title: "PDF Guides",
                        description: "Export beautiful packing guides"
                    )
                }
            }
            .padding(.top, 32)
        }
        .padding()
    }

    private func featureCard(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)

            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

// MARK: - Trip Creator
struct TripCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var destinations: [Destination] = []
    @State private var tripType: TripType = .leisure
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var showingDestinationPicker = false

    let onTripCreated: (TravelTrip) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Type") {
                    Picker("Type", selection: $tripType) {
                        ForEach(TripType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section("Destinations") {
                    ForEach(destinations) { destination in
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(destination.name)
                                    .font(.headline)
                                Text(destination.country)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Remove") {
                                destinations.removeAll { $0.id == destination.id }
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                        }
                    }

                    Button("Add Destination") {
                        showingDestinationPicker = true
                    }
                }

                Section("Duration") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }

                Section {
                    Button("Create Trip") {
                        let trip = TravelTrip(
                            id: UUID(),
                            destinations: destinations,
                            type: tripType,
                            duration: DateInterval(start: startDate, end: endDate),
                            createdAt: Date()
                        )
                        onTripCreated(trip)
                        dismiss()
                    }
                    .disabled(destinations.isEmpty)
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingDestinationPicker) {
                DestinationPickerView { destination in
                    destinations.append(destination)
                }
            }
        }
    }
}

// MARK: - Destination Picker
struct DestinationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedActivities: [Activity] = []

    let onDestinationSelected: (Destination) -> Void

    private let popularDestinations = [
        ("Paris", "France", CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)),
        ("Tokyo", "Japan", CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)),
        ("New York", "USA", CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)),
        ("London", "UK", CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)),
        ("Dubai", "UAE", CLLocationCoordinate2D(latitude: 25.2048, longitude: 55.2708)),
    ]

    var body: some View {
        NavigationStack {
            VStack {
                SearchBar(text: $searchText, placeholder: "Search destinations...")

                List {
                    Section("Popular Destinations") {
                        ForEach(popularDestinations, id: \.0) { name, country, coordinate in
                            Button(action: {
                                let destination = Destination(
                                    id: UUID(),
                                    name: name,
                                    country: country,
                                    coordinate: coordinate,
                                    activities: selectedActivities,
                                    culturalNorms: []
                                )
                                onDestinationSelected(destination)
                                dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(name)
                                            .font(.headline)
                                        Text(country)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    Section("Planned Activities") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(ActivityCategory.allCases, id: \.self) { category in
                                ActivityChip(
                                    category: category,
                                    isSelected: selectedActivities.contains { $0.category == category }
                                ) {
                                    if let index = selectedActivities.firstIndex(where: { $0.category == category }) {
                                        selectedActivities.remove(at: index)
                                    } else {
                                        selectedActivities.append(Activity(
                                            id: UUID(),
                                            name: category.rawValue,
                                            category: category,
                                            dressCode: .casual,
                                            weatherDependency: category == .outdoor
                                        ))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ActivityChip: View {
    let category: ActivityCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(category.rawValue)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Trip Overview
struct TripOverviewView: View {
    @ObservedObject var travelManager: TravelProManager

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(travelManager.trips) { trip in
                    TripCard(trip: trip, travelManager: travelManager)
                }
            }
            .padding()
        }
    }
}

struct TripCard: View {
    let trip: TravelTrip
    @ObservedObject var travelManager: TravelProManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(destinationNames)
                        .font(.headline)
                        .fontWeight(.bold)

                    Text(dateRange)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: trip.type.icon)
                        .font(.title2)
                        .foregroundColor(.blue)

                    Text(trip.type.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Weather summary
            if let firstDestination = trip.destinations.first,
               let weather = travelManager.weatherData[firstDestination.id.uuidString] {
                WeatherSummaryView(weather: weather)
            }

            // Packing progress
            if let packingList = trip.packingList {
                PackingProgressView(packingList: packingList)
            }

            HStack {
                Button("View Details") {
                    travelManager.currentTrip = trip
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button("Export PDF") {
                    exportTripToPDF(trip)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    private var destinationNames: String {
        trip.destinations.map(\.name).joined(separator: " → ")
    }

    private var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: trip.duration.start)) - \(formatter.string(from: trip.duration.end))"
    }

    private func exportTripToPDF(_ trip: TravelTrip) {
        let pdfExporter = TravelPDFExporter()
        pdfExporter.exportTrip(trip)
    }
}

struct WeatherSummaryView: View {
    let weather: WeatherForecast

    var body: some View {
        HStack {
            Image(systemName: "cloud.sun.fill")
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Weather Forecast")
                    .font(.caption)
                    .fontWeight(.medium)

                Text("\(Int(weather.overallTrend.averageTemp))°C avg, \(weather.overallTrend.rainDays) rainy days")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PackingProgressView: View {
    let packingList: PackingList

    private var packedItems: Int {
        packingList.categories.flatMap(\.items).filter(\.isPacked).count
    }

    private var totalItems: Int {
        packingList.categories.flatMap(\.items).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Packing Progress")
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                Text("\(packedItems)/\(totalItems)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: Double(packedItems), total: Double(totalItems))
                .progressViewStyle(LinearProgressViewStyle())

            HStack {
                Text("\(String(format: "%.1f", packingList.totalWeight))kg total")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(packingList.spaceOptimization.spaceUtilization * 100))% optimized")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())

            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .foregroundColor(.secondary)
                .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}

#Preview {
    TravelProView()
}