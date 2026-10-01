import XCTest
@testable import ReadingDomain

final class ProgressTests: XCTestCase {
    func testValidPageKnownAndUnknownTotal() throws {
        let known = try ReadingProgress.pages(current: 187, total: 450)
        XCTAssertEqual(known.currentPage, 187); XCTAssertEqual(known.totalPages, 450)
        XCTAssertNil(known.percentage)
        let unknown = try ReadingProgress.pages(current: 187)
        XCTAssertNil(unknown.totalPages)
        XCTAssertThrowsError(try ReadingProgress.pages(current: 451, total: 450))
        XCTAssertThrowsError(try ReadingProgress.pages(current: -1))
        XCTAssertThrowsError(try ReadingProgress.pages(total: 0))
    }
    func testPercentageBoundariesAndUnknown() throws {
        for value in [0.0,42.0,46.5,100.0] {
            let progress = try ReadingProgress.percentage(value)
            XCTAssertEqual(progress.percentage, value)
            XCTAssertNil(progress.currentPage); XCTAssertNil(progress.totalPages)
        }
        XCTAssertNil(try ReadingProgress.percentage().percentage)
        for value in [-1.0,100.1,Double.infinity,Double.nan] {
            XCTAssertThrowsError(try ReadingProgress.percentage(value))
        }
    }
    func testApparentEndOnlyHintsAtConfirmation() throws {
        for progress in [try ReadingProgress.pages(current: 450,total: 450), try .percentage(100)] {
            var reading = ReadingInstance(bookID: UUID(), progress: progress)
            XCTAssertTrue(progress.suggestsFinishConfirmation)
            XCTAssertEqual(reading.status, .currentlyReading)
            XCTAssertThrowsError(try ReadingRules.finish(&reading, confirmed: false, date: nil, expectedRevision: 0))
            _ = try ReadingRules.finish(&reading, confirmed: true, date: nil, expectedRevision: 0)
            XCTAssertEqual(reading.status, .read)
        }
    }
    func testRecorded100PercentageDoesNotFinish() throws {
        var reading = ReadingInstance(bookID: UUID(), progress: try .percentage(42))
        _ = try ProgressRules.record(&reading, value: .percentage(100), expectedRevision: 0)
        XCTAssertEqual(reading.status, .currentlyReading)
        XCTAssertTrue(reading.progress.suggestsFinishConfirmation)
    }
    func testManualFinishWithNoValueInEitherMode() throws {
        for progress in [try ReadingProgress.pages(), try .percentage()] {
            var reading = ReadingInstance(bookID: UUID(), progress: progress)
            _ = try ReadingRules.finish(&reading, confirmed: true, date: nil, expectedRevision: 0)
            XCTAssertEqual(reading.status, .read)
        }
    }
    func testPercentageCannotFabricatePagesOrPagesRead() throws {
        var reading = ReadingInstance(bookID: UUID(), progress: try .percentage(0))
        _ = try ProgressRules.record(&reading, value: .percentage(65), expectedRevision: 0)
        XCTAssertNil(reading.progress.currentPage); XCTAssertNil(reading.progress.totalPages)
        XCTAssertNil(reading.progressObservations.last?.genuinePageDelta)
        XCTAssertNil(ProgressRules.pagesReadFromObservations(reading))
    }
    func testOnlyGenuinePageObservationsContributeToPages() throws {
        var reading = ReadingInstance(bookID: UUID(), progress: try .pages(current: 10,total: 450))
        _ = try ProgressRules.record(&reading, value: .pages(current: 20,total: 450), expectedRevision: 0)
        XCTAssertEqual(ProgressRules.pagesReadFromObservations(reading),10)
        XCTAssertNil(reading.progress.percentage)
    }
    func testDNFRetainsEachGenuineUnitAndResume() throws {
        for progress in [try ReadingProgress.pages(current: 183), try .percentage(46)] {
            var reading = ReadingInstance(bookID: UUID(), progress: progress)
            try ReadingRules.markDNF(&reading)
            XCTAssertEqual(reading.progress,progress)
            XCTAssertNil(ProgressRules.pagesReadFromObservations(reading))
            try ReadingRules.resume(&reading)
            XCTAssertEqual(reading.progress,progress)
        }
    }
    func testPercentageConflictRetainsObservationWithoutMaximumOrTimeWinner() throws {
        var reading = ReadingInstance(bookID: UUID(), progress: try .percentage(20))
        _ = try ProgressRules.record(&reading, value: .percentage(40), expectedRevision: 0)
        let id = UUID()
        let result = try ProgressRules.record(&reading, value: .percentage(80), expectedRevision: 0,
            observationID: id, recordedAt: Date(timeIntervalSinceNow: 3600))
        guard case .requiresReview(let observation) = result else { return XCTFail("Conflict must be reviewed") }
        XCTAssertEqual(observation.value.percentage,80)
        XCTAssertEqual(reading.progress.percentage,40)
        XCTAssertEqual(reading.progressObservations.count,2)
        _ = try ProgressRules.record(&reading, value: .percentage(80), expectedRevision: 0,
            observationID: id, recordedAt: Date())
        XCTAssertEqual(reading.progressObservations.count,2)
    }
    func testFormatAndModeAreIndependent() throws {
        for format in JournalFormat.allCases {
            for progress in [try ReadingProgress.pages(current: 10), try .percentage(42)] {
                var reading = ReadingInstance(bookID: UUID(), progress: progress)
                try ReadingRules.setJournalFormat(format, origin: .user, reading: &reading)
                XCTAssertEqual(reading.progress,progress)
                let mode: ProgressMode = progress.mode == .page ? .percentage : .page
                try ProgressRules.selectMode(mode, reading: &reading, expectedRevision: 0)
                XCTAssertEqual(reading.journalFormat,format)
            }
        }
    }
    func testModeSwitchNeverConvertsHistory() throws {
        var reading = ReadingInstance(bookID: UUID(), progress: try .pages(current: 10,total: 450))
        _ = try ProgressRules.record(&reading, value: .pages(current: 20,total: 450), expectedRevision: 0)
        let original = reading.progressObservations
        try ProgressRules.selectMode(.percentage, reading: &reading, expectedRevision: 1)
        XCTAssertEqual(reading.progressObservations,original)
        XCTAssertNil(reading.progress.percentage)
        XCTAssertNil(reading.progress.currentPage)
        _ = try ProgressRules.record(&reading, value: .percentage(65), expectedRevision: 2)
        XCTAssertEqual(reading.progressObservations.first?.value.mode,.page)
        XCTAssertEqual(reading.progressObservations.last?.value.mode,.percentage)
        XCTAssertEqual(ProgressRules.pagesReadFromObservations(reading),10)
        try ProgressRules.selectMode(.page, reading: &reading, expectedRevision: 3)
        XCTAssertNil(reading.progress.currentPage)
        XCTAssertEqual(reading.progressObservations.count,2)
    }
    func testDecodedMixedOrInvalidProgressIsRejected() throws {
        for text in [
            #"{"mode":"percentage","currentPage":292,"totalPages":450,"percentage":65}"#,
            #"{"mode":"page","currentPage":187,"percentage":42}"#,
            #"{"mode":"percentage","percentage":101}"#,
            #"{"mode":"page","currentPage":451,"totalPages":450}"#
        ] {
            XCTAssertThrowsError(try JSONDecoder().decode(ReadingProgress.self,from: Data(text.utf8)))
        }
        let original = try ReadingProgress.percentage(42)
        XCTAssertEqual(try JSONDecoder().decode(ReadingProgress.self, from: JSONEncoder().encode(original)), original)
    }
}
