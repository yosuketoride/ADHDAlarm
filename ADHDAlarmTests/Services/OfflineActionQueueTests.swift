import XCTest
@testable import ADHDAlarm

final class OfflineActionQueueTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        let suiteName = "OfflineActionQueueTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    func testEnqueueStatusUpdate_KeepsOnlyLatestActionForSameEventID() async {
        let service = MockFamilyService()
        let queue = OfflineActionQueue(familyService: service, defaults: makeDefaults())

        await queue.enqueueStatusUpdate(
            eventID: "event-1",
            status: "completed",
            timestamp: Date(timeIntervalSince1970: 100)
        )
        await queue.enqueueStatusUpdate(
            eventID: "event-1",
            status: "skipped",
            timestamp: Date(timeIntervalSince1970: 200)
        )

        let queued = await queue.queuedSnapshot()
        XCTAssertEqual(queued.count, 1)
        XCTAssertEqual(queued.first?.eventID, "event-1")
        XCTAssertEqual(queued.first?.status, "skipped")
        XCTAssertEqual(queued.first?.timestamp, Date(timeIntervalSince1970: 200))
    }

    func testEnqueueStatusUpdate_TrimsOldestEntriesBeyondOneHundred() async {
        let service = MockFamilyService()
        let queue = OfflineActionQueue(familyService: service, defaults: makeDefaults())

        for index in 0..<101 {
            await queue.enqueueStatusUpdate(
                eventID: "event-\(index)",
                status: "completed",
                timestamp: Date(timeIntervalSince1970: Double(index))
            )
        }

        let queued = await queue.queuedSnapshot()
        XCTAssertEqual(queued.count, 100)
        XCTAssertEqual(queued.first?.eventID, "event-1")
        XCTAssertEqual(queued.last?.eventID, "event-100")
    }

    func testFlush_SendsQueuedActionsInTimestampOrder() async {
        let service = MockFamilyService()
        service.shouldThrow = true
        let queue = OfflineActionQueue(familyService: service, defaults: makeDefaults())

        await queue.sendOrEnqueueStatusUpdate(eventID: "event-2", status: "skipped")
        await queue.enqueueStatusUpdate(
            eventID: "event-1",
            status: "completed",
            timestamp: Date(timeIntervalSince1970: 100)
        )
        await queue.enqueueStatusUpdate(
            eventID: "event-3",
            status: "completed",
            timestamp: Date(timeIntervalSince1970: 300)
        )

        service.shouldThrow = false
        await queue.flush()

        let statuses = await MainActor.run { service.updatedRemoteStatuses }
        let count = await queue.queuedCount()
        XCTAssertEqual(statuses.map(\.id), ["event-1", "event-2", "event-3"])
        XCTAssertEqual(count, 0)
    }

    func testSendOrEnqueueStatusUpdate_WhenRequestFails_StoresActionForLater() async {
        let service = MockFamilyService()
        service.shouldThrow = true
        let queue = OfflineActionQueue(familyService: service, defaults: makeDefaults())

        await queue.sendOrEnqueueStatusUpdate(eventID: "event-1", status: "completed")

        let queued = await queue.queuedSnapshot()
        XCTAssertEqual(queued.count, 1)
        XCTAssertEqual(queued.first?.eventID, "event-1")
        XCTAssertEqual(queued.first?.status, "completed")
    }
}
