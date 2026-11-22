import XCTest
@testable import SleepApneaCheck

final class HistoryRepositoryTests: XCTestCase {
    private var tempDirectory: URL!
    private var repository: HistoryRepository!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SleepApneaTests_\(UUID().uuidString)", isDirectory: true)
        repository = HistoryRepository(baseDirectoryURL: tempDirectory)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testSaveLoadAndClearRoundTrip() throws {
        let screening = ScreeningCalculator.evaluate(
            stopBangInput: StopBangInput(snoring: true, tired: true, isMale: true),
            essAnswers: [1, 1, 2, 1, 0, 1, 1, 0]
        )
        let audioSession = AudioAnalyzer.generateSimulatedSession()
        let store = HistoryStoreData(screenings: [screening], audioSessions: [audioSession])

        try repository.save(store)
        let loaded = try repository.load()

        XCTAssertEqual(loaded.screenings.count, 1)
        XCTAssertEqual(loaded.audioSessions.count, 1)
        XCTAssertEqual(loaded.screenings.first?.stopBangScore, 3)

        try repository.clearAll()
        let afterClear = try repository.load()
        XCTAssertTrue(afterClear.screenings.isEmpty)
        XCTAssertTrue(afterClear.audioSessions.isEmpty)
    }

    func testCorruptedFileThrowsLoadFailed() throws {
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("history.json")
        try Data("invalid json".utf8).write(to: fileURL)

        XCTAssertThrowsError(try repository.load()) { error in
            guard case HistoryRepositoryError.loadFailed = error else {
                XCTFail("Expected loadFailed error, got \(error)")
                return
            }
        }
    }
}
