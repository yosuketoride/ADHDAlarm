import SwiftUI

/// マイクボタンに適用するジェスチャーモディファイア
/// tapToggle モード: タップで開始/終了
/// pressAndHold モード: 押している間だけ録音
struct MicGestureModifier: ViewModifier {
    let vm: InputViewModel
    let mode: MicInputMode

    func body(content: Content) -> some View {
        if mode == .tapToggle {
            content
                .onTapGesture {
                    if vm.isListening {
                        vm.stopListening()
                    } else {
                        vm.startListening()
                    }
                }
        } else {
            // レビュー指摘: DragGesture(minimumDistance: 0) は ScrollView 内でスクロールを
            // 乗っ取るアンチパターン。onLongPressGesture(minimumDuration: 0) を使うと
            // OSレベルでスクロールとのジェスチャー競合が正しく処理される。
            content
                .onLongPressGesture(minimumDuration: 0) {
                    // 長押し完了（指を離した後）: 録音停止
                    vm.stopListening()
                } onPressingChanged: { isPressing in
                    if isPressing {
                        vm.startListening()
                    } else {
                        vm.stopListening()
                    }
                }
        }
    }
}
