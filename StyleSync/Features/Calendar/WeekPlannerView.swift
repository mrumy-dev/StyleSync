import SwiftUI

struct WeekPlannerView: View {
    @ObservedObject var calendarManager: CalendarManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedWeek = Date()
    @State private var workWeekMode = true
    @State private var showingBulkActions = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Week selector and mode toggle
                weekControlsSection

                // Week overview
                weekOverviewSection

                // Daily planning
                dailyPlanningSection

                Spacer()
            }
            .padding()
            .navigationTitle("Week Planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Plan Entire Week") {
                            planEntireWeek()
                        }

                        Button("Repeat Prevention") {
                            showingBulkActions = true
                        }

                        Button("Export Schedule") {
                            exportWeekSchedule()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private var weekControlsSection: some View {
        VStack(spacing: 16) {
            // Week navigation
            HStack {
                Button(action: previousWeek) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.blue)
                }

                Spacer()

                VStack {
                    Text(weekRange)
                        .font(.headline)
                        .fontWeight(.medium)

                    Text(monthYear)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: nextWeek) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }

            // Mode toggle
            Picker("Mode", selection: $workWeekMode) {
                Text("Work Week").tag(true)
                Text("Full Week").tag(false)
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }

    private var weekOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Week Overview")
                .font(.headline)
                .fontWeight(.medium)

            WeekOverviewGrid(
                events: eventsForWeek,
                workWeekMode: workWeekMode
            )
        }
    }

    private var dailyPlanningSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Planning")
                .font(.headline)
                .fontWeight(.medium)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(weekDays, id: \.self) { day in
                        DayPlanningCard(
                            date: day,
                            events: eventsForDay(day),
                            plannedOutfits: outfitsForDay(day)
                        )
                    }
                }
            }
        }
    }

    private var weekDays: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedWeek) else {
            return []
        }

        var days: [Date] = []
        let startDay = workWeekMode ? 1 : 0 // Monday for work week, Sunday for full week
        let endDay = workWeekMode ? 5 : 7 // Friday for work week, Saturday for full week

        for i in startDay..<endDay {
            if let day = calendar.date(byAdding: .day, value: i, to: weekInterval.start) {
                days.append(day)
            }
        }

        return days
    }

    private var eventsForWeek: [CalendarEvent] {
        calendarManager.upcomingEvents.filter { event in
            calendar.isDate(event.startDate, equalTo: selectedWeek, toGranularity: .weekOfYear)
        }
    }

    private var weekRange: String {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedWeek) else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let startFormatted = formatter.string(from: weekInterval.start)
        let endFormatted = formatter.string(from: weekInterval.end.addingTimeInterval(-86400)) // Subtract a day

        return "\(startFormatted) - \(endFormatted)"
    }

    private var monthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: selectedWeek)
    }

    private func previousWeek() {
        selectedWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedWeek) ?? selectedWeek
    }

    private func nextWeek() {
        selectedWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedWeek) ?? selectedWeek
    }

    private func eventsForDay(_ date: Date) -> [CalendarEvent] {
        return eventsForWeek.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
    }

    private func outfitsForDay(_ date: Date) -> [PlannedOutfit] {
        let dayEvents = eventsForDay(date)
        return dayEvents.compactMap { calendarManager.getPlannedOutfit(for: $0.id) }
    }

    private func planEntireWeek() {
        // Implementation for planning the entire week at once
        Task {
            await bulkPlanWeek()
        }
    }

    private func bulkPlanWeek() async {
        // Generate outfits for all events in the week
        let outfitPlanner = SmartOutfitPlanner()

        for day in weekDays {
            let dayEvents = eventsForDay(day)

            for event in dayEvents {
                if calendarManager.getPlannedOutfit(for: event.id) == nil {
                    let weather = calendarManager.weatherForecasts[event.id]
                    let previousOutfits = Array(calendarManager.plannedOutfits.values)

                    let outfit = await outfitPlanner.suggestOutfit(
                        for: event,
                        weather: weather,
                        previousOutfits: previousOutfits
                    )

                    calendarManager.planOutfit(for: event, outfit: outfit)
                }
            }
        }
    }

    private func exportWeekSchedule() {
        // Implementation for exporting the week schedule
    }
}

struct WeekOverviewGrid: View {
    let events: [CalendarEvent]
    let workWeekMode: Bool

    private let weekDayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let workDayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri"]

