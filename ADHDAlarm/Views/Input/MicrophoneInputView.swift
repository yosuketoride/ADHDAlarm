import SwiftUI
import Speech
import AVFoundation

/// 音声入力のメイン画面
/// マイクボタンを押している間だけ録音し、離したら自動でNL解析する
struct MicrophoneInputView: View {
    @State var viewModel: InputViewModel
    var onSaved: (() -> Void)? = nil
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var permissionsService = PermissionsService()
    @State private var showManualInput = false
    @State private var showPaywall = false
    @State private var owlBounce = false
    @State private var permissionRefreshID = 0

    /// XP × 感情に応じたふくろうアセット名を返す
    private func owlImageName(appState: AppState, emotion: String) -> String {
        let stage: Int
        switch appState.owlXP {
        case 0..<100:    stage = 0
        case 100..<500:  stage = 1
        case 500..<1000: stage = 2
        default:         stage = 3
        }
        let name = "owl_stage\(stage)_\(emotion)"
        if UIImage(named: name) != nil { return name }
        let normal = "owl_stage\(stage)_normal"
        if UIImage(named: normal) != nil { return normal }
        return "OwlIcon"
    }

    /// マイク・音声認識の権限が揃っているか
    private var hasSpeechPermission: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized &&
        AVAudioApplication.shared.recordPermission == .granted
    }

    private var canRequestPermissionsInApp: Bool {
        SFSpeechRecognizer.authorizationStatus() == .notDetermined ||
        AVAudioApplication.shared.recordPermission == .undetermined
    }

    /// 初期状態（何も起きていない）かどうか
    private var isIdle: Bool {
        !viewModel.isListening &&
        !viewModel.isParsing &&
        viewModel.transcribedText.isEmpty &&
        viewModel.errorMessage == nil &&
        viewModel.parsedInput == nil
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if isIdle {
                // ── 初期状態: フクロウが主役のフルデザイン ──
                idleView
            } else {
                // ── アクティブ状態: 録音中・解析中・結果表示 ──
                activeView
            }

            // 成功メッセージのオーバーレイ（上部スライドイン）
            if let msg = viewModel.confirmationMessage {
                VStack {
                    confirmationOverlay(msg)
                    Spacer()
                }
            }
        }
        .animation(.spring(duration: 0.3), value: isIdle)
        .animation(.spring(duration: 0.3), value: viewModel.parsedInput != nil)
        .animation(.spring(duration: 0.3), value: viewModel.confirmationMessage)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showManualInput, onDismiss: {
            if viewModel.confirmationMessage != nil {
                onSaved?()
                dismiss()
            }
        }) {
            NavigationStack {
                PersonManualInputView(viewModel: viewModel, onSaved: onSaved)
                    .navigationTitle("予定を追加")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("閉じる") { showManualInput = false }
                        }
                    }
            }
            .presentationDetents([.large])
        }
        .onChange(of: viewModel.confirmationMessage) { _, newValue in
            guard newValue != nil else { return }
            guard !showManualInput else { return }
            onSaved?()
            dismiss()
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.4).delay(0.3)) {
                owlBounce = true
            }
        }
        .onDisappear {
            // シートが閉じられる時（アラーム割り込み含む）に必ず録音を停止する。
            // これがないとAVAudioEngine(.record)が動いたままになり、
            // RingingViewの音声再生(.playback)と競合してアラームが無音になる。
            viewModel.stopListening()
        }
    }

    // MARK: - 初期状態デザイン（フクロウ主役）

    private var idleView: some View {
        VStack(spacing: 0) {
            Spacer()

            // フクロウ + 吹き出しエリア
            VStack(spacing: 16) {
                ZStack(alignment: .center) {
                    // フクロウ本体（入力待機中 = normal）
                    Image(owlImageName(appState: appState, emotion: "normal"))
                        .resizable().scaledToFit()
                        .frame(width: 150, height: 150)
                        .scaleEffect(owlBounce ? 1.0 : 0.7)
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)

                    // 吹き出し（右上に固定オフセット）
                    VStack(alignment: .leading, spacing: 2) {
                        Text("なんでも")
                        Text("話しかけてね！")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
                    .overlay(alignment: .bottomLeading) {
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.blue)
                            .rotationEffect(.degrees(30))
                            .offset(x: 10, y: 8)
                    }
                    .offset(x: 90, y: -60)
                    .opacity(owlBounce ? 1 : 0)
                }
                // 吹き出しが上方向に60pt超える分をフレーム高に含める
                // （シート半開き時に吹き出しが切れないよう layout space を確保）
                .frame(height: 220)

                // ガイドテキスト
                VStack(spacing: 8) {
                    Text("ボタンを押して話しかけてね")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("「明日の15時にカフェ」\n「10分後に薬を飲む」")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .opacity(owlBounce ? 1 : 0)
            }
            .padding(.horizontal, 32)

            Spacer()

            // マイクボタン
            microphoneButton
                .padding(.bottom, 56)

            // テキスト入力切り替え
            Button {
                showManualInput = true
            } label: {
                Text("文字で入力する")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - アクティブ状態デザイン

    private var activeView: some View {
        VStack(spacing: 0) {
            Spacer()

            transcriptionArea

            Spacer()

            // P-1-7: 重複検知ワーニング（ParseConfirmationViewの前に表示）
            if let warning = viewModel.duplicateWarning {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🦉 もしかして、もう登録されているかも？")
                            .font(.callout.weight(.bold))
                            .foregroundStyle(.primary)
                        Text("「\(warning.existingTitle)」（\(warning.existingDate.japaneseTimeString)）が見つかりました。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yellow.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    HStack(spacing: 12) {
                        Button("追加しない（安心した！）") {
                            withAnimation { viewModel.reset() }
                        }
                        .buttonStyle(.large(background: .secondary))

                        Button("別の予定として追加") {
                            viewModel.dismissDuplicateWarning()
                        }
                        .buttonStyle(.large(background: Color.owlAmber, foreground: .black))
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            } else if let parsed = viewModel.parsedInput {
                ParseConfirmationView(
                    parsed: parsed,
                    isLoading: viewModel.isWritingThrough,
                    errorMessage: viewModel.errorMessage,
                    selectedMinutes: Binding(
                        get: { viewModel.selectedPreNotificationMinutesList },
                        set: { viewModel.selectedPreNotificationMinutesList = $0 }
                    ),
                    selectedRecurrence: Binding(
                        get: { viewModel.selectedRecurrence },
                        set: { viewModel.selectedRecurrence = $0 }
                    ),
                    availableCalendars: viewModel.availableCalendars,
                    selectedCalendarID: Binding(
                        get: { viewModel.selectedCalendarID },
                        set: { viewModel.selectedCalendarID = $0 }
                    ),
                    selectedFireDate: Binding(
                        get: { viewModel.selectedFireDate },
                        set: { viewModel.selectedFireDate = $0 }
                    ),
                    isPro: appState.subscriptionTier == .pro,
                    onUpgradeTapped: {
                        showPaywall = true
                    },
                    onConfirm: {
                        Task { await viewModel.confirmAndSchedule() }
                    },
                    onCancel: {
                        viewModel.parsedInput = nil
                        viewModel.errorMessage = nil
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            } else {
                microphoneButton
                    .padding(.bottom, 56)
            }

            if viewModel.parsedInput == nil {
                Button {
                    showManualInput = true
                } label: {
                    Text("文字で入力する")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - 文字起こしエリア

    private var transcriptionArea: some View {
        Group {
            if viewModel.isListening && viewModel.transcribedText.isEmpty {
                Text("聞いています…")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else if viewModel.isParsing {
                VStack(spacing: 8) {
                    Text(viewModel.transcribedText)
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
            } else if !viewModel.transcribedText.isEmpty {
                Text(viewModel.transcribedText)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    // エラー時 = worried
                    Image(owlImageName(appState: appState, emotion: "worried"))
                        .resizable().scaledToFit().frame(width: 72, height: 72)
                    Text(error)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
        .frame(minHeight: 100)
    }

    // MARK: - マイクボタン

    private var microphoneButton: some View {
        VStack(spacing: 20) {
            if !hasSpeechPermission {
                VStack(spacing: 16) {
                    Image(systemName: "mic.slash.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text("マイクが使えない状態です")
                        .font(.callout.weight(.semibold))
                    Text(permissionDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(permissionButtonTitle) {
                        Task {
                            if canRequestPermissionsInApp {
                                await permissionsService.requestSpeech()
                                await permissionsService.requestMicrophone()
                                permissionRefreshID += 1
                            } else if let url = URL(string: UIApplication.openSettingsURLString) {
                                await UIApplication.shared.open(url)
                            }
                        }
                    }
                    .buttonStyle(.large(background: .blue))
                    .padding(.horizontal, 32)
                }
            } else {
                ZStack {
                    if viewModel.isListening {
                        Circle()
                            .stroke(Color.red.opacity(0.3), lineWidth: 2)
                            .frame(width: 160, height: 160)
                            .scaleEffect(1.3)
                            .opacity(0)
                            .animation(
                                .easeInOut(duration: 0.9).repeatForever(autoreverses: false),
                                value: viewModel.isListening
                            )
                    }
                    Circle()
                        .fill(viewModel.isListening ? Color.red : Color.blue)
                        .frame(width: 120, height: 120)
                        .shadow(color: .blue.opacity(0.4), radius: viewModel.isListening ? 20 : 8)
                    Image(systemName: viewModel.isListening ? "waveform" : "mic.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)
                        .symbolEffect(.variableColor, isActive: viewModel.isListening)
                }
                .frame(width: 140, height: 140)
                .modifier(MicGestureModifier(vm: viewModel, mode: appState.micInputMode))

                Text(appState.micInputMode == .tapToggle
                     ? (viewModel.isListening ? "もう一度タップで終了" : "タップして話す")
                     : (viewModel.isListening ? "話し終わったら離してください" : "押しながら話す"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 完了オーバーレイ

    private func confirmationOverlay(_ message: String) -> some View {
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
        .task {
            // レビュー指摘: DispatchQueue.main.asyncAfter はキャンセルできないため
            // ビュー破棄後もクロージャが実行される恐れがある。Task はビュー破棄時に自動キャンセルされる。
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.3)) {
                viewModel.confirmationMessage = nil
                }
            }
        }
    private var permissionDescription: String {
        if canRequestPermissionsInApp {
            return "最初の1回だけ、音声認識とマイクの許可が必要です。\n下のボタンから、このまま許可できます。"
        }
        return "iPhoneの「設定」アプリから、\nこのアプリのマイクと音声認識をオンにしてくださいね。"
    }

    private var permissionButtonTitle: String {
        canRequestPermissionsInApp ? "続ける" : "設定アプリを開く"
    }
}
