import Foundation
import UserNotifications
import SwiftUI

@MainActor
class OutfitNotificationManager: ObservableObject {
    @Published var notificationSettings = NotificationSettings()
    @Published var pendingNotifications: [PendingNotification] = []

    private let notificationCenter = UNUserNotificationCenter.current()

    init() {
        checkNotificationSettings()
    }

    func scheduleNotifications(for events: [CalendarEvent]) async {
        await requestNotificationPermissions()

        for event in events {
            await scheduleEventNotifications(for: event)
        }
    }

    func updateNotification(for event: CalendarEvent, outfit: PlannedOutfit) async {
        // Remove existing notifications for this event
        await removeNotifications(for: event.id)

        // Schedule updated notifications
        await scheduleEventNotifications(for: event, plannedOutfit: outfit)
    }

    private func scheduleEventNotifications(for event: CalendarEvent, plannedOutfit: PlannedOutfit? = nil) async {
        let eventDate = event.startDate
        let calendar = Calendar.current

        // Evening before notification (7 PM day before)
        if notificationSettings.eveningPrepEnabled,
           let eveningBefore = calendar.date(byAdding: .day, value: -1, to: eventDate),
           let eveningTime = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: eveningBefore),
           eveningTime > Date() {

            let content = createEveningPrepContent(for: event, plannedOutfit: plannedOutfit)
            await scheduleNotification(
                id: "\(event.id)_evening_prep",
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: eveningTime),
                    repeats: false
                )
            )
        }

        // Morning preparation notification (2 hours before event)
        if notificationSettings.morningPrepEnabled,
           let morningTime = calendar.date(byAdding: .hour, value: -2, to: eventDate),
           morningTime > Date() {

            let content = createMorningPrepContent(for: event, plannedOutfit: plannedOutfit)
            await scheduleNotification(
                id: "\(event.id)_morning_prep",
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: morningTime),
                    repeats: false
                )
            )
        }

        // Weather alert (if conditions changed significantly)
        if notificationSettings.weatherAlertsEnabled,
           let weatherTime = calendar.date(byAdding: .hour, value: -3, to: eventDate),
           weatherTime > Date() {

            await scheduleWeatherAlert(for: event, at: weatherTime)
        }

        // Last-minute reminder (30 minutes before)
        if notificationSettings.lastMinuteRemindersEnabled,
           let reminderTime = calendar.date(byAdding: .minute, value: -30, to: eventDate),
           reminderTime > Date() {

            let content = createLastMinuteReminderContent(for: event)
            await scheduleNotification(
                id: "\(event.id)_last_minute",
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime),
                    repeats: false
                )
            )
        }

        // Special event reminders
        if event.eventType == .specialEvent || event.importance == .critical {
            await scheduleSpecialEventReminders(for: event, plannedOutfit: plannedOutfit)
        }

        // Laundry day suggestions
        await scheduleLaundryReminders(for: event, plannedOutfit: plannedOutfit)
    }

    private func createEveningPrepContent(for event: CalendarEvent, plannedOutfit: PlannedOutfit?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Tomorrow's Outfit Ready! 👗"

        if let outfit = plannedOutfit {
            content.body = "Your outfit for \(event.title) is planned. Check if everything is clean and ready!"

            if !outfit.weatherConsiderations.isEmpty {
                content.body += "\n\nWeather note: \(outfit.weatherConsiderations.first!)"
            }
        } else {
            content.body = "Don't forget to plan your outfit for \(event.title) tomorrow"
        }

        content.sound = .default
        content.categoryIdentifier = "EVENING_PREP"
        content.userInfo = ["eventId": event.id, "eventTitle": event.title]

        // Add action buttons
        content.categoryIdentifier = "OUTFIT_PREP"

        return content
    }

    private func createMorningPrepContent(for event: CalendarEvent, plannedOutfit: PlannedOutfit?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()

        if let outfit = plannedOutfit {
            content.title = "Time to get ready! ⏰"
            content.body = "Your \(event.eventType.rawValue.lowercased()) starts in 2 hours. Your outfit is ready!"

            // Add specific preparation tips based on event type
            let tips = getPreparationTips(for: event)
            if !tips.isEmpty {
                content.body += "\n\nTip: \(tips.randomElement()!)"
            }
        } else {
            content.title = "⚠️ Outfit Not Planned"
            content.body = "Your \(event.eventType.rawValue.lowercased()) starts in 2 hours. Time to pick an outfit!"
        }

        content.sound = .default
        content.categoryIdentifier = "MORNING_PREP"
        content.userInfo = ["eventId": event.id, "eventTitle": event.title]

        return content
    }

    private func createLastMinuteReminderContent(for event: CalendarEvent) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Final Check! ✨"
        content.body = "30 minutes until \(event.title). Final outfit check!"

        // Add quick checklist based on event type
        let checklist = getLastMinuteChecklist(for: event)
        content.body += "\n\n\(checklist.joined(separator: " • "))"

        content.sound = .default
        content.categoryIdentifier = "FINAL_CHECK"
        content.userInfo = ["eventId": event.id]

        return content
    }

    private func scheduleWeatherAlert(for event: CalendarEvent, at alertTime: Date) async {
        // In a real implementation, this would check if weather has changed significantly
        // and only send notification if conditions are different from when outfit was planned

        let content = UNMutableNotificationContent()
        content.title = "Weather Update! 🌤️"
        content.body = "Weather has changed for \(event.title). Check if your outfit still works!"
        content.sound = .default
        content.categoryIdentifier = "WEATHER_ALERT"
        content.userInfo = ["eventId": event.id]

        await scheduleNotification(
            id: "\(event.id)_weather_alert",
            content: content,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: alertTime),
                repeats: false
            )
        )
    }

    private func scheduleSpecialEventReminders(for event: CalendarEvent, plannedOutfit: PlannedOutfit?) async {
        let calendar = Calendar.current

        // 1 week before for very special events
        if event.importance == .critical,
           let weekBefore = calendar.date(byAdding: .day, value: -7, to: event.startDate),
           weekBefore > Date() {

            let content = UNMutableNotificationContent()
            content.title = "Special Event Reminder 🎉"
            content.body = "\(event.title) is next week! Start planning your perfect outfit."
            content.sound = .default

            await scheduleNotification(
                id: "\(event.id)_week_before",
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents([.year, .month, .day, .hour], from: weekBefore),
                    repeats: false
                )
            )
        }

        // 3 days before for outfit shopping/preparation
        if event.eventType == .specialEvent || event.eventType == .dateNight,
           let threeDaysBefore = calendar.date(byAdding: .day, value: -3, to: event.startDate),
           threeDaysBefore > Date() {

            let content = UNMutableNotificationContent()
            content.title = "Outfit Preparation Time! 🛍️"
            content.body = "\(event.title) is in 3 days. Perfect time for any last-minute shopping or alterations!"
            content.sound = .default

            await scheduleNotification(
                id: "\(event.id)_three_days_prep",
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents([.year, .month, .day, .hour], from: threeDaysBefore),
                    repeats: false
                )
            )
        }
    }

    private func scheduleLaundryReminders(for event: CalendarEvent, plannedOutfit: PlannedOutfit?) async {
        guard let outfit = plannedOutfit,
              notificationSettings.laundryRemindersEnabled else { return }

        // Check if any items in the outfit might need cleaning
        let needsCleaning = outfit.items.filter { item in
            // Simple logic - in reality, this would check actual wear history
            item.timesWorn > 2 && item.lastWorn != nil &&
            Calendar.current.dateComponents([.day], from: item.lastWorn!, to: Date()).day! < 2
        }

        if !needsCleaning.isEmpty {
            let calendar = Calendar.current
            guard let laundryTime = calendar.date(byAdding: .day, value: -2, to: event.startDate),
                  laundryTime > Date() else { return }

            let content = UNMutableNotificationContent()
            content.title = "Laundry Day! 🧺"

            if needsCleaning.count == 1 {
                content.body = "Don't forget to clean your \(needsCleaning.first!.name.lowercased()) for \(event.title)"
            } else {
                content.body = "Clean \(needsCleaning.count) items for \(event.title): \(needsCleaning.prefix(2).map(\.name).joined(separator: ", "))"
            }

            content.sound = .default
            content.categoryIdentifier = "LAUNDRY_REMINDER"

            await scheduleNotification(
                id: "\(event.id)_laundry",
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents([.year, .month, .day, .hour], from: laundryTime),
                    repeats: false
                )
            )
        }
    }

    private func scheduleNotification(
        id: String,
        content: UNMutableNotificationContent,
        trigger: UNNotificationTrigger
    ) async {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            print("Scheduled notification: \(id)")
        } catch {
            print("Failed to schedule notification \(id): \(error)")
        }
    }

    private func removeNotifications(for eventId: String) async {
        let identifiers = [
            "\(eventId)_evening_prep",
            "\(eventId)_morning_prep",
            "\(eventId)_weather_alert",
            "\(eventId)_last_minute",
            "\(eventId)_week_before",
            "\(eventId)_three_days_prep",
            "\(eventId)_laundry"
        ]

        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func requestNotificationPermissions() async {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await setupNotificationCategories()
            }
        } catch {
            print("Notification permission error: \(error)")
        }
    }

    private func setupNotificationCategories() async {
        let outfitPrepActions = [
            UNNotificationAction(
                identifier: "VIEW_OUTFIT",
                title: "View Outfit",
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: "CHANGE_OUTFIT",
                title: "Change Outfit",
                options: [.foreground]
            )
        ]

        let finalCheckActions = [
            UNNotificationAction(
                identifier: "ALL_GOOD",
                title: "All Good ✓",
                options: []
            ),
            UNNotificationAction(
                identifier: "NEED_CHANGES",
                title: "Make Changes",
                options: [.foreground]
            )
        ]

        let categories = [
            UNNotificationCategory(
                identifier: "OUTFIT_PREP",
                actions: outfitPrepActions,
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: "FINAL_CHECK",
                actions: finalCheckActions,
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: "MORNING_PREP",
                actions: outfitPrepActions,
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: "EVENING_PREP",
                actions: outfitPrepActions,
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: "WEATHER_ALERT",
                actions: [
                    UNNotificationAction(
                        identifier: "CHECK_WEATHER",
                        title: "Check Weather",
                        options: [.foreground]
                    )
                ],
                intentIdentifiers: [],
                options: []
            ),
            UNNotificationCategory(
                identifier: "LAUNDRY_REMINDER",
                actions: [
                    UNNotificationAction(
                        identifier: "MARK_DONE",
                        title: "Done",
                        options: []
                    )
                ],
                intentIdentifiers: [],
                options: []
            )
        ]

        notificationCenter.setNotificationCategories(Set(categories))
    }

    private func checkNotificationSettings() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                // Update UI based on notification settings
                print("Notification authorization status: \(settings.authorizationStatus)")
            }
        }
    }

    private func getPreparationTips(for event: CalendarEvent) -> [String] {
        switch event.eventType {
        case .videoCall:
            return [
                "Test your camera angle and lighting",
                "Ensure your top looks good on camera",
                "Have a backup shirt nearby just in case"
            ]

        case .jobInterview:
            return [
                "Iron your clothes and check for any stains",
                "Polish your shoes",
                "Have a backup outfit ready",
                "Check your appearance in different lighting"
            ]

        case .dateNight:
            return [
                "Make sure everything fits comfortably",
                "Check the weather one more time",
                "Have a jacket or wrap ready just in case"
            ]

        case .specialEvent:
            return [
                "Take photos of your outfit beforehand",
                "Check dress code requirements one more time",
                "Prepare any special accessories"
            ]

        default:
            return [
                "Do a final mirror check",
                "Make sure you're comfortable",
                "Check the weather"
            ]
        }
    }

    private func getLastMinuteChecklist(for event: CalendarEvent) -> [String] {
        var checklist = ["Mirror check", "Comfort check"]

        if event.isVideoCall {
            checklist.append("Camera test")
        }

        if event.eventType == .jobInterview {
            checklist.append("Shoe polish check")
        }

        if event.eventType == .dateNight || event.eventType == .specialEvent {
            checklist.append("Accessories secure")
        }

        return checklist
    }

    // MARK: - Weekly and Monthly Planning Notifications
    func scheduleWeeklyPlanningReminder() async {
        let content = UNMutableNotificationContent()
        content.title = "Weekly Outfit Planning 📅"
        content.body = "Time to plan your outfits for the upcoming week!"
        content.sound = .default

        // Schedule for Sunday evening at 7 PM
        var components = DateComponents()
        components.weekday = 1 // Sunday
        components.hour = 19

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        await scheduleNotification(
            id: "weekly_planning_reminder",
            content: content,
            trigger: trigger
        )
    }

    func scheduleSeasonalWardrobeReminder() async {
        // Schedule reminders for season changes
        let seasonalDates = [
            (month: 3, day: 1, title: "Spring Wardrobe"),
            (month: 6, day: 1, title: "Summer Wardrobe"),
            (month: 9, day: 1, title: "Fall Wardrobe"),
            (month: 12, day: 1, title: "Winter Wardrobe")
        ]

        for (month, day, season) in seasonalDates {
            let content = UNMutableNotificationContent()
            content.title = "Seasonal Wardrobe Update 🍂"
            content.body = "Time to update your \(season.lowercased()) and plan outfits for the new season!"
            content.sound = .default

            var components = DateComponents()
            components.month = month
            components.day = day
            components.hour = 10

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            await scheduleNotification(
                id: "seasonal_\(season.lowercased())_reminder",
                content: content,
                trigger: trigger
            )
        }
    }
}

// MARK: - Settings and Models
struct NotificationSettings {
    var eveningPrepEnabled: Bool = true
    var morningPrepEnabled: Bool = true
    var weatherAlertsEnabled: Bool = true
    var lastMinuteRemindersEnabled: Bool = true
    var laundryRemindersEnabled: Bool = true
    var weeklyPlanningEnabled: Bool = true
    var seasonalRemindersEnabled: Bool = true

    var eveningPrepTime: Int = 19 // 7 PM
    var morningPrepHours: Int = 2 // 2 hours before event
    var weatherAlertHours: Int = 3 // 3 hours before event
    var lastMinuteMinutes: Int = 30 // 30 minutes before event
}

struct PendingNotification: Identifiable {
    let id: String
    let eventId: String
    let type: NotificationType
    let scheduledTime: Date
    let content: String
}

enum NotificationType: String, CaseIterable {
    case eveningPrep = "Evening Prep"
    case morningPrep = "Morning Prep"
    case weatherAlert = "Weather Alert"
    case lastMinute = "Last Minute"
    case laundry = "Laundry Reminder"
    case weeklyPlanning = "Weekly Planning"
    case seasonal = "Seasonal Update"
}

// MARK: - Notification Settings View
struct NotificationSettingsView: View {
    @StateObject private var notificationManager = OutfitNotificationManager()
    @State private var settings = NotificationSettings()

