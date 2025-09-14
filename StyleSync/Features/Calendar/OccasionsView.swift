import SwiftUI
import EventKit
import UserNotifications
import CoreLocation

@MainActor
class CalendarManager: ObservableObject {
    @Published var upcomingEvents: [CalendarEvent] = []
    @Published var plannedOutfits: [String: PlannedOutfit] = [:]
    @Published var isLoading = false
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var weatherForecasts: [String: WeatherForecast] = [:]

    private let eventStore = EKEventStore()
    private let outfitPlanner = SmartOutfitPlanner()
    private let notificationManager = OutfitNotificationManager()
    private let weatherService = CalendarWeatherService()

    init() {
        checkCalendarAuthorization()
        setupNotifications()
    }

    func requestCalendarAccess() async {
        let status = await eventStore.requestFullAccessToEvents()
        await MainActor.run {
            authorizationStatus = status
            if status == .fullAccess {
                Task {
                    await loadUpcomingEvents()
                }
            }
        }
    }

    private func checkCalendarAuthorization() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if authorizationStatus == .fullAccess {
            Task {
                await loadUpcomingEvents()
            }
        }
    }

    func loadUpcomingEvents() async {
        guard authorizationStatus == .fullAccess else { return }

        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let startDate = Date()
        let endDate = calendar.date(byAdding: .day, value: 14, to: startDate) ?? Date()

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)

        var calendarEvents: [CalendarEvent] = []

        for event in events {
            let calendarEvent = CalendarEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "Untitled Event",
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                isAllDay: event.isAllDay,
                eventType: detectEventType(from: event),
                dressCode: determineDressCode(from: event),
                importance: determineImportance(from: event),
                isVideoCall: detectVideoCall(from: event),
                attendeeCount: event.attendees?.count ?? 0,
                notes: event.notes
            )
            calendarEvents.append(calendarEvent)
        }

        upcomingEvents = calendarEvents.sorted { $0.startDate < $1.startDate }

        // Load weather for events
        await loadWeatherForEvents()

        // Generate outfit suggestions
        await generateOutfitSuggestions()

        // Schedule notifications
        await scheduleOutfitNotifications()
    }

    private func loadWeatherForEvents() async {
        for event in upcomingEvents {
            if let location = event.location, !location.isEmpty {
                do {
                    let forecast = try await weatherService.getForecast(for: location, date: event.startDate)
                    weatherForecasts[event.id] = forecast
                } catch {
                    print("Failed to load weather for \(event.title): \(error)")
                }
            }
        }
    }

    private func generateOutfitSuggestions() async {
        for event in upcomingEvents {
            if plannedOutfits[event.id] == nil {
                let outfit = await outfitPlanner.suggestOutfit(
                    for: event,
                    weather: weatherForecasts[event.id],
                    previousOutfits: Array(plannedOutfits.values)
                )
                plannedOutfits[event.id] = outfit
            }
        }
    }

    private func scheduleOutfitNotifications() async {
        await notificationManager.scheduleNotifications(for: upcomingEvents)
    }

    func planOutfit(for event: CalendarEvent, outfit: PlannedOutfit) {
        plannedOutfits[event.id] = outfit

        // Save to persistent storage
        UserDefaults.standard.set(try? JSONEncoder().encode(outfit), forKey: "outfit_\(event.id)")

        // Update notification
        Task {
            await notificationManager.updateNotification(for: event, outfit: outfit)
        }
    }

    func getPlannedOutfit(for eventId: String) -> PlannedOutfit? {
        return plannedOutfits[eventId]
    }

    // MARK: - Event Analysis
    private func detectEventType(from event: EKEvent) -> EventType {
        let title = event.title?.lowercased() ?? ""
        let location = event.location?.lowercased() ?? ""
        let notes = event.notes?.lowercased() ?? ""

        let combinedText = "\(title) \(location) \(notes)"

        // Work-related keywords
        if combinedText.contains(where: { ["meeting", "conference", "interview", "presentation", "work", "office", "client"].contains($0) }) {
            if combinedText.contains(where: { ["zoom", "teams", "video", "call", "virtual", "online"].contains($0) }) {
                return .videoCall
            }
            if combinedText.contains(where: { ["interview", "job"].contains($0) }) {
                return .jobInterview
            }
            return .workMeeting
        }

        // Social events
        if combinedText.contains(where: { ["dinner", "date", "restaurant", "romantic"].contains($0) }) {
            return .dateNight
        }

        if combinedText.contains(where: { ["wedding", "party", "celebration", "birthday"].contains($0) }) {
            return .specialEvent
        }

        if combinedText.contains(where: { ["gym", "workout", "fitness", "yoga", "run"].contains($0) }) {
            return .fitness
        }

        if combinedText.contains(where: { ["travel", "flight", "vacation", "trip"].contains($0) }) {
            return .travel
        }

        // Check time and duration for work patterns
        let hour = Calendar.current.component(.hour, from: event.startDate)
        let duration = event.endDate.timeIntervalSince(event.startDate) / 3600 // hours

        if hour >= 9 && hour <= 17 && duration <= 2 {
            return .workMeeting
        }

        return .casual
    }

    private func determineDressCode(from event: EKEvent) -> DressCode {
        let eventType = detectEventType(from: event)
        let title = event.title?.lowercased() ?? ""

        switch eventType {
        case .jobInterview:
            return .business
        case .workMeeting:
            return title.contains("formal") || title.contains("board") ? .business : .businessCasual
        case .videoCall:
            return .videocallOptimized
        case .dateNight:
            return .cocktail
        case .specialEvent:
            return title.contains("wedding") ? .formal : .cocktail
        case .fitness:
            return .activewear
        case .travel:
            return .comfortable
        case .casual:
            return .casual
        }
    }

    private func determineImportance(from event: EKEvent) -> EventImportance {
        let title = event.title?.lowercased() ?? ""
        let attendeeCount = event.attendees?.count ?? 0

        if title.contains(where: { ["interview", "presentation", "board", "ceo", "director"].contains($0) }) {
            return .critical
        }

        if attendeeCount > 10 || title.contains(where: { ["meeting", "conference", "important"].contains($0) }) {
            return .high
        }

        if title.contains(where: { ["casual", "coffee", "catch up"].contains($0) }) {
            return .low
        }

        return .medium
    }

    private func detectVideoCall(from event: EKEvent) -> Bool {
        let title = event.title?.lowercased() ?? ""
        let location = event.location?.lowercased() ?? ""
        let notes = event.notes?.lowercased() ?? ""

        let combinedText = "\(title) \(location) \(notes)"

        return combinedText.contains(where: { ["zoom", "teams", "video", "call", "virtual", "online", "meet", "webex"].contains($0) })
    }

    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            }
        }
    }
}

