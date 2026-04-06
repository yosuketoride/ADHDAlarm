import XCTest
@testable import ADHDAlarm

final class ToastWindowManagerTests: XCTestCase {

    func testToastQueueState_QueuesSecondToastUntilFirstCompletes() {
        var queue = ToastQueueState()
        let first = ToastMessage(text: "ひとつめ", style: .owlTip)
        let second = ToastMessage(text: "ふたつめ", style: .error)

        let firstPresented = queue.enqueue(first, now: Date())
        let secondPresented = queue.enqueue(second, now: Date().addingTimeInterval(0.5))

        XCTAssertTrue(firstPresented)
        XCTAssertFalse(secondPresented)
        XCTAssertEqual(queue.current?.text, "ひとつめ")
        XCTAssertEqual(queue.pending.map(\.text), ["ふたつめ"])

        let next = queue.advance()
        XCTAssertEqual(next?.text, "ふたつめ")
        XCTAssertEqual(queue.current?.text, "ふたつめ")
        XCTAssertTrue(queue.pending.isEmpty)
    }

    func testToastQueueState_IgnoresDuplicateTextWithinTwoSeconds() {
        var queue = ToastQueueState()
        let now = Date()
        let first = ToastMessage(text: "同じ文言", style: .owlTip)
        let duplicate = ToastMessage(text: "同じ文言", style: .error)

        XCTAssertTrue(queue.enqueue(first, now: now))
        XCTAssertFalse(queue.enqueue(duplicate, now: now.addingTimeInterval(1.5)))
        XCTAssertNil(queue.pending.first, "2秒以内の同一文言は重複登録しないこと")
        XCTAssertEqual(queue.current?.style, .owlTip)
    }

    func testToastQueueState_AllowsDuplicateTextAfterTwoSeconds() {
        var queue = ToastQueueState()
        let now = Date()
        let first = ToastMessage(text: "同じ文言", style: .owlTip)
        let later = ToastMessage(text: "同じ文言", style: .error)

        XCTAssertTrue(queue.enqueue(first, now: now))
        XCTAssertFalse(queue.enqueue(later, now: now.addingTimeInterval(2.1)))
        XCTAssertEqual(queue.pending.map(\.style), [.error])
    }
}
