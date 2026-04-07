import XCTest
@testable import ADHDAlarm

@MainActor
final class FamilyHomeViewModelTests: XCTestCase {
    private var defaultsSuiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaultsSuiteName = "FamilyHomeViewModelTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
    }

    override func tearDown() {
        if let defaultsSuiteName {
            UserDefaults().removePersistentDomain(forName: defaultsSuiteName)
        }
        defaults = nil
        defaultsSuiteName = nil
        super.tearDown()
    }

    func testLoadEvents_FreeTierStillLoadsSentEventsAndShowsFirstCompletionBannerOnce() async throws {
        let service = MockFamilyService()
        service.stubFamilyLinks = [try makeFamilyLinkRecord(id: "link-1", status: "paired", isPremium: false)]
        service.stubSentEvents = [try makeRemoteEventRecord(id: "event-1", status: "completed")]
        let appState = AppState()
        appState.subscriptionTier = .free

        let viewModel = FamilyHomeViewModel(service: service, defaults: defaults)
        viewModel.bindAppStateIfNeeded(appState)

        await viewModel.loadEvents(linkId: "link-1")

        XCTAssertEqual(viewModel.sentEvents.count, 1)
        XCTAssertTrue(viewModel.shouldShowFirstCompletionBanner)
        XCTAssertTrue(defaults.bool(forKey: Constants.Keys.familyFirstCompletedBannerShown))

        viewModel.dismissFirstCompletionBanner()
        XCTAssertFalse(viewModel.shouldShowFirstCompletionBanner)

        await viewModel.loadEvents(linkId: "link-1")
        XCTAssertFalse(viewModel.shouldShowFirstCompletionBanner)
    }

    func testLoadEvents_ProTierDoesNotShowFirstCompletionBanner() async throws {
        let service = MockFamilyService()
        service.stubFamilyLinks = [try makeFamilyLinkRecord(id: "link-1", status: "paired", isPremium: false)]
        service.stubSentEvents = [try makeRemoteEventRecord(id: "event-1", status: "completed")]
        let appState = AppState()
        appState.subscriptionTier = .pro

        let viewModel = FamilyHomeViewModel(service: service, defaults: defaults)
        viewModel.bindAppStateIfNeeded(appState)

        await viewModel.loadEvents(linkId: "link-1")

        XCTAssertEqual(viewModel.sentEvents.count, 1)
        XCTAssertFalse(viewModel.shouldShowFirstCompletionBanner)
        XCTAssertFalse(defaults.bool(forKey: Constants.Keys.familyFirstCompletedBannerShown))
    }

    private func makeRemoteEventRecord(id: String, status: String) throws -> RemoteEventRecord {
        let json = """
        {
          "id": "\(id)",
          "family_link_id": "link-1",
          "creator_device_id": "creator-1",
          "target_device_id": "target-1",
          "title": "おくすり",
          "fire_date": "2026-04-07T09:00:00Z",
          "pre_notification_minutes": 15,
          "voice_character": "femaleConcierge",
          "note": null,
          "status": "\(status)",
          "created_at": "2026-04-07T08:00:00Z",
          "synced_at": null
        }
        """
        return try decode(RemoteEventRecord.self, from: json)
    }

    private func makeFamilyLinkRecord(id: String, status: String, isPremium: Bool) throws -> FamilyLinkRecord {
        let json = """
        {
          "id": "\(id)",
          "parent_device_id": "parent-1",
          "child_device_id": "child-1",
          "display_name": "家族",
          "status": "\(status)",
          "expires_at": "2026-04-07T10:00:00Z",
          "created_at": "2026-04-07T08:00:00Z",
          "is_premium": \(isPremium ? "true" : "false")
        }
        """
        return try decode(FamilyLinkRecord.self, from: json)
    }

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: Data(json.utf8))
    }
}
