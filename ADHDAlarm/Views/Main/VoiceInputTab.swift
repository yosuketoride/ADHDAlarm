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
    @State private var owlBounce = false
    @State private var isBreathing = false
    @State private var isPulsing = false

    private var hasSpeechPermission: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized &&
        AVAudioApplication.shared.recordPermission == .granted
    }

    /// 時間帯別フクロウ吹き出しメッセージ
    private var owlGreeting: (line1: String, line2: String) {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11:  return ("おはようございます！", "今日の予定を教えてね")
        case 11..<17: return ("こんにちは！", "午後も自分のペースでね")
        default:      return ("おつかれさま！", "明日の予定はあるかな？")
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 温もりのある淡いグラデーション背景
                LinearGradient(
                    colors: [
                        Color(UIColor.systemBackground),
                        Color.blue.opacity(0.04),
                        Color.orange.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if let vm = viewModel {
                    inputContent(vm: vm)
                }
            }
            .navigationTitle("予定を追加")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            if viewModel == nil {
                viewModel = InputViewModel(appState: appState)
            }
            withAnimation(.spring(duration: 0.6, bounce: 0.4).delay(0.3)) {
                owlBounce = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.5)) {
                isBreathing = true
            }
            withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false).delay(1.0)) {
                isPulsing = true
            }
            // PRO版かつ複数カレンダーがある場合は選択肢をロード
            Task { await viewModel?.loadCalendarsIfNeeded() }
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
                    selectedRecurrence: Binding(
                        get: { vm.selectedRecurrence },
                        set: { vm.selectedRecurrence = $0 }
                    ),
                    availableCalendars: vm.availableCalendars,
                    selectedCalendarID: Binding(
                        get: { vm.selectedCalendarID },
                        set: { vm.selectedCalendarID = $0 }
                    ),
                    selectedFireDate: Binding(
                        get: { vm.selectedFireDate },
                        set: { vm.selectedFireDate = $0 }
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
            } else if let error = vm.errorMessage, vm.parsedInput == nil {
                // エラー優先表示（解析失敗時に文字起こしテキストに隠れないよう条件順を入れ替え）
                VStack(spacing: 12) {
                    if !vm.transcribedText.isEmpty {
                        Text(vm.transcribedText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Text(error)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
            } else if !vm.transcribedText.isEmpty {
                Text(vm.transcribedText)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                // フクロウ + 時間帯別吹き出し（初期状態）
                VStack(spacing: 20) {
                    ZStack(alignment: .center) {
                        // フクロウ（呼吸アニメーション）
                        Image("OwlIcon")
                            .resizable().scaledToFit()
                            .frame(width: 160, height: 160)
                            .scaleEffect(owlBounce ? 1.0 : 0.7)
                            .offset(y: isBreathing ? -4 : 4)
                            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)

                        // 時間帯別吹き出し（フクロウ右上に固定オフセット）
                        VStack(alignment: .leading, spacing: 2) {
                            Text(owlGreeting.line1)
                                .font(.system(size: 13, weight: .bold))
                            Text(owlGreeting.line2)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                        .overlay(alignment: .bottomLeading) {
                            Image(systemName: "triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.background)
                                .rotationEffect(.degrees(30))
                                .offset(x: 10, y: 8)
                        }
                        .offset(x: 100, y: -70)
                        .opacity(owlBounce ? 1 : 0)
                    }
                    .frame(height: 160)

                    // 例文カード
                    VStack(spacing: 10) {
                        Text("例えば、こんな風に話しかけてね")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        ExampleCard(icon: "📅", text: "「明日の15時にカフェ」")
                        ExampleCard(icon: "💊", text: "「10分後に薬を飲む」")
                    }
                    .opacity(owlBounce ? 1 : 0)
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
                    // Pulseエフェクト（録音していない時だけ表示）
                    if !vm.isListening {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 100, height: 100)
                            .scaleEffect(isPulsing ? 1.5 : 1.0)
                            .opacity(isPulsing ? 0.0 : 1.0)
                    }

                    // 録音中の波紋アニメーション
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

// MARK: - 例文カード

private struct ExampleCard: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Text(icon)
                .font(.title3)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
