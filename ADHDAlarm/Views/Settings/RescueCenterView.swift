import SwiftUI
import AVFoundation
import AudioToolbox
import WidgetKit

/// レスキューセンター（お助けセンター）
///
/// よくある問題を自己解決できる FAQ カードを提供する。
/// 星1評価レビューを防ぐためのパニック防止・安心設計。
struct RescueCenterView: View {

    @State private var viewModel = RescueCenterViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ヘッダー
                VStack(spacing: 8) {
                    Image(systemName: "hands.sparkles.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.blue)
                    Text("お困りですか？一緒に解決しましょう！")
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)
                .padding(.horizontal)

                // 問題カード一覧
                rescueCard(
                    icon: "speaker.slash.fill",
                    iconColor: .orange,
                    title: "アラームが鳴らない・音が小さい",
                    description: "今すぐ音量を確認できます。"
                ) {
                    Button {
                        viewModel.testVolume()
                    } label: {
                        Label(
                            viewModel.isTesting ? "テスト中…" : "音量テストを鳴らす",
                            systemImage: viewModel.isTesting ? "speaker.wave.3.fill" : "speaker.wave.3"
                        )
                    }
                    .buttonStyle(.large(background: .orange))
                    .disabled(viewModel.isTesting)

                    // 音が小さかった場合の案内
                    if !viewModel.isTesting {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                                .padding(.top, 1)
                            Text("音が小さかったら、iPhoneの「設定」→「サウンドと触覚」→「着信音と通知音」のスライダーを上げてください。アラームはマナーモードがオンでも鳴ります。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                rescueCard(
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: .blue,
                    title: "予定を変えたのに古い時間で鳴る",
                    description: "大丈夫です！アプリがまだ変更を知らないだけです。今すぐお掃除（更新）します。"
                ) {
                    if viewModel.isSyncing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("お掃除中です…")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 60)
                    } else if viewModel.syncDone {
                        Label("お掃除が完了しました！", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.callout.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 60)
                    } else {
                        Button {
                            Task { await viewModel.forceSync() }
                        } label: {
                            Label("今すぐお掃除する", systemImage: "sparkles")
                        }
                        .buttonStyle(.large(background: .blue))
                    }
                }

                rescueCard(
                    icon: "wand.and.stars",
                    iconColor: .purple,
                    title: "カレンダーの変更を自動で反映したい",
                    description: "「ショートカット」アプリと連携すると、寝ている間に自動でお掃除してくれます。"
                ) {
                    NavigationLink {
                        AutomationGuideView()
                    } label: {
                        Label("自動化の設定ガイドを見る", systemImage: "chevron.right")
                    }
                    .buttonStyle(.large(background: .purple))
                }

                rescueCard(
                    icon: "waveform.badge.mic",
                    iconColor: .indigo,
                    title: "「Hey Siri」が喋ってくれない・文字だけ表示される",
                    description: "iPhoneの設定を変えると、Siriが声で答えてくれるようになります。"
                ) {
                    Button {
                        if let url = URL(string: "App-Prefs:SIRI") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("設定 → Siriと検索 を開く", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.large(background: .indigo))

                    Text("「Siriの反応」→「話した内容への反応」を\n「常にオン」に変更してください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                rescueCard(
                    icon: "alarm.waves.left.and.right.fill",
                    iconColor: .red,
                    title: "アラームを今すぐ全部止めたい",
                    description: "予定がキャンセルになったときなどに、全てのアラームを一時停止できます。"
                ) {
                    if viewModel.isCancellingAll {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("停止中…")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 60)
                    } else if viewModel.cancelAllDone {
                        Label("全てのアラームを停止しました", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.callout.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 60)
                    } else {
                        Button(role: .destructive) {
                            viewModel.showCancelConfirm = true
                        } label: {
                            Label("全アラームを緊急停止する", systemImage: "xmark.circle.fill")
                        }
                        .buttonStyle(.large(background: .red))
                    }
                }
                .confirmationDialog(
                    "本当に全てのアラームを停止しますか？",
                    isPresented: $viewModel.showCancelConfirm,
                    titleVisibility: .visible
                ) {
                    Button("全て停止する", role: .destructive) {
                        Task { await viewModel.cancelAllAlarms() }
                    }
                    Button("キャンセル", role: .cancel) {}
                } message: {
                    Text("停止後はアラームが鳴りません。必要な予定はもう一度追加してください。")
                }

            }
            .padding(.bottom, 32)
        }
        .navigationTitle("お助けセンター")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - カードコンポーネント

    private func rescueCard<Actions: View>(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // タイトル行
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 36)
                Text(title)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.primary)
            }

            Text(description)
                .font(.callout)
                .foregroundStyle(.secondary)

            actions()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - ViewModel

@Observable
private final class RescueCenterViewModel: NSObject {

    // 音量テスト
    var isTesting = false
    private var speechSynthesizer: AVSpeechSynthesizer?

    // 強制同期
    var isSyncing = false
    var syncDone = false

    // 全アラーム停止
    var isCancellingAll = false
    var cancelAllDone = false
    var showCancelConfirm = false

    // レビュー指摘: 完了後3秒でフラグをリセットするTaskをプロパティに保持。
    // ビュー破棄後も走り続けないよう deinit でキャンセルする。
    private var syncResetTask: Task<Void, Never>?
    private var cancelResetTask: Task<Void, Never>?

    deinit {
        syncResetTask?.cancel()
        cancelResetTask?.cancel()
    }

    // MARK: - 音量テスト

    func testVolume() {
        isTesting = true
        // ビープ先行（着信音量）
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                AudioServicesPlayAlertSound(1005)
            }
        }
        // 1秒後にTTSで音声テスト
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, options: [])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("【音量テスト】セッション確保失敗: \(error.localizedDescription)")
            }
            let synthesizer = AVSpeechSynthesizer()
            synthesizer.delegate = self
            let utterance = AVSpeechUtterance(string: "テストです！この音量でアラームが鳴ります。聞こえていますか？")
            utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
            utterance.rate = 0.48
            utterance.pitchMultiplier = 1.1
            synthesizer.speak(utterance)
            self.speechSynthesizer = synthesizer
        }
    }

    // MARK: - 強制同期

    func forceSync() async {
        isSyncing = true
        syncDone = false
        let engine = SyncEngine()
        await engine.performFullSync()
        isSyncing = false
        syncDone = true
        syncResetTask?.cancel()
        syncResetTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            syncDone = false
        }
    }

    // MARK: - 全アラーム緊急停止

    func cancelAllAlarms() async {
        isCancellingAll = true
        cancelAllDone = false

        let scheduler = AlarmKitScheduler()
        let store = AlarmEventStore.shared
        let allEvents = store.loadAll()

        // 全アラームIDを収集してキャンセル
        let allIDs: [UUID] = allEvents.flatMap { event in
            event.alarmKitIdentifiers.isEmpty
                ? [event.alarmKitIdentifier].compactMap { $0 }
                : event.alarmKitIdentifiers
        }

        if !allIDs.isEmpty {
            try? await scheduler.cancelAll(alarmKitIDs: allIDs)
        }

        // ローカルマッピングもクリア
        for event in allEvents {
            store.delete(id: event.id)
        }

        isCancellingAll = false
        cancelAllDone = true

        // WidgetKit更新
        WidgetCenter.shared.reloadAllTimelines()

        cancelResetTask?.cancel()
        cancelResetTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            cancelAllDone = false
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension RescueCenterViewModel: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        speechSynthesizer = nil
        isTesting = false
    }
}

