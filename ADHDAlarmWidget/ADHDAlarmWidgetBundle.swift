import WidgetKit
import SwiftUI

@main
struct ADHDAlarmWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextAlarmWidget()    // ホーム画面: 次の予定（Small / Medium）
        VisualTimerWidget()  // ロック画面 / スタンバイ: 残り時間ゲージ
    }
}
