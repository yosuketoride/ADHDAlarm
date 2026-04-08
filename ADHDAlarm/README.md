---

## 技術スタック

- **iOS 26.2+** / **Xcode 26.3** / **Swift 5.0**
- 厳格並行性: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- AlarmKit（iOS 26専用）/ EventKit / AVFoundation / Speech / StoreKit 2 / WidgetKit / SwiftUI

---

### ディレクトリ構成
```
ADHDAlarm/
├── App/            AppState, AppRouter, Constants
├── Models/         AlarmEvent, ParsedInput, SyncDiff, SubscriptionTier
├── Protocols/      4プロトコル定義
├── Services/       プロトコル実装クラス
├── ViewModels/     @Observable VM（各View対応）
├── Views/          Onboarding/ Dashboard/ Input/ Alarm/ Settings/ Paywall/ Shared/
└── Extensions/     Date+Formatting, Color+Theme
```

---