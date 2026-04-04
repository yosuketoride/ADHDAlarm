import Foundation

@MainActor
final class HandledAlarmStore {
    static let shared = HandledAlarmStore()

    private let key = Constants.Keys.handledAlarmKitIDs

    private init() {}

    func markHandled(_ alarmKitID: UUID) {
        var ids = loadIDs()
        ids.insert(alarmKitID.uuidString)
        persist(ids)
    }

    func clearHandled(_ alarmKitID: UUID) {
        var ids = loadIDs()
        ids.remove(alarmKitID.uuidString)
        persist(ids)
    }

    func isHandled(_ alarmKitID: UUID) -> Bool {
        loadIDs().contains(alarmKitID.uuidString)
    }

    private func loadIDs() -> Set<String> {
        let defaults = UserDefaults.standard
        let suiteDefaults = UserDefaults(suiteName: Constants.appGroupID)
        let local = defaults.stringArray(forKey: key) ?? []
        let shared = suiteDefaults?.stringArray(forKey: key) ?? []
        return Set(local + shared)
    }

    private func persist(_ ids: Set<String>) {
        let array = Array(ids)
        UserDefaults.standard.set(array, forKey: key)
        UserDefaults(suiteName: Constants.appGroupID)?.set(array, forKey: key)
    }
}
