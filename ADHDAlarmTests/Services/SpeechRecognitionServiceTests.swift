import XCTest

final class SpeechRecognitionServiceTests: XCTestCase {

    func testSpeechRecognitionService_UsesOnDeviceRecognition() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("ADHDAlarm/Services/SpeechRecognitionService.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("request.requiresOnDeviceRecognition = true"))
        XCTAssertTrue(source.contains("request.shouldReportPartialResults = true"))
    }
}
