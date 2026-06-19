import Combine

@MainActor
final class PreferencesNavigationState: ObservableObject {
    @Published var selectedTab: String = "general"
}
