import SwiftUI

struct SOSPairingView: View {
    @State var viewModel: SOSPairingViewModel
    @State private var showQRSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.state == .paired {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text("LINE連携済み")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("アラーム応答がない場合、自動的にお知らせが送信されます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)

                // テスト送信ボタン（連携が正しく動いているか確認）
                Button {
                    viewModel.sendTestMessage()
                } label: {
                    switch viewModel.testSendStatus {
                    case .idle:
                        Label("テストメッセージを送る", systemImage: "paperplane")
                    case .sending:
                        Label("送信中…", systemImage: "clock")
                    case .sent:
                        Label("送信しました！LINEを確認してください", systemImage: "checkmark.circle.fill")
                    case .failed(let msg):
                        Label(msg, systemImage: "exclamationmark.triangle")
                    }
                }
                .buttonStyle(.bordered)
                .tint(viewModel.testSendStatus == .sent ? .green : viewModel.testSendStatus == .idle ? .blue : .orange)
                .disabled(viewModel.testSendStatus == .sending)

                Button(role: .destructive) {
                    viewModel.unpair()
                } label: {
                    Label("連携を解除する", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    showQRSheet = true
                    viewModel.startPairing()
                } label: {
                    HStack {
                        Image(systemName: "message.fill")
                            .font(.title2)
                        Text("お知らせを受け取る家族を登録する")
                            .font(.headline)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Text("QRコードを表示して、ご家族のスマホから連携コードを送信してもらいます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showQRSheet) {
            NavigationStack {
                VStack(spacing: 24) {
                    if viewModel.state == .generating {
                        ProgressView("連携コードを発行中...")
                    } else if viewModel.state == .waitingForFamily || viewModel.state == .paired {
                        if viewModel.state == .paired {
                            VStack(spacing: 16) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.green)
                                Text("連携が完了しました！")
                                    .font(.title2.bold())
                                Button("閉じる") {
                                    showQRSheet = false
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .transition(.scale)
                        } else {
                            Text("ご家族のスマホで以下のQRコード（公式LINE）を読み取り、以下の4桁のコードをメッセージで送信してください。")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            // 公式LINEのQRコード画像
                            Image("line_qr")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                            
                            VStack(spacing: 8) {
                                Text("連携コード")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                
                                Text(viewModel.pairingCode ?? "----")
                                    .font(.system(size: 48, weight: .black, design: .monospaced))
                                    .tracking(8)
                                    .foregroundStyle(.primary)
                            }
                            
                            Text("有効期限: \(viewModel.timeRemainingFormatted)")
                                .font(.callout.bold())
                                .foregroundStyle(viewModel.timeRemaining < 60 ? .red : .primary)
                        }
                    } else if case let .error(msg) = viewModel.state {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.orange)
                            Text(msg)
                                .multilineTextAlignment(.center)
                            Button("再発行する") {
                                viewModel.startPairing()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    }
                }
                .padding()
                .navigationTitle("LINE連携")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            viewModel.cancelPairing()
                            showQRSheet = false
                        }
                    }
                }
            }
            .interactiveDismissDisabled()
        }
    }
}
