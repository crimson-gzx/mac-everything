import AppKit
import QuickLookUI

@MainActor
final class QuickLookPreviewer: NSObject, @preconcurrency QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookPreviewer()

    private var previewURLs: [URL] = []

    private override init() {
        super.init()
    }

    func preview(selected: FileEntry?, results: [FileEntry]) {
        let orderedEntries = orderedPreviewEntries(selected: selected, results: results)
        guard !orderedEntries.isEmpty else { return }

        previewURLs = orderedEntries.map(\.url)

        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        panel.currentPreviewItemIndex = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        QLPreviewPanel.shared()?.close()
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURLs.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard previewURLs.indices.contains(index) else { return nil }
        return previewURLs[index] as NSURL
    }

    private func orderedPreviewEntries(selected: FileEntry?, results: [FileEntry]) -> [FileEntry] {
        guard let selected else { return results }
        var ordered = [selected]
        ordered.append(contentsOf: results.filter { $0.id != selected.id })
        return ordered
    }
}
