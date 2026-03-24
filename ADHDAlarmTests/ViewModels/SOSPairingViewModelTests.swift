import XCTest
@testable import ADHDAlarm

@MainActor
final class SOSPairingViewModelTests: XCTestCase {
    
    var viewModel: SOSPairingViewModel!
    var mockSOSService: MockSOSService!
    var appState: AppState!
    var defaults: UserDefaults!
    
    override func setUp() async throws {
        // テスト用のUserDefaultsを作成してAppStateをリセット
        let domain = UUID().uuidString
        defaults = UserDefaults(suiteName: domain)
        UserDefaults.standard.removePersistentDomain(forName: domain)
        
        let oldStandard = UserDefaults.standard
        let oldSuite = UserDefaults(suiteName: Constants.appGroupID)
        
        // AppStateの内部でUserDefaults.standardやAppGroupを見に行くので、
        // 完全に隔離するのは難しいが、少なくともキーをクリアしておく
        UserDefaults.standard.removeObject(forKey: Constants.Keys.sosPairingId)
        
        appState = AppState()
        mockSOSService = MockSOSService()
        viewModel = SOSPairingViewModel(sosService: mockSOSService, appState: appState)
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockSOSService = nil
        appState = nil
        UserDefaults.standard.removeObject(forKey: Constants.Keys.sosPairingId)
    }
    
    func testInitialState() {
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertNil(viewModel.pairingCode)
    }
    
    func testStartPairingSuccess() async throws {
        // Arrange
        mockSOSService.generatedCode = "9999"
        mockSOSService.generatedPairingId = "test-pairing-id"
        // 即座にpairedが来るように設定
        mockSOSService.streamValues = ["paired"]
        
        // Act
        viewModel.startPairing()
        
        // Asynchronous tasks inside ViewModel take a moment
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        
        // Assert
        XCTAssertEqual(viewModel.state, .paired)
        XCTAssertEqual(viewModel.pairingCode, "9999")
        XCTAssertEqual(appState.sosPairingId, "test-pairing-id")
    }
    
    func testStartPairingTimeout() async throws {
        // Arrange
        mockSOSService.generatedCode = "1234"
        mockSOSService.streamValues = [] // status changes not coming
        
        // Act
        viewModel.startPairing()
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // Force timeout by manipulating timeRemaining
        viewModel.timeRemaining = 0
        
        // Wait for the next timer tick
        try await Task.sleep(nanoseconds: 1_100_000_000) // wait > 1s for timer
        
        // Assert
        if case .error(let msg) = viewModel.state {
            XCTAssertTrue(msg.contains("コードの有効期限"))
        } else {
            XCTFail("Expected timeout error, but got \(viewModel.state)")
        }
    }
    
    func testUnpair() async throws {
        // Arrange
        appState.sosPairingId = "existing-pairing-id"
        let vm = SOSPairingViewModel(sosService: mockSOSService, appState: appState) // recreating to pick up AppState changes
        XCTAssertEqual(vm.state, .paired)
        
        // Act
        vm.unpair()
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // Assert
        XCTAssertEqual(vm.state, .idle)
        XCTAssertNil(vm.pairingCode)
        XCTAssertNil(appState.sosPairingId)
        XCTAssertEqual(mockSOSService.unpairedId, "existing-pairing-id")
    }
}
