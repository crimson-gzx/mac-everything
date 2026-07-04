import Foundation

struct FileEntry: Codable, Hashable, Identifiable, Sendable {
    let path: String
    let name: String
    let isDirectory: Bool
    let modifiedAt: Date?
    let size: Int64?

    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
    var fileExtension: String { url.pathExtension.lowercased() }
}

struct ParsedQuery: Sendable {
    var textTerms: [String] = []
    var extensions: Set<String> = []
    var wantsFolders: Bool?

    init(_ rawQuery: String) {
        let pieces = rawQuery
            .split(whereSeparator: \.isWhitespace)
            .map { String($0).lowercased() }

        for piece in pieces {
            if piece.hasPrefix("ext:") {
                let values = piece.dropFirst(4).split(separator: ",")
                extensions.formUnion(values.map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: ".")) })
            } else if piece == "type:folder" || piece == "type:dir" {
                wantsFolders = true
            } else if piece == "type:file" {
                wantsFolders = false
            } else {
                textTerms.append(piece)
            }
        }
    }
}

enum SearchEngine {
    static func search(_ rawQuery: String, in entries: [FileEntry], limit: Int = 500) -> [FileEntry] {
        let query = ParsedQuery(rawQuery.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !query.textTerms.isEmpty || !query.extensions.isEmpty || query.wantsFolders != nil else {
            return Array(entries.prefix(limit))
        }

        var ranked: [(entry: FileEntry, score: Int)] = []
        ranked.reserveCapacity(min(entries.count, limit * 4))

        for entry in entries {
            if let wantsFolders = query.wantsFolders, entry.isDirectory != wantsFolders { continue }
            if !query.extensions.isEmpty, !query.extensions.contains(entry.fileExtension) { continue }

            let name = entry.name.lowercased()
            let path = entry.path.lowercased()
            var score = entry.isDirectory ? 2 : 0
            var matched = true

            for term in query.textTerms {
                if name == term {
                    score += 1_000
                } else if name.hasPrefix(term) {
                    score += 650
                } else if let range = name.range(of: term) {
                    score += 420 - min(name.distance(from: name.startIndex, to: range.lowerBound), 120)
                } else if path.contains(term) {
                    score += 120
                } else {
                    matched = false
                    break
                }
            }

            if matched {
                score -= min(entry.path.count / 12, 80)
                ranked.append((entry, score))
            }
        }

        ranked.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.entry.name.localizedStandardCompare($1.entry.name) == .orderedAscending
        }
        return ranked.prefix(limit).map(\.entry)
    }
}
