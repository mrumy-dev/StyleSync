import SwiftUI
import Observation

@Observable
class AppState {
    var selectedTab: Int = 0
    var isShowingAddItemSheet = false
    var isShowingFilterSheet = false
    var searchText = ""
    var selectedCategory: String?
    var selectedCollection: Collection?
    var isLoading = false
    var errorMessage: String?

    var filteredCategories: [String] = [
        "Clothing",
        "Shoes",
        "Accessories",
        "Hair",
        "Makeup",
        "Inspiration"
    ]

    func showError(_ message: String) {
        errorMessage = message
    }

    func clearError() {
        errorMessage = nil
    }

    func resetFilters() {
        searchText = ""
        selectedCategory = nil
        selectedCollection = nil
    }
}