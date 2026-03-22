import SwiftUI
import Speech
import AVFoundation

/// Tab 1: 音声入力タブ
/// マイクボタンを中央に大きく配置し、入力だけに集中できる画面
struct VoiceInputTab: View {
    @Environment(AppState.self) private var appState
    let dashboardViewModel: DashboardViewModel

    @State private var viewModel: InputViewModel?
    @State private var showTextFallback = false
    @State private var showPaywall = false

    private var hasSpeechPermission: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized &&
        AVAudioApplication.shared.recordPermission == .granted
    }

    var body: some View {
        ZStack {
            Color.themeBackground.ignoresSafeArea()

            if let vm = viewModel {
                inputContent(vm: vm)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = InputViewModel(appState: appState)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                viewModel: PaywallViewModel(
                    storeKit: StoreKitService(),
                    appState: appState
                )
            )
        }
    }

    @ViewBuilder
    private func inputContent(vm: InputViewModel) -> some View {
        VStack(spacing: 0) {
            // タイトル
            Text("予定を追加")
                .font(.title2.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Spacer()

            // 文字起こし / 解析中 / エラー / ガイドテキスト
            transcriptionArea(vm: vm)

            Spacer()

            // 確認カード or テキスト入力 or マイクボタン
            if let parsed = vm.parsedInput {
                ParseConfirmationView(
                    parsed: parsed,
                    isLoading: vm.isWritingThrough,
                    errorMessage: vm.errorMessage,
                    selectedMinutes: Binding(
                        get: { vm.selectedPreNotificationMinutesList },
                        set: { vm.selectedPreNotificationMinutesList = $0 }
                    ),
                    isPro: appState.subscriptionTier == .pro,
                    onUpgradeTapped: { showPaywall = true },
                    onConfirm: {
                        Task {
                            await vm.confirmAndSchedule()
                            if vm.confirmationMessage != nil {
                                await dashboardViewModel.loadEvents()
                            }
                        }
                    },
                    onCancel: {
                        vm.parsedInput = nil
                        vm.errorMessage = nil
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            } else if showTextFallback {
                TextInputFallbackView(viewModel: vm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            } else {
                microphoneButton(vm: vm)
                    .padding(.bottom, 48)
            }

            // テキスト入力切り替えボタン
            if vm.parsedInput == nil {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        showTextFallback.toggle()
                        vm.reset()
                    }
                } label: {
                    Text(showTextFallback ? "マイクに切り替える" : "文字で入力する")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 24)
            }
        }
        .animation(.spring(duration: 0.3), value: vm.parsedInput != nil)
        // 成功メッセージオーバーレイ（上部スライドイン）
        .overlay(alignment: .top) {
            if let msg = vm.confirmationMessage {
                confirmationOverlay(msg, vm: vm)
            }
        }
    }

    // MARK: - 文字起こしエリア

    @ViewBuilder
    private func transcriptionArea(vm: InputViewModel) -> some View {
        Group {
            if vm.isListening && vm.transcribedText.isEmpty {
                Text("聞いています…")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else if vm.isParsing {
                // NL解析中
                VStack(spacing: 8) {
                    Text(vm.transcribedText)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("考えています…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if !vm.transcribedText.isEmpty {
                Text(vm.transcribedText)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else if let error = vm.errorMessage, vm.parsedInput == nil {
                Text(error)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                VStack(spacing: 12) {
                    Text("ボタンを押しながら話してください")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("「明日の15時にカフェ」\n「30分後に薬を飲む」")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.horizontal, 32)
        .frame(minHeight: 100)
    }

    // MARK: - マイクボタン

    @ViewBuilder
    private func microphoneButton(vm: InputViewModel) -> some View {
        VStack(spacing: 20) {
            if !hasSpeechPermission {
                VStack(spacing: 16) {
                    Image(systemName: "mic.slash.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text("マイクが使えない状態です")
                        .font(.callout.weight(.semibold))
                    Text("iPhoneの「設定」アプリから、\nこのアプリのマイクをオンにしてくださいね。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("設定アプリを開く") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.large(background: .blue))
                    .padding(.horizontal, 32)
                }
            } else {
                ZStack {
                    if vm.isListening {
                        Circle()
                            .stroke(Color.red.opacity(0.3), lineWidth: 2)
                            .frame(width: 160, height: 160)
                            .scaleEffect(1.3)
                            .opacity(0)
                            .animation(
                                .easeInOut(duration: 0.9).repeatForever(autoreverses: false),
                                value: vm.isListening
                            )
                    }
                    Circle()
                        .fill(vm.isListening ? Color.red : Color.blue)
                        .frame(width: 120, height: 120)
                        .shadow(color: .blue.opacity(0.4), radius: vm.isListening ? 20 : 8)
                    Image(systemName: vm.isListening ? "waveform" : "mic.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)
                        .symbolEffect(.variableColor, isActive: vm.isListening)
                }
                .frame(width: 140, height: 140)
                .modifier(MicGestureModifier(vm: vm, mode: appState.micInputMode))

                Text(appState.micInputMode == .tapToggle
                     ? (vm.isListening ? "もう一度タップで終了" : "タップして話す")
                     : (vm.isListening ? "話し終わったら離してください" : "押しながら話す"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 成功トースト（上部スライドイン）

    private func confirmationOverlay(_ message: String, vm: InputViewModel) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
            Text(message)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.spring(duration: 0.3)) {
                    vm.confirmationMessage = nil
                }
            }
        }
    }
}