struct OccasionsView: View {
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var premiumManager = PremiumManager()
    @State private var selectedDate = Date()
    @State private var showingOutfitPicker = false
    @State private var selectedEvent: CalendarEvent?
    @State private var showingWeekPlanner = false

    var body: some View {
        NavigationStack {
            VStack {
                if premiumManager.hasFeatureAccess(.advancedAnalytics) {
                    if calendarManager.authorizationStatus == .fullAccess {
                        occasionsContent
                    } else {
                        calendarAccessView
                    }
                } else {
                    premiumPromptView
                }
            }
            .navigationTitle("Occasions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if calendarManager.authorizationStatus == .fullAccess {
                        Button("Week Planner") {
                            showingWeekPlanner = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingOutfitPicker) {
                if let event = selectedEvent {
                    OutfitPlanningView(
                        event: event,
                        weather: calendarManager.weatherForecasts[event.id],
                        existingOutfit: calendarManager.getPlannedOutfit(for: event.id)
                    ) { outfit in
                        calendarManager.planOutfit(for: event, outfit: outfit)
                    }
                }
            }
            .sheet(isPresented: $showingWeekPlanner) {
                WeekPlannerView(calendarManager: calendarManager)
            }
        }
    }

    private var calendarAccessView: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            VStack(spacing: 16) {
                Text("Calendar Access Required")
                    .font(.title)
                    .fontWeight(.bold)

                Text("StyleSync needs access to your calendar to plan outfits for your upcoming events")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("Grant Access") {
                Task {
                    await calendarManager.requestCalendarAccess()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var premiumPromptView: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.purple)

            VStack(spacing: 16) {
                Text("Smart Calendar Planning")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Plan outfits for your events with AI-powered suggestions based on weather, occasion, and dress codes.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                FeatureRow(icon: "calendar.circle", title: "Event Detection", description: "Automatic outfit suggestions for meetings, dates, interviews")
                FeatureRow(icon: "video.circle", title: "Video Call Optimization", description: "Outfit recommendations optimized for video calls")
                FeatureRow(icon: "bell.circle", title: "Smart Notifications", description: "Evening prep reminders and weather alerts")
                FeatureRow(icon: "arrow.triangle.2.circlepath", title: "Repeat Prevention", description: "Never wear the same outfit to similar events")
            }
            .padding(.horizontal)

            Button("Upgrade to Premium") {
                // Show paywall
            }
            .buttonStyle(PremiumButtonStyle())
        }
        .padding()
    }

    private var occasionsContent: some View {
        VStack {
            if calendarManager.isLoading {
                ProgressView("Loading your events...")
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Quick actions
                        quickActionsSection

                        // Today's events
                        todayEventsSection

                        // Upcoming events
                        upcomingEventsSection

                        // Week overview
                        weekOverviewSection
                    }
                    .padding()
                }
            }
        }
        .refreshable {
            await calendarManager.loadUpcomingEvents()
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.medium)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    QuickActionCard(
                        icon: "briefcase.fill",
                        title: "Work Week",
                        subtitle: "Plan 5 days",
                        color: .blue
                    ) {
                        showingWeekPlanner = true
                    }

