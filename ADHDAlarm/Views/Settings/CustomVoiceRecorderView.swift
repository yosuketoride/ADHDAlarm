import SwiftUI
import AVFoundation

/// カテゴリ別 家族の生声録音管理画面（PRO機能）
///
/// お薬・お出かけ・お仕事・食事・病院・その他の6カテゴリそれぞれに
/// 個別の声を録音できる。予定タイトルのキーワードから自動でカテゴリを判定する。
struct CustomVoiceRecorderView: View {

    @State private var selectedCategory: VoiceCategory? = nil
    @State private var recordingStates: [VoiceCategory: Bool] = [:]  // カテゴリ → 録音あり？

    var body: some View {
        List {
            // 説明ヘッダー
            Section {
                VStack(spacing: 10) {
                    Image(systemName: "person.wave.2.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.pink)
                    Text("予定の種類ごとに\n大切な人の声を録音できます")
                        .font(.callout.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text("予定タイトルのキーワードから自動で判定し、\n対応する声でアラームを鳴らします。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            // カテゴリ一覧
            Section("カテゴリを選んで録音") {
                ForEach(VoiceCategory.allCases, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        HStack(spacing: 14) {
                            Text(category.emoji)
                                .font(.title2)
                                .frame(width: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.displayName)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text(category.keywords.prefix(3).joined(separator: "・"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if recordingStates[category] == true {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "mic.badge.plus")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }

            Section {
                Label("録音していないカテゴリは「その他」の録音か、自動音声（さくら）で再生されます。", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("家族の生声")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedCategory) { category in
            CategoryRecorderSheet(
                category: category,
                onSaved: { refreshRecordingStates() }
            )
        }
        .onAppear { refreshRecordingStates() }
    }

    private func refreshRecordingStates() {
        guard let soundsDir = try? FileManager.default.url(
            for: .libraryDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false
        ).appendingPathComponent("Sounds") else { return }

        for category in VoiceCategory.allCases {
            let url = soundsDir.appendingPathComponent(category.fileName)
            recordingStates[category] = FileManager.default.fileExists(atPath: url.path)
        }
    }
}

// MARK: - VoiceCategory: Identifiable（シートのitem用）

extension VoiceCategory: Identifiable {
    public var id: String { rawValue }
}

// MARK: - カテゴリ別録音シート

struct CategoryRecorderSheet: View {

    let category: VoiceCategory
    var onSaved: () -> Void

    @State private var viewModel: CategoryRecorderViewModel
    @Environment(\.dismiss) private var dismiss

    init(category: VoiceCategory, onSaved: @escaping () -> Void) {
        self.category = category
        self.onSaved = onSaved
        _viewModel = State(initialValue: CategoryRecorderViewModel(category: category))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // ヘッダー
                    VStack(spacing: 10) {
                        Text(category.emoji)
                            .font(.system(size: 56))
                        Text(category.displayName)
                            .font(.title2.weight(.bold))
                        Text("録音例:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(category.exampleScript)
                            .font(.callout)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 8)

                    // 録音ステータス
                    if viewModel.isRecording {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                                .symbolEffect(.pulse)
                            Text("録音中… \(viewModel.recordingDurationText)")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                    } else if viewModel.hasRecording {
                        Label("録音が保存されています", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.callout.weight(.semibold))
                    }

                    // 録音ボタン
                    Button {
                        viewModel.toggleRecording()
                    } label: {
                        Label(
                            viewModel.isRecording ? "録音を止める" : "録音を開始する",
                            systemImage: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill"
                        )
                    }
                    .buttonStyle(.large(
                        background: viewModel.isRecording ? .red : .pink,
                        foreground: .white
                    ))
                    .padding(.horizontal, 32)

                    // 試し聴き・削除
                    if viewModel.hasRecording {
                        HStack(spacing: 16) {
                            Button {
                                viewModel.playback()
                            } label: {
                                Label(
                                    viewModel.isPlaying ? "再生中…" : "試し聴き",
                                    systemImage: viewModel.isPlaying ? "speaker.wave.3.fill" : "play.circle.fill"
                                )
                            }
                            .buttonStyle(.large(background: .blue))

                            Button(role: .destructive) {
                                viewModel.deleteRecording()
                            } label: {
                                Label("削除", systemImage: "trash.fill")
                            }
                            .buttonStyle(.large(background: Color(.systemGray4), foreground: .red))
                        }
                        .padding(.horizontal, 32)
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle(category.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") {
                        onSaved()
                        dismiss()
                    }
                }
            }
            .alert("エラー", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

// MARK: - ViewModel（カテゴリ別）

@Observable
final class CategoryRecorderViewModel: NSObject {

    var isRecording = false
    var isPlaying = false
    var hasRecording = false
    var showError = false
    var errorMessage = ""
    var recordingDurationText = "0:00"

    private let category: VoiceCategory
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingStartTime: Date?
    private var durationTimer: Timer?

    private let tempURL: URL = {
        FileManager.default.temporaryDirectory.appendingPathComponent("category_voice_temp.caf")
    }()

    private var savedURL: URL? {
        try? FileManager.default.url(
            for: .libraryDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        .appendingPathComponent("Sounds")
        .appendingPathComponent(category.fileName)
    }

    init(category: VoiceCategory) {
        self.category = category
        super.init()
        hasRecording = savedURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self, granted else {
                    self?.triggerError("マイクの使用が許可されていません。iPhoneの「設定」からマイクをオンにしてください。")
                    return
                }
                self.beginRecording()
            }
        }
    }

    private func beginRecording() {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
            audioRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            isRecording = true
            recordingStartTime = Date()
            startDurationTimer()
        } catch {
            triggerError("録音を開始できませんでした。もう一度試してください。")
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        stopDurationTimer()
        isRecording = false

        guard let savedURL else { return }
        do {
            let dir = savedURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            if FileManager.default.fileExists(atPath: savedURL.path) {
                try FileManager.default.removeItem(at: savedURL)
            }
            try FileManager.default.copyItem(at: tempURL, to: savedURL)
            hasRecording = true
        } catch {
            triggerError("録音の保存に失敗しました。もう一度試してください。")
        }
    }

    func playback() {
        guard let savedURL, FileManager.default.fileExists(atPath: savedURL.path) else { return }
        if isPlaying {
            audioPlayer?.stop()
            isPlaying = false
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: savedURL)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true
        } catch {
            triggerError("再生できませんでした。もう一度試してください。")
        }
    }

    func deleteRecording() {
        guard let savedURL else { return }
        try? FileManager.default.removeItem(at: savedURL)
        try? FileManager.default.removeItem(at: tempURL)
        hasRecording = false
        isPlaying = false
        audioPlayer?.stop()
        audioPlayer = nil
    }

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartTime else { return }
            let elapsed = Int(Date().timeIntervalSince(start))
            self.recordingDurationText = String(format: "%d:%02d", elapsed / 60, elapsed % 60)
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
        recordingDurationText = "0:00"
    }

    private func triggerError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

extension CategoryRecorderViewModel: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag { triggerError("録音が正常に完了しませんでした。") }
    }
}

extension CategoryRecorderViewModel: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}