    var body: some View {
        let labels = workWeekMode ? workDayLabels : weekDayLabels

        VStack(spacing: 8) {
            // Day labels
            HStack {
                ForEach(labels, id: \.self) { label in
                    Text(label)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Event visualization
            HStack(alignment: .top, spacing: 4) {
                ForEach(labels, id: \.self) { dayLabel in
                    let dayEvents = eventsForDayLabel(dayLabel)

                    VStack(spacing: 2) {
                        ForEach(dayEvents.prefix(4), id: \.id) { event in
                            Rectangle()
                                .fill(eventColor(event.eventType))
                                .frame(height: 6)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                        }

                        if dayEvents.count > 4 {
                            Text("+\(dayEvents.count - 4)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        // Fill empty space
                        ForEach(0..<(4 - min(dayEvents.count, 4)), id: \.self) { _ in
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 6)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func eventsForDayLabel(_ label: String) -> [CalendarEvent] {
        let dayIndex = workWeekMode ?
            workDayLabels.firstIndex(of: label) :
            weekDayLabels.firstIndex(of: label)

        guard let index = dayIndex else { return [] }

        let calendar = Calendar.current
        let today = Date()

        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start else {
            return []
        }

        let adjustedIndex = workWeekMode ? index + 1 : index // Adjust for work week starting on Monday
        guard let targetDate = calendar.date(byAdding: .day, value: adjustedIndex, to: startOfWeek) else {
            return []
        }

        return events.filter { calendar.isDate($0.startDate, inSameDayAs: targetDate) }
    }

    private func eventColor(_ type: EventType) -> Color {
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

struct DayPlanningCard: View {
    let date: Date
    let events: [CalendarEvent]
    let plannedOutfits: [PlannedOutfit]

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayLabel)
                        .font(.headline)
                        .fontWeight(.medium)

                    Text("\(events.count) events")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                planningStatusIndicator
            }

            if events.isEmpty {
                Text("No events planned")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(events) { event in
                        DayEventRow(
                            event: event,
                            hasPlannedOutfit: plannedOutfits.contains { $0.eventId == event.id }
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }

    private var planningStatusIndicator: some View {
        let plannedCount = events.filter { event in
            plannedOutfits.contains { $0.eventId == event.id }
        }.count

        let allPlanned = plannedCount == events.count && !events.isEmpty

        return HStack(spacing: 6) {
            Image(systemName: allPlanned ? "checkmark.circle.fill" : "clock.circle")
                .foregroundColor(allPlanned ? .green : .orange)

            Text(allPlanned ? "All Planned" : "\(plannedCount)/\(events.count) planned")
                .font(.caption)
                .foregroundColor(allPlanned ? .green : .orange)
        }
    }
}

struct DayEventRow: View {
    let event: CalendarEvent
    let hasPlannedOutfit: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(DateFormatter.timeOnly.string(from: event.startDate))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    eventTypeLabel
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if event.isVideoCall {
                    Image(systemName: "video")
                        .font(.caption)
                        .foregroundColor(.purple)
                }

                Image(systemName: hasPlannedOutfit ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundColor(hasPlannedOutfit ? .green : .secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var eventTypeLabel: some View {
        Text(event.eventType.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(eventTypeColor)
            .clipShape(Capsule())
    }

    private var eventTypeColor: Color {
        switch event.eventType {
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

// MARK: - Week Planning Strategies
class WeekPlanningStrategy {
    static func generateWeekPlan(events: [CalendarEvent]) -> WeekPlan {
        let groupedEvents = Dictionary(grouping: events) { event in
            Calendar.current.startOfDay(for: event.startDate)
        }

        var dailyPlans: [Date: DayPlan] = [:]

        for (date, dayEvents) in groupedEvents {
            dailyPlans[date] = generateDayPlan(for: dayEvents, date: date)
        }

        return WeekPlan(dailyPlans: dailyPlans)
    }

    private static func generateDayPlan(for events: [CalendarEvent], date: Date) -> DayPlan {
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }

        // Analyze day structure
        let hasWorkEvents = sortedEvents.contains { $0.eventType == .workMeeting || $0.eventType == .videoCall }
        let hasEveningEvents = sortedEvents.contains { event in
            Calendar.current.component(.hour, from: event.startDate) >= 18
        }
        let hasSpecialEvents = sortedEvents.contains { $0.eventType == .specialEvent || $0.eventType == .dateNight }

        // Determine outfit strategy
        let strategy: OutfitStrategy
        if hasSpecialEvents {
            strategy = .specialFocus
        } else if hasWorkEvents && hasEveningEvents {
            strategy = .dayToNight
        } else if hasWorkEvents {
            strategy = .professional
        } else {
            strategy = .casual
        }

        return DayPlan(
            date: date,
            events: sortedEvents,
            strategy: strategy,
            transitionNeeded: hasWorkEvents && hasEveningEvents
        )
    }
}

struct WeekPlan {
    let dailyPlans: [Date: DayPlan]
}

struct DayPlan {
    let date: Date
    let events: [CalendarEvent]
    let strategy: OutfitStrategy
    let transitionNeeded: Bool
}

enum OutfitStrategy {
    case professional
    case casual
    case specialFocus
    case dayToNight
}

#Preview {
    WeekPlannerView(calendarManager: CalendarManager())
}