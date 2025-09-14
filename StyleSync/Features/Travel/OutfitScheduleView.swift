import SwiftUI

struct OutfitScheduleView: View {
    @ObservedObject var travelManager: TravelProManager
    @State private var selectedDate: Date?
    @State private var showingOutfitCreator = false

    var body: some View {
        NavigationStack {
            VStack {
                if let trip = travelManager.currentTrip {
                    // Trip timeline
                    tripTimelineHeader(trip)

                    // Calendar view
                    outfitCalendarView(trip)

                    // Day details
                    if let selectedDate = selectedDate {
                        selectedDayView(trip: trip, date: selectedDate)
                    } else {
                        Spacer()
                        Text("Select a day to view outfit schedule")
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Outfit Schedule")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Auto-Schedule") {
                        generateOutfitSchedule()
                    }
                }
            }
            .sheet(isPresented: $showingOutfitCreator) {
                OutfitCreatorView(
                    trip: travelManager.currentTrip,
                    selectedDate: selectedDate ?? Date()
                ) { outfit in
                    addOutfitToSchedule(outfit)
                }
            }
        }
    }

    private func tripTimelineHeader(_ trip: TravelTrip) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trip Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(trip.duration.duration / 86400, format: .number) days")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Destinations")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(trip.destinations.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }

            // Destination timeline
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(trip.destinations) { destination in
                        DestinationTimelineCard(destination: destination)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.horizontal, -20)
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func outfitCalendarView(_ trip: TravelTrip) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Schedule")
                .font(.headline)
                .fontWeight(.medium)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(generateDateRange(from: trip.duration.start, to: trip.duration.end), id: \.self) { date in
                        DayCard(
                            date: date,
                            isSelected: selectedDate == date,
                            hasOutfits: hasOutfits(for: date, in: trip),
                            weather: getWeather(for: date, trip: trip)
                        ) {
                            selectedDate = date
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func selectedDayView(trip: TravelTrip, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Day header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(DateFormatter.weekdayAndDate.string(from: date))
                        .font(.title2)
                        .fontWeight(.bold)

                    if let destination = getDestination(for: date, trip: trip) {
                        Text(destination.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button("Add Outfit") {
                    showingOutfitCreator = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)

            // Weather info
            if let weather = getWeather(for: date, trip: trip) {
                WeatherInfoCard(weather: weather)
                    .padding(.horizontal)
            }

            // Planned activities
            if let activities = getActivities(for: date, trip: trip) {
                ActivitiesSection(activities: activities)
                    .padding(.horizontal)
            }

            // Outfit schedule
            outfitScheduleSection(for: date, trip: trip)

            Spacer()
        }
    }

    private func outfitScheduleSection(for date: Date, trip: TravelTrip) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Outfit Schedule")
                .font(.headline)
                .fontWeight(.medium)
                .padding(.horizontal)

            if let scheduleDay = trip.outfitSchedule.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
                LazyVStack(spacing: 12) {
                    ForEach(scheduleDay.plannedOutfits) { plannedOutfit in
                        PlannedOutfitCard(
                            outfit: plannedOutfit,
                            onEdit: { editOutfit(plannedOutfit) },
                            onDelete: { deleteOutfit(plannedOutfit) }
                        )
                    }
                }
                .padding(.horizontal)
            } else {
                EmptyOutfitScheduleView {
                    showingOutfitCreator = true
                }
                .padding(.horizontal)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Trip Selected")
                .font(.title2)
                .fontWeight(.medium)

            Text("Create a trip to schedule your daily outfits")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Helper Functions
    private func generateDateRange(from start: Date, to end: Date) -> [Date] {
        var dates: [Date] = []
        var currentDate = start

        while currentDate <= end {
            dates.append(currentDate)
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? end
        }

        return dates
    }

    private func hasOutfits(for date: Date, in trip: TravelTrip) -> Bool {
        return trip.outfitSchedule.contains { scheduleDay in
            Calendar.current.isDate(scheduleDay.date, inSameDayAs: date) && !scheduleDay.plannedOutfits.isEmpty
        }
    }

    private func getWeather(for date: Date, trip: TravelTrip) -> DailyForecast? {
        // In a real implementation, match date with weather forecast
        return travelManager.weatherData.values.first?.dailyForecasts.first { forecast in
            Calendar.current.isDate(forecast.date, inSameDayAs: date)
        }
    }

    private func getDestination(for date: Date, trip: TravelTrip) -> Destination? {
        // Simple implementation - return first destination
        // In a real app, this would track which destination you're at on each day
        return trip.destinations.first
    }

    private func getActivities(for date: Date, trip: TravelTrip) -> [Activity]? {
        // Return planned activities for the date
        return trip.destinations.first?.activities
    }

    private func generateOutfitSchedule() {
        // Auto-generate outfit schedule based on weather, activities, and available items
        guard var trip = travelManager.currentTrip else { return }

        let outfitScheduler = OutfitScheduler()
        trip.outfitSchedule = outfitScheduler.generateSchedule(
            for: trip,
            weather: travelManager.weatherData
        )

        travelManager.currentTrip = trip
        if let index = travelManager.trips.firstIndex(where: { $0.id == trip.id }) {
            travelManager.trips[index] = trip
        }
    }

    private func addOutfitToSchedule(_ outfit: PlannedOutfit) {
        // Add outfit to the schedule
    }

    private func editOutfit(_ outfit: PlannedOutfit) {
        // Edit existing outfit
    }

    private func deleteOutfit(_ outfit: PlannedOutfit) {
        // Delete outfit from schedule
    }
}

struct DestinationTimelineCard: View {
    let destination: Destination

    var body: some View {
        VStack(spacing: 8) {
            Text(destination.name)
                .font(.headline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)

            Text(destination.country)
                .font(.caption)
                .foregroundColor(.secondary)

            // Activity icons
            HStack(spacing: 4) {
                ForEach(destination.activities.prefix(3), id: \.id) { activity in
                    Image(systemName: activityIcon(activity.category))
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                if destination.activities.count > 3 {
                    Text("+\(destination.activities.count - 3)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 120, height: 80)
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    private func activityIcon(_ category: ActivityCategory) -> String {
        switch category {
        case .dining: return "fork.knife"
        case .sightseeing: return "camera"
        case .business: return "briefcase"
        case .outdoor: return "leaf"
        case .nightlife: return "moon.stars"
        case .cultural: return "building.columns"
        case .sports: return "figure.walk"
        case .shopping: return "bag"
        }
    }
}

struct DayCard: View {
    let date: Date
    let isSelected: Bool
    let hasOutfits: Bool
    let weather: DailyForecast?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : .primary)

                Text(DateFormatter.shortWeekday.string(from: date))
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)

                if let weather = weather {
                    Image(systemName: weatherIcon(weather.condition))
                        .font(.caption)
                        .foregroundColor(isSelected ? .white : .blue)
                }

                if hasOutfits {
                    Circle()
                        .fill(isSelected ? Color.white : Color.green)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 60, height: 80)
            .background(isSelected ? Color.blue : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func weatherIcon(_ condition: WeatherCondition) -> String {
        switch condition {
        case .sunny: return "sun.max"
        case .partlyCloudy: return "cloud.sun"
        case .cloudy: return "cloud"
        case .rainy: return "cloud.rain"
        case .stormy: return "cloud.bolt"
        case .snowy: return "cloud.snow"
        case .foggy: return "cloud.fog"
        }
    }
}

struct WeatherInfoCard: View {
    let weather: DailyForecast

    var body: some View {
        HStack {
            Image(systemName: weatherIcon(weather.condition))
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(weather.condition.rawValue)
                    .font(.headline)
                    .fontWeight(.medium)

                Text("\(Int(weather.minTemp))° - \(Int(weather.maxTemp))°C")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if weather.precipitation > 0 {
                    HStack {
                        Image(systemName: "drop")
                            .foregroundColor(.blue)
                        Text("\(Int(weather.precipitation))%")
                    }
                    .font(.caption)
                }

                HStack {
                    Image(systemName: "wind")
                        .foregroundColor(.gray)
                    Text("\(Int(weather.windSpeed)) km/h")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func weatherIcon(_ condition: WeatherCondition) -> String {
        switch condition {
        case .sunny: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy: return "cloud.fill"
        case .rainy: return "cloud.rain.fill"
        case .stormy: return "cloud.bolt.fill"
        case .snowy: return "cloud.snow.fill"
        case .foggy: return "cloud.fog.fill"
        }
    }
}

struct ActivitiesSection: View {
    let activities: [Activity]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Planned Activities")
                .font(.subheadline)
                .fontWeight(.medium)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(activities.prefix(4), id: \.id) { activity in
                    ActivityChip(activity: activity)
                }

                if activities.count > 4 {
                    Button("+\(activities.count - 4) more") {
                        // Show all activities
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
                }
            }
        }
    }
}

struct ActivityChip: View {
    let activity: Activity

    var body: some View {
        HStack {
            Image(systemName: activityIcon(activity.category))
                .font(.caption)
                .foregroundColor(.blue)

            Text(activity.name)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
    }

    private func activityIcon(_ category: ActivityCategory) -> String {
        switch category {
        case .dining: return "fork.knife"
        case .sightseeing: return "camera"
        case .business: return "briefcase"
        case .outdoor: return "leaf"
        case .nightlife: return "moon.stars"
        case .cultural: return "building.columns"
        case .sports: return "figure.walk"
        case .shopping: return "bag"
        }
    }
}

struct PlannedOutfitCard: View {
    let outfit: PlannedOutfit
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(outfit.timeOfDay.rawValue)
                        .font(.headline)
                        .fontWeight(.medium)

                    Text(outfit.activity.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Menu {
                    Button("Edit", action: onEdit)
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }

            // Outfit items
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(outfit.items, id: \.id) { item in
                        OutfitItemView(item: item)
                    }
                }
            }

            // Cultural considerations
            if !outfit.culturalConsiderations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cultural Notes")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)

                    ForEach(outfit.culturalConsiderations, id: \.self) { note in
                        Text("• \(note)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

struct OutfitItemView: View {
    let item: PackingItem

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: itemIcon(item.name))
                        .foregroundColor(.blue)
                )

            Text(item.name)
                .font(.caption2)
                .lineLimit(1)
        }
        .frame(width: 60)
    }

    private func itemIcon(_ name: String) -> String {
        let lowercaseName = name.lowercased()
        if lowercaseName.contains("shirt") { return "tshirt" }
        if lowercaseName.contains("pants") { return "p.circle" }
        if lowercaseName.contains("shoe") { return "shoe.2" }
        if lowercaseName.contains("jacket") { return "j.circle" }
        return "tshirt"
    }
}

struct EmptyOutfitScheduleView: View {
    let onAddOutfit: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tshirt")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            Text("No outfits planned")
                .font(.headline)
                .foregroundColor(.secondary)

            Button("Plan Outfits") {
                onAddOutfit()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct OutfitCreatorView: View {
    let trip: TravelTrip?
    let selectedDate: Date
    let onOutfitCreated: (PlannedOutfit) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTimeOfDay: TimeOfDay = .morning
    @State private var selectedActivity: Activity?
    @State private var selectedItems: [PackingItem] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Time & Activity") {
                    Picker("Time of Day", selection: $selectedTimeOfDay) {
                        ForEach(TimeOfDay.allCases, id: \.self) { time in
                            Text(time.rawValue).tag(time)
                        }
                    }

                    if let trip = trip {
                        Picker("Activity", selection: $selectedActivity) {
                            Text("Select Activity").tag(nil as Activity?)
                            ForEach(trip.destinations.flatMap(\.activities), id: \.id) { activity in
                                Text(activity.name).tag(activity as Activity?)
                            }
                        }
                    }
                }

                Section("Outfit Items") {
                    if let packingList = trip?.packingList {
                        ForEach(packingList.categories.flatMap(\.items), id: \.id) { item in
                            HStack {
                                Button(action: {
                                    toggleItem(item)
                                }) {
                                    Image(systemName: selectedItems.contains(where: { $0.id == item.id }) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedItems.contains(where: { $0.id == item.id }) ? .blue : .secondary)
                                }
                                .buttonStyle(PlainButtonStyle())

                                Text(item.name)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Create Outfit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveOutfit()
                    }
                    .disabled(selectedActivity == nil || selectedItems.isEmpty)
                }
            }
        }
    }

    private func toggleItem(_ item: PackingItem) {
        if let index = selectedItems.firstIndex(where: { $0.id == item.id }) {
            selectedItems.remove(at: index)
        } else {
            selectedItems.append(item)
        }
    }

    private func saveOutfit() {
        guard let activity = selectedActivity else { return }

        let outfit = PlannedOutfit(
            id: UUID(),
            timeOfDay: selectedTimeOfDay,
            activity: activity,
            items: selectedItems,
            alternatives: [],
            culturalConsiderations: []
        )

        onOutfitCreated(outfit)
        dismiss()
    }
}

// MARK: - Outfit Scheduler
class OutfitScheduler {
    func generateSchedule(
        for trip: TravelTrip,
        weather: [String: WeatherForecast]
    ) -> [OutfitScheduleDay] {
        var schedule: [OutfitScheduleDay] = []

        let dateRange = generateDateRange(from: trip.duration.start, to: trip.duration.end)

        for date in dateRange {
            let destination = trip.destinations.first! // Simplified
            let activities = destination.activities
            let dailyWeather = weather.values.first?.dailyForecasts.first { forecast in
                Calendar.current.isDate(forecast.date, inSameDayAs: date)
            }

            var plannedOutfits: [PlannedOutfit] = []

            // Generate outfits for different times of day based on activities
            for timeOfDay in TimeOfDay.allCases {
                if let activity = selectActivity(for: timeOfDay, activities: activities) {
                    let outfit = generateOutfit(
                        for: activity,
                        timeOfDay: timeOfDay,
                        weather: dailyWeather,
                        packingList: trip.packingList
                    )
                    if let outfit = outfit {
                        plannedOutfits.append(outfit)
                    }
                }
            }

            let scheduleDay = OutfitScheduleDay(
                id: UUID(),
                date: date,
                destination: destination,
                activities: activities,
                plannedOutfits: plannedOutfits,
                weather: dailyWeather
            )

            schedule.append(scheduleDay)
        }

        return schedule
    }

    private func generateDateRange(from start: Date, to end: Date) -> [Date] {
        var dates: [Date] = []
        var currentDate = start

        while currentDate <= end {
            dates.append(currentDate)
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? end
        }

        return dates
    }

    private func selectActivity(for timeOfDay: TimeOfDay, activities: [Activity]) -> Activity? {
        switch timeOfDay {
        case .morning:
            return activities.first { $0.category == .sightseeing || $0.category == .business }
        case .afternoon:
            return activities.first { $0.category == .outdoor || $0.category == .shopping }
        case .evening:
            return activities.first { $0.category == .dining }
        case .night:
            return activities.first { $0.category == .nightlife }
        }
    }

    private func generateOutfit(
        for activity: Activity,
        timeOfDay: TimeOfDay,
        weather: DailyForecast?,
        packingList: PackingList?
    ) -> PlannedOutfit? {
        guard let packingList = packingList else { return nil }

        let allItems = packingList.categories.flatMap(\.items)
        var outfitItems: [PackingItem] = []

        // Basic outfit selection logic
        // In a real implementation, this would be much more sophisticated
        if let topItem = allItems.first(where: { $0.name.lowercased().contains("shirt") }) {
            outfitItems.append(topItem)
        }

        if let bottomItem = allItems.first(where: { $0.name.lowercased().contains("pants") }) {
            outfitItems.append(bottomItem)
        }

        if let shoes = allItems.first(where: { $0.name.lowercased().contains("shoe") }) {
            outfitItems.append(shoes)
        }

        // Weather-appropriate additions
        if let weather = weather, weather.minTemp < 15 {
            if let jacket = allItems.first(where: { $0.name.lowercased().contains("jacket") }) {
                outfitItems.append(jacket)
            }
        }

        return PlannedOutfit(
            id: UUID(),
            timeOfDay: timeOfDay,
            activity: activity,
            items: outfitItems,
            alternatives: [],
            culturalConsiderations: []
        )
    }
}

extension DateFormatter {
    static let weekdayAndDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    static let shortWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()
}

#Preview {
    OutfitScheduleView(travelManager: TravelProManager())
}