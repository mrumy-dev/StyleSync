import SwiftData
import Foundation

@Model
class StyleItem {
    var id: UUID
    var title: String
    var category: String
    var imageData: Data?
    var tags: [String]
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var isFavorite: Bool
    var collection: Collection?

    init(title: String, category: String, imageData: Data? = nil, tags: [String] = [], notes: String = "") {
        self.id = UUID()
        self.title = title
        self.category = category
        self.imageData = imageData
        self.tags = tags
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isFavorite = false
    }
}

@Model
class Collection {
    var id: UUID
    var name: String
    var colorHex: String
    var iconName: String
    var items: [StyleItem]
    var createdAt: Date
    var updatedAt: Date

    init(name: String, colorHex: String = "#007AFF", iconName: String = "folder.fill") {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.items = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
class UserPreferences {
    var id: UUID
    var preferredCategories: [String]
    var notificationSettings: NotificationSettings
    var appearanceMode: AppearanceMode
    var hapticFeedbackEnabled: Bool
    var soundEffectsEnabled: Bool

    init() {
        self.id = UUID()
        self.preferredCategories = []
        self.notificationSettings = NotificationSettings()
        self.appearanceMode = .system
        self.hapticFeedbackEnabled = true
        self.soundEffectsEnabled = true
    }
}

@Model
class NotificationSettings {
    var remindersEnabled: Bool
    var trendsEnabled: Bool
    var collectionUpdatesEnabled: Bool

    init() {
        self.remindersEnabled = true
        self.trendsEnabled = false
        self.collectionUpdatesEnabled = true
    }
}

enum AppearanceMode: String, CaseIterable, Codable {
    case light = "light"
    case dark = "dark"
    case system = "system"

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}