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
            content
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in if !vm.isListening { vm.startListening() } }
                        .onEnded { _ in vm.stopListening() }
                )
        }
    }
}