                    QuickActionCard(
                        icon: "heart.fill",
                        title: "Date Night",
                        subtitle: "Tonight",
                        color: .pink
                    ) {
                        // Plan date night outfit
                    }

                    QuickActionCard(
                        icon: "video.fill",
                        title: "Video Calls",
                        subtitle: "Today",
                        color: .green
                    ) {
                        // Show video call outfits
                    }

                    QuickActionCard(
                        icon: "sparkles",
                        title: "Special Event",
                        subtitle: "This week",
                        color: .purple
                    ) {
                        // Show special events
                    }
                }
                .padding(.horizontal)
            }
            .padding(.horizontal, -16)
        }
    }

    private var todayEventsSection: some View {
        let todayEvents = calendarManager.upcomingEvents.filter { Calendar.current.isDate($0.startDate, inSameDayAs: Date()) }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today")
                    .font(.headline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(todayEvents.count) events")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if todayEvents.isEmpty {
                Text("No events today")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(todayEvents) { event in
                    EventCard(
                        event: event,
                        plannedOutfit: calendarManager.getPlannedOutfit(for: event.id),
                        weather: calendarManager.weatherForecasts[event.id]
                    ) {
                        selectedEvent = event
                        showingOutfitPicker = true
                    }
                }
            }
        }
    }

    private var upcomingEventsSection: some View {
        let upcomingEvents = calendarManager.upcomingEvents.filter { !Calendar.current.isDate($0.startDate, inSameDayAs: Date()) }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming")
                .font(.headline)
                .fontWeight(.medium)

            ForEach(upcomingEvents.prefix(5)) { event in
                EventCard(
                    event: event,
                    plannedOutfit: calendarManager.getPlannedOutfit(for: event.id),
                    weather: calendarManager.weatherForecasts[event.id]
                ) {
                    selectedEvent = event
                    showingOutfitPicker = true
                }
            }
        }
    }

    private var weekOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Week Overview")
                .font(.headline)
                .fontWeight(.medium)

            WeekOverviewGrid(events: calendarManager.upcomingEvents)
        }
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                VStack(spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100, height: 80)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EventCard: View {
    let event: CalendarEvent
    let plannedOutfit: PlannedOutfit?
    let weather: WeatherForecast?
    let onPlanOutfit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Event header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(DateFormatter.timeOnly.string(from: event.startDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let location = event.location, !location.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "location")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(location)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Spacer()

                VStack(spacing: 4) {
                    eventTypeIcon(event.eventType)
                        .font(.title2)
                        .foregroundColor(eventTypeColor(event.eventType))

                    importanceBadge(event.importance)
                }
            }

            // Weather and outfit section
            HStack {
                // Weather info
                if let weather = weather {
                    HStack(spacing: 8) {
                        Image(systemName: weatherIcon(weather.condition))
                            .foregroundColor(.blue)

                        Text("\(Int(weather.temperature))°")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if weather.precipitationChance > 30 {
                            HStack(spacing: 2) {
                                Image(systemName: "drop")
                                    .font(.caption)
                                Text("\(Int(weather.precipitationChance))%")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                }

                Spacer()

                // Outfit status
                if let outfit = plannedOutfit {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Outfit planned")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                } else {
                    Button("Plan Outfit") {
                        onPlanOutfit()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }

            // Special considerations
            if event.isVideoCall {
                HStack {
                    Image(systemName: "video")
                        .foregroundColor(.purple)
                    Text("Video call - upper body focus recommended")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    private func eventTypeIcon(_ type: EventType) -> Image {
        switch type {
        case .workMeeting: return Image(systemName: "briefcase")
        case .videoCall: return Image(systemName: "video")
        case .jobInterview: return Image(systemName: "person.badge.plus")
        case .dateNight: return Image(systemName: "heart")
        case .specialEvent: return Image(systemName: "sparkles")
        case .fitness: return Image(systemName: "figure.walk")
        case .travel: return Image(systemName: "airplane")
        case .casual: return Image(systemName: "person")
        }
    }

    private func eventTypeColor(_ type: EventType) -> Color {
        switch type {
        case .workMeeting: return .blue
        case .videoCall: return .purple
        case .jobInterview: return .green
        case .dateNight: return .pink
        case .specialEvent: return .orange
        case .fitness: return .mint
        case .travel: return .cyan
        case .casual: return .gray
        }
    }

    private func importanceBadge(_ importance: EventImportance) -> some View {
        Text(importance.rawValue.uppercased())
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(importance.color)
            .clipShape(Capsule())
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

struct WeekOverviewGrid: View {
    let events: [CalendarEvent]

    private let weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(spacing: 12) {
            // Week grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(weekDays, id: \.self) { day in
                    VStack(spacing: 8) {
                        Text(day)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        let dayEvents = eventsForDay(day)

                        VStack(spacing: 2) {
                            ForEach(dayEvents.prefix(3), id: \.id) { event in
                                Rectangle()
                                    .fill(eventTypeColor(event.eventType))
                                    .frame(height: 4)
                                    .clipShape(RoundedRectangle(cornerRadius: 2))
                            }

                            if dayEvents.count > 3 {
                                Text("+\(dayEvents.count - 3)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(height: 40)
                    }
                    .frame(height: 60)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func eventsForDay(_ dayName: String) -> [CalendarEvent] {
        let calendar = Calendar.current
        let today = Date()

        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start else {
            return []
        }

        let dayIndex = weekDays.firstIndex(of: dayName) ?? 0
        guard let targetDate = calendar.date(byAdding: .day, value: dayIndex, to: startOfWeek) else {
            return []
        }

        return events.filter { calendar.isDate($0.startDate, inSameDayAs: targetDate) }
    }

    private func eventTypeColor(_ type: EventType) -> Color {
        switch type {
        case .workMeeting: return .blue
        case .videoCall: return .purple
        case .jobInterview: return .green
        case .dateNight: return .pink
        case .specialEvent: return .orange
        case .fitness: return .mint
        case .travel: return .cyan
        case .casual: return .gray
        }
    }
}

// MARK: - Data Models
struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let isAllDay: Bool
    let eventType: EventType
    let dressCode: DressCode
    let importance: EventImportance
    let isVideoCall: Bool
    let attendeeCount: Int
    let notes: String?
}

enum EventType: String, CaseIterable {
    case workMeeting = "Work Meeting"
    case videoCall = "Video Call"
    case jobInterview = "Job Interview"
    case dateNight = "Date Night"
    case specialEvent = "Special Event"
    case fitness = "Fitness"
    case travel = "Travel"
    case casual = "Casual"
}

enum DressCode: String, CaseIterable {
    case casual = "Casual"
    case businessCasual = "Business Casual"
    case business = "Business"
    case cocktail = "Cocktail"
    case formal = "Formal"
    case activewear = "Activewear"
    case comfortable = "Comfortable"
    case videocallOptimized = "Video Call Optimized"
}

enum EventImportance: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
}

// MARK: - Supporting Services
class CalendarWeatherService {
    func getForecast(for location: String, date: Date) async throws -> WeatherForecast {
        // Simulate weather API call
        await Task.sleep(nanoseconds: 500_000_000)

        return WeatherForecast(
            condition: WeatherCondition.allCases.randomElement() ?? .sunny,
            temperature: Double.random(in: 15...25),
            precipitationChance: Int.random(in: 0...100),
            humidity: Int.random(in: 40...80),
            windSpeed: Double.random(in: 5...20)
        )
    }
}

struct WeatherForecast {
    let condition: WeatherCondition
    let temperature: Double
    let precipitationChance: Int
    let humidity: Int
    let windSpeed: Double
}

extension DateFormatter {
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    OccasionsView()
}