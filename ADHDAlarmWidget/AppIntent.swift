import AppIntents
import Foundation
import WidgetKit

struct CompleteAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "予定を完了にする"

    @Parameter(title: "予定ID")
    var eventID: String

    init() {}
    init(eventID: String) {
        self.eventID = eventID
    }

    func perform() async throws -> some IntentResult {
        let appGroupID = "group.com.yosuke.WasurenboAlarm"
        let fileName = "alarm_events.json"
        
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName),
              let data = try? Data(contentsOf: url) else {
            return .result()
        }
        
        guard var jsonArray = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
            return .result()
        }
        
        var found = false
        for i in 0..<jsonArray.count {
            if let idStr = jsonArray[i]["id"] as? String, idStr == eventID {
                jsonArray[i]["completionStatus"] = "completed"
                found = true
                break
            }
        }
        
        if found, let newData = try? JSONSerialization.data(withJSONObject: jsonArray, options: []) {
            try? newData.write(to: url)
            
            // XPを加算
            if let defaults = UserDefaults(suiteName: appGroupID) {
                let currentXP = defaults.integer(forKey: "owl_xp")
                let todayXP = defaults.integer(forKey: "owl_xp_today")
                if todayXP + 10 <= 50 {
                    defaults.set(currentXP + 10, forKey: "owl_xp")
                    defaults.set(todayXP + 10, forKey: "owl_xp_today")
                }
            }
        }
        
        return .result()
    }
}
