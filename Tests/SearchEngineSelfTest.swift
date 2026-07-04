import Foundation

@main
struct SearchEngineSelfTest {
    static func main() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let oldDate = calendar.date(byAdding: .day, value: -20, to: today)!

        let entries = [
            FileEntry(path: "/Users/test/Documents/report-final.pdf", name: "report-final.pdf", isDirectory: false, modifiedAt: today, size: 12 * 1_024 * 1_024),
            FileEntry(path: "/Users/test/Documents/report-notes.txt", name: "report-notes.txt", isDirectory: false, modifiedAt: oldDate, size: 2 * 1_024),
            FileEntry(path: "/Users/test/Documents/report-temp.pdf", name: "report-temp.pdf", isDirectory: false, modifiedAt: today, size: 500 * 1_024),
            FileEntry(path: "/Users/test/Documents/Reports", name: "Reports", isDirectory: true, modifiedAt: today, size: nil),
            FileEntry(path: "/Users/test/Pictures/photo.jpg", name: "photo.jpg", isDirectory: false, modifiedAt: oldDate, size: 10)
        ]

        let ranked = SearchEngine.search("report", in: entries)
        precondition(ranked.first?.name == "Reports", "Prefix ranking failed")
        precondition(ranked.map(\.name).contains("report-final.pdf"), "Expected PDF result")

        let pdfs = SearchEngine.search("report ext:pdf", in: entries)
        precondition(pdfs.map(\.name).contains("report-final.pdf"), "Extension filter failed")
        precondition(!pdfs.map(\.name).contains("report-notes.txt"), "Extension filter allowed txt")

        let wildcard = SearchEngine.search("*.pdf", in: entries)
        precondition(wildcard.map(\.name).contains("report-final.pdf"), "Wildcard PDF failed")
        precondition(!wildcard.map(\.name).contains("photo.jpg"), "Wildcard included jpg")

        let excluded = SearchEngine.search("report !temp", in: entries)
        precondition(!excluded.map(\.name).contains("report-temp.pdf"), "Exclusion failed")

        let nameScoped = SearchEngine.search("name:photo", in: entries)
        precondition(nameScoped.map(\.name) == ["photo.jpg"], "name: filter failed")

        let pathScoped = SearchEngine.search("path:pictures", in: entries)
        precondition(pathScoped.map(\.name) == ["photo.jpg"], "path: filter failed")

        let large = SearchEngine.search("report size:>10mb", in: entries)
        precondition(large.map(\.name) == ["report-final.pdf"], "size filter failed")

        let todays = SearchEngine.search("report date:today", in: entries)
        precondition(todays.map(\.name).contains("report-final.pdf"), "date filter missed today file")
        precondition(!todays.map(\.name).contains("report-notes.txt"), "date filter included old file")

        let folders = SearchEngine.search("report type:folder", in: entries)
        precondition(folders.count == 1 && folders.first?.isDirectory == true, "Folder filter failed")

        let files = SearchEngine.search("report type:file", in: entries)
        precondition(files.allSatisfy { !$0.isDirectory }, "File filter failed")

        let sizeSorted = SearchEngine.search("report type:file", in: entries, sort: .sizeLargest)
        precondition(sizeSorted.first?.name == "report-final.pdf", "Size sorting failed")

        print("SearchEngine self-test passed")
    }
}
