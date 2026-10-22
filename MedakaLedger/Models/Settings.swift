import Foundation
import Observation

// 設定値（ARCHITECTURE.md 3.3）。UserDefaultsに保存する。Proの状態はここに入れない。

@MainActor
@Observable
final class AppSettings {
    enum Key {
        static let degreeDaysToHatch = "degreeDaysToHatch"
        static let defaultWaterTempC = "defaultWaterTempC"
        static let waterChangeWarningDays = "waterChangeWarningDays"
        static let winterWaterChangeWarningDays = "winterWaterChangeWarningDays"
        static let breedingSeasonMonths = "breedingSeasonMonths"
        static let listingTemplate = "listingTemplate"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let lastBackupAt = "lastBackupAt"
    }

    static let defaultBreedingSeasonMonths = [4, 5, 6, 7, 8, 9]

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.degreeDaysToHatch: 250.0,
            Key.defaultWaterTempC: 25.0,
            Key.waterChangeWarningDays: 14,
            Key.winterWaterChangeWarningDays: 45,
            Key.breedingSeasonMonths: Self.defaultBreedingSeasonMonths,
            Key.listingTemplate: "",
            Key.hasCompletedOnboarding: false,
        ])
    }

    var degreeDaysToHatch: Double {
        get { access(keyPath: \.degreeDaysToHatch); return defaults.double(forKey: Key.degreeDaysToHatch) }
        set { withMutation(keyPath: \.degreeDaysToHatch) { defaults.set(newValue, forKey: Key.degreeDaysToHatch) } }
    }

    var defaultWaterTempC: Double {
        get { access(keyPath: \.defaultWaterTempC); return defaults.double(forKey: Key.defaultWaterTempC) }
        set { withMutation(keyPath: \.defaultWaterTempC) { defaults.set(newValue, forKey: Key.defaultWaterTempC) } }
    }

    var waterChangeWarningDays: Int {
        get { access(keyPath: \.waterChangeWarningDays); return defaults.integer(forKey: Key.waterChangeWarningDays) }
        set { withMutation(keyPath: \.waterChangeWarningDays) { defaults.set(newValue, forKey: Key.waterChangeWarningDays) } }
    }

    var winterWaterChangeWarningDays: Int {
        get { access(keyPath: \.winterWaterChangeWarningDays); return defaults.integer(forKey: Key.winterWaterChangeWarningDays) }
        set { withMutation(keyPath: \.winterWaterChangeWarningDays) { defaults.set(newValue, forKey: Key.winterWaterChangeWarningDays) } }
    }

    var breedingSeasonMonths: [Int] {
        get {
            access(keyPath: \.breedingSeasonMonths)
            return defaults.array(forKey: Key.breedingSeasonMonths) as? [Int] ?? Self.defaultBreedingSeasonMonths
        }
        set { withMutation(keyPath: \.breedingSeasonMonths) { defaults.set(newValue, forKey: Key.breedingSeasonMonths) } }
    }

    var listingTemplate: String {
        get { access(keyPath: \.listingTemplate); return defaults.string(forKey: Key.listingTemplate) ?? "" }
        set { withMutation(keyPath: \.listingTemplate) { defaults.set(newValue, forKey: Key.listingTemplate) } }
    }

    var hasCompletedOnboarding: Bool {
        get { access(keyPath: \.hasCompletedOnboarding); return defaults.bool(forKey: Key.hasCompletedOnboarding) }
        set { withMutation(keyPath: \.hasCompletedOnboarding) { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) } }
    }

    var lastBackupAt: Date? {
        get { access(keyPath: \.lastBackupAt); return defaults.object(forKey: Key.lastBackupAt) as? Date }
        set { withMutation(keyPath: \.lastBackupAt) { defaults.set(newValue, forKey: Key.lastBackupAt) } }
    }

    func isBreedingSeason(on date: Date = .now, calendar: Calendar = .current) -> Bool {
        Season.isBreedingSeason(on: date, months: breedingSeasonMonths, calendar: calendar)
    }
}
