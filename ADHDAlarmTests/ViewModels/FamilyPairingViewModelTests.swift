import XCTest
@testable import ADHDAlarm

@MainActor
final class FamilyPairingViewModelTests: XCTestCase {

    var viewModel: FamilyPairingViewModel!
    var mockService: MockFamilyService!

    override func setUp() async throws {
        mockService = MockFamilyService()
        viewModel = FamilyPairingViewModel(service: mockService)
    }

    override func tearDown() async throws {
        viewModel = nil
        mockService = nil
    }

    // MARK: - 初期状態

    func testInitialState() {
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(viewModel.inputCode, "")
    }

    // MARK: - 親側: コード生成

    func testGenerateCodeSuccess() async throws {
        // Arrange
        mockService.stubLinkId = "link-abc"
        mockService.stubCode = "654321"

        // Act
        viewModel.generateCode(isPremium: false)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        // Assert: waitingForFamilyに遷移しているか
        if case .waitingForFamily(let code, let linkId, _) = viewModel.state {
            XCTAssertEqual(code, "654321")
            XCTAssertEqual(linkId, "link-abc")
        } else {
            XCTFail("Expected .waitingForFamily but got \(viewModel.state)")
        }
        XCTAssertEqual(mockService.generatedCodes.count, 1)
    }

    func testGenerateCodeFailure() async throws {
        // Arrange
        mockService.shouldThrow = true

        // Act
        viewModel.generateCode(isPremium: false)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        if case .error(let msg) = viewModel.state {
            XCTAssertFalse(msg.isEmpty)
        } else {
            XCTFail("Expected .error but got \(viewModel.state)")
        }
    }

    func testGenerateCodeIgnoredIfNotIdle() async throws {
        // Arrange: idle以外の状態にしておく
        viewModel.state = .generating

        // Act
        viewModel.generateCode(isPremium: false)
        try await Task.sleep(nanoseconds: 50_000_000)

        // Assert: コードは生成されていない
        XCTAssertEqual(mockService.generatedCodes.count, 0)
    }

    // MARK: - 親側: キャンセル

    func testCancelWaitingResetsToIdle() async throws {
        // Arrange: 先にコードを生成してwaitingForFamily状態にする
        viewModel.generateCode(isPremium: false)
        try await Task.sleep(nanoseconds: 100_000_000)
        guard case .waitingForFamily = viewModel.state else {
            XCTFail("Setup failed: expected .waitingForFamily")
            return
        }

        // Act
        viewModel.cancelWaiting()

        // Assert
        XCTAssertEqual(viewModel.state, .idle)
    }

    // MARK: - 子側: コード入力してペアリング

    func testJoinWithCodeSuccess() async throws {
        // Arrange
        viewModel.inputCode = "123456"
        mockService.stubLinkId = "link-xyz"

        // Act
        viewModel.joinWithCode(isPremium: false)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        if case .linked(let linkId) = viewModel.state {
            XCTAssertEqual(linkId, "link-xyz")
        } else {
            XCTFail("Expected .linked but got \(viewModel.state)")
        }
        XCTAssertEqual(mockService.joinedCodes, ["123456"])
    }

    func testJoinWithCodeTooShortShowsError() async throws {
        // Arrange: 6桁未満
        viewModel.inputCode = "123"

        // Act
        viewModel.joinWithCode(isPremium: false)
        try await Task.sleep(nanoseconds: 50_000_000)

        // Assert
        if case .error(let msg) = viewModel.state {
            XCTAssertTrue(msg.contains("6桁"))
        } else {
            XCTFail("Expected .error but got \(viewModel.state)")
        }
        XCTAssertEqual(mockService.joinedCodes.count, 0)
    }

    func testJoinWithInvalidCodeShowsError() async throws {
        // Arrange: shouldThrow=true でjoinFamily()がFamilyError.invalidCodeを投げる
        viewModel.inputCode = "000000"
        mockService.shouldThrow = true  // MockFamilyServiceはjoinFamilyでFamilyError.invalidCodeを投げる

        // Act
        viewModel.joinWithCode(isPremium: false)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        if case .error(let msg) = viewModel.state {
            XCTAssertTrue(msg.contains("コードが正しくない") || msg.contains("有効期限"))
        } else {
            XCTFail("Expected .error but got \(viewModel.state)")
        }
    }

    // MARK: - ペアリング解除

    func testUnlinkResetsToIdle() async throws {
        // Act
        viewModel.unlink(linkId: "link-to-remove")
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(mockService.unlinkedIds, ["link-to-remove"])
    }

    // MARK: - OR セマンティクス: isPremium フラグの伝達

    func testJoinWithCodePassesPremiumTrueWhenProUser() async throws {
        // Arrange: PRO ユーザーが参加する
        viewModel.inputCode = "123456"

        // Act
        viewModel.joinWithCode(isPremium: true)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert: isPremium=true がサービスに渡っていること
        XCTAssertEqual(mockService.joinedIsPremiums, [true])
    }

    func testJoinWithCodePassesPremiumFalseWhenFreeUser() async throws {
        // Arrange: 無料ユーザーが参加する
        viewModel.inputCode = "123456"

        // Act
        viewModel.joinWithCode(isPremium: false)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert: isPremium=false がサービスに渡っていること（false で上書きするかどうかはサービス側の責務）
        XCTAssertEqual(mockService.joinedIsPremiums, [false])
    }

    func testGenerateCodePassesPremiumTrueWhenProUser() async throws {
        // Arrange: PRO ユーザーがコード発行
        // Act
        viewModel.generateCode(isPremium: true)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert: isPremium=true がサービスに渡っていること
        XCTAssertEqual(mockService.generatedIsPremiums, [true])
    }

    // MARK: - Realtimeリスナー: pairedイベントでlinkedに遷移

    func testListeningTaskTransitionsToLinkedOnPaired() async throws {
        // Arrange: statusStreamで"paired"をすぐに流す
        mockService.statusStream = AsyncStream { continuation in
            continuation.yield("paired")
            continuation.finish()
        }
        mockService.stubCode = "999888"
        mockService.stubLinkId = "link-realtime"

        // Act: generateCode()でリスナーも起動
        viewModel.generateCode(isPremium: false)
        try await Task.sleep(nanoseconds: 300_000_000) // Realtimeイベント受信まで少し待つ

        // Assert
        if case .linked(let linkId) = viewModel.state {
            XCTAssertEqual(linkId, "link-realtime")
        } else {
            XCTFail("Expected .linked but got \(viewModel.state)")
        }
    }
}