    var body: some View {
        NavigationStack {
            Form {
                Section("Outfit Preparation") {
                    Toggle("Evening Prep Reminders", isOn: $settings.eveningPrepEnabled)
                    if settings.eveningPrepEnabled {
                        HStack {
                            Text("Time")
                            Spacer()
                            Picker("Evening Prep Time", selection: $settings.eveningPrepTime) {
                                ForEach(17...21, id: \.self) { hour in
                                    Text("\(hour):00").tag(hour)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }

                    Toggle("Morning Prep Reminders", isOn: $settings.morningPrepEnabled)
                    if settings.morningPrepEnabled {
                        HStack {
                            Text("Hours Before Event")
                            Spacer()
                            Picker("Morning Prep Hours", selection: $settings.morningPrepHours) {
                                ForEach(1...4, id: \.self) { hours in
                                    Text("\(hours) hour\(hours == 1 ? "" : "s")").tag(hours)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                }

                Section("Event Alerts") {
                    Toggle("Weather Change Alerts", isOn: $settings.weatherAlertsEnabled)
                    Toggle("Last-Minute Reminders", isOn: $settings.lastMinuteRemindersEnabled)
                    Toggle("Laundry Day Suggestions", isOn: $settings.laundryRemindersEnabled)
                }

                Section("Planning Reminders") {
                    Toggle("Weekly Planning", isOn: $settings.weeklyPlanningEnabled)
                    Toggle("Seasonal Updates", isOn: $settings.seasonalRemindersEnabled)
                }

                Section("Notification Test") {
                    Button("Send Test Notification") {
                        sendTestNotification()
                    }
                }
            }
            .navigationTitle("Notification Settings")
        }
    }

    private func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "StyleSync Test 👗"
        content.body = "This is a test notification from StyleSync!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "test_notification",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Test notification error: \(error)")
            }
        }
    }
}

#Preview {
    NotificationSettingsView()
}