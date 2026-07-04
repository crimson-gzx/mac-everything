import Foundation

@main
struct SearchEngineSelfTest {
    static func main() {
        let entries = [
            FileEntry(path: "/Users/test/Documents/report-final.pdf", name: "report-final.pdf", isDirectory: false, modifiedAt: nil, size: 10),
            FileEntry(path: "/Users/test/Documents/report-notes.txt", name: "report-notes.txt", isDirectory: false, modifiedAt: nil, size: 10),
            FileEntry(path: "/Users/test/Documents/Reports", name: "Reports", isDirectory: true, modifiedAt: nil, size: nil),
            FileEntry(path: "/Users/test/Pictures/photo.jpg", name: "photo.jpg", isDirectory: false, modifiedAt: nil, size: 10)
        ]

        let ranked = SearchEngine.search("report", in: entries)
        precondition(ranked.first?.name == "Reports", "Prefix ranking failed")
        precondition(ranked.map(\.name).contains("report-final.pdf"), "Expected PDF result")

        let pdfs = SearchEngine.search("report ext:pdf", in: entries)
        precondition(pdfs.map(\.name) == ["report-final.pdf"], "Extension filter failed")

        let folders = SearchEngine.search("report type:folder", in: entries)
        precondition(folders.count == 1 && folders.first?.isDirectory == true, "Folder filter failed")

        let files = SearchEngine.search("report type:file", in: entries)
        precondition(files.allSatisfy { !$0.isDirectory }, "File filter failed")

        print("SearchEngine self-test passed")
    }
}
