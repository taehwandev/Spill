import Foundation

/// Local UI metadata only; never part of token events or uploads.
@MainActor
struct DashboardUpdateRestoration {
    private let defaults: UserDefaults
    private let now: () -> Date
    private let requestKey = "dashboard.updateReopenAt"
    private let restoreKey = "dashboard.updateRestoreFiltersAt"
    private let filtersKey = "dashboard.localFilters"

    init(defaults: UserDefaults = SpillSettings.sharedDefaults(), now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
    }

    func prepare(isDashboardOpen: Bool) {
        defaults.removeObject(forKey: restoreKey)
        if isDashboardOpen {
            defaults.set(now().timeIntervalSince1970, forKey: requestKey)
        } else {
            defaults.removeObject(forKey: requestKey)
        }
        defaults.synchronize()
    }

    func consumeReopenRequest() -> Bool {
        let valid = consumeTimestamp(requestKey)
        if valid {
            defaults.set(now().timeIntervalSince1970, forKey: restoreKey)
            defaults.synchronize()
        }
        return valid
    }

    func save(_ filters: DashboardRestoredFilters) {
        guard let data = try? JSONEncoder().encode(filters),
              data != defaults.data(forKey: filtersKey) else { return }
        defaults.set(data, forKey: filtersKey)
        defaults.synchronize()
    }

    func consumeFilters() -> DashboardRestoredFilters? {
        guard consumeTimestamp(restoreKey), let data = defaults.data(forKey: filtersKey) else { return nil }
        return try? JSONDecoder().decode(DashboardRestoredFilters.self, from: data)
    }

    private func consumeTimestamp(_ key: String) -> Bool {
        guard let value = defaults.object(forKey: key) as? Double else { return false }
        defaults.removeObject(forKey: key)
        defaults.synchronize()
        let age = now().timeIntervalSince1970 - value
        return age >= 0 && age < 600
    }
}
