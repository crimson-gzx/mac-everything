import XCTest
@testable import MacEverything

final class SearchEngineTests: XCTestCase {
    private let entries = [
        FileEntry(path: "/Users/test/Documents/report-final.pdf", name: "report-final.pdf", isDirectory: false, modifiedAt: nil, size: 10),
        FileEntry(path: "/Users/test/Documents/report-notes.txt", name: "report-notes.txt", isDirectory: false, modifiedAt: nil, size: 10),
        FileEntry(path: "/Users/test/Documents/Reports", name: "Reports", isDirectory: true, modifiedAt: nil, size: nil),
        FileEntry(path: "/Users/test/Pictures/photo.jpg", name: "photo.jpg", isDirectory: false, modifiedAt: nil, size: 10)
    ]

    func testPrefixMatchesRankBeforePathMatches() {
        let results = SearchEngine.search("report", in: entries)
        XCTAssertEqual(results.first?.name, "Reports")
        XCTAssertTrue(results.map(\.name).contains("report-final.pdf"))
    }

    func testExtensionFilterWorks() {
        let results = SearchEngine.search("report ext:pdf", in: entries)
        XCTAssertEqual(results.map(\.name), ["report-final.pdf"])
    }

    func testTypeFilterWorks() {
        let folders = SearchEngine.search("report type:folder", in: entries)
        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(folders.first?.isDirectory, true)

        let files = SearchEngine.search("report type:file", in: entries)
        XCTAssertTrue(files.allSatisfy { !$0.isDirectory })
    }
}
