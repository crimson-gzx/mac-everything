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

enum SearchSort: String, CaseIterable, Identifiable, Sendable {
    case relevance
    case name
    case path
    case modifiedNewest
    case modifiedOldest
    case sizeLargest
    case sizeSmallest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .relevance: "相关度"
        case .name: "名称"
        case .path: "路径"
        case .modifiedNewest: "最近修改"
        case .modifiedOldest: "最早修改"
        case .sizeLargest: "大小降序"
        case .sizeSmallest: "大小升序"
        }
    }
}

private enum MatchScope: Sendable {
    case anywhere
    case name
    case path
}

private struct QueryTerm: Sendable {
    let alternatives: [TextMatcher]
    let scope: MatchScope

    init(_ raw: String, scope: MatchScope = .anywhere) {
        self.alternatives = raw
            .split(separator: "|", omittingEmptySubsequences: true)
            .map { TextMatcher(String($0)) }
        self.scope = scope
    }

    func matches(lowerName: String, lowerPath: String) -> Bool {
        switch scope {
        case .anywhere:
            alternatives.contains { $0.matches(lowerName) || $0.matches(lowerPath) }
        case .name:
            alternatives.contains { $0.matches(lowerName) }
        case .path:
            alternatives.contains { $0.matches(lowerPath) }
        }
    }

    func score(lowerName: String, lowerPath: String) -> Int? {
        var best: Int?
        for matcher in alternatives {
            let value: Int?
            switch scope {
            case .anywhere:
                value = max(matcher.score(in: lowerName, nameWeighted: true) ?? -1, matcher.score(in: lowerPath, nameWeighted: false) ?? -1)
            case .name:
                value = matcher.score(in: lowerName, nameWeighted: true)
            case .path:
                value = matcher.score(in: lowerPath, nameWeighted: false)
            }
            if let value, value >= 0 {
                best = max(best ?? value, value)
            }
        }
        return best
    }
}

private struct TextMatcher: Sendable {
    let raw: String
    private let wildcardRegex: NSRegularExpression?

    init(_ raw: String) {
        self.raw = raw.lowercased()
        if raw.contains("*") || raw.contains("?") {
            let escaped = NSRegularExpression.escapedPattern(for: raw.lowercased())
                .replacingOccurrences(of: "\\*", with: ".*")
                .replacingOccurrences(of: "\\?", with: ".")
            wildcardRegex = try? NSRegularExpression(pattern: "^" + escaped + "$", options: [.caseInsensitive])
        } else {
            wildcardRegex = nil
        }
    }

    func matches(_ value: String) -> Bool {
        if let wildcardRegex {
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            return wildcardRegex.firstMatch(in: value, range: range) != nil
        }
        return value.contains(raw)
    }

    func score(in value: String, nameWeighted: Bool) -> Int? {
        if let wildcardRegex {
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            guard wildcardRegex.firstMatch(in: value, range: range) != nil else { return nil }
            return nameWeighted ? 760 : 220
        }

        if value == raw { return nameWeighted ? 1_200 : 360 }
        if value.hasPrefix(raw) { return nameWeighted ? 820 : 260 }
        if let range = value.range(of: raw) {
            let offset = value.distance(from: value.startIndex, to: range.lowerBound)
            return (nameWeighted ? 520 : 160) - min(offset, nameWeighted ? 180 : 90)
        }
        return nil
    }
}

private struct SizeRule: Sendable {
    enum Operator: Sendable { case greaterThan, greaterOrEqual, lessThan, lessOrEqual, equal }

    let op: Operator
    let bytes: Int64

    func matches(_ size: Int64?) -> Bool {
        guard let size else { return false }
        switch op {
        case .greaterThan: return size > bytes
        case .greaterOrEqual: return size >= bytes
        case .lessThan: return size < bytes
        case .lessOrEqual: return size <= bytes
        case .equal: return size == bytes
        }
    }
}

private struct DateRule: Sendable {
    let after: Date?
    let before: Date?

    func matches(_ date: Date?) -> Bool {
        guard let date else { return false }
        if let after, date < after { return false }
        if let before, date >= before { return false }
        return true
    }
}

private struct ParsedQuery: Sendable {
    var includeTerms: [QueryTerm] = []
    var excludeTerms: [QueryTerm] = []
    var extensions: Set<String> = []
    var excludedExtensions: Set<String> = []
    var wantsFolders: Bool?
    var sizeRules: [SizeRule] = []
    var dateRules: [DateRule] = []
    var requestedSort: SearchSort?

    init(_ rawQuery: String) {
        for originalPart in Self.splitQuery(rawQuery) {
            var piece = originalPart.lowercased()
            guard !piece.isEmpty else { continue }

            let isExclusion = piece.hasPrefix("!") || piece.hasPrefix("-")
            if isExclusion { piece.removeFirst() }
            guard !piece.isEmpty else { continue }

            if piece.hasPrefix("sort:") || piece.hasPrefix("order:") {
                if let sort = Self.parseSort(String(piece.dropFirst(piece.hasPrefix("sort:") ? 5 : 6))) {
                    requestedSort = sort
                }
                continue
            }

            if piece.hasPrefix("ext:") || piece.hasPrefix("extension:") {
                let prefixLength = piece.hasPrefix("ext:") ? 4 : 10
                let values = Self.parseExtensions(String(piece.dropFirst(prefixLength)))
                if isExclusion { excludedExtensions.formUnion(values) } else { extensions.formUnion(values) }
                continue
            }

            if piece == "type:folder" || piece == "type:dir" || piece == "folder:" || piece == "folder" {
                wantsFolders = isExclusion ? false : true
                continue
            }
            if piece == "type:file" || piece == "file:" || piece == "file" {
                wantsFolders = isExclusion ? true : false
                continue
            }

            if piece.hasPrefix("size:") {
                if !isExclusion, let rule = Self.parseSizeRule(String(piece.dropFirst(5))) {
                    sizeRules.append(rule)
                }
                continue
            }

            if piece.hasPrefix("date:") || piece.hasPrefix("dm:") || piece.hasPrefix("modified:") {
                let prefixLength: Int
                if piece.hasPrefix("date:") { prefixLength = 5 }
                else if piece.hasPrefix("dm:") { prefixLength = 3 }
                else { prefixLength = 9 }
                if !isExclusion, let rule = Self.parseDateRule(String(piece.dropFirst(prefixLength))) {
                    dateRules.append(rule)
                }
                continue
            }

            let scopedTerm: QueryTerm
            if piece.hasPrefix("name:") || piece.hasPrefix("file:") {
                scopedTerm = QueryTerm(String(piece.dropFirst(5)), scope: .name)
            } else if piece.hasPrefix("path:") {
                scopedTerm = QueryTerm(String(piece.dropFirst(5)), scope: .path)
            } else {
                scopedTerm = QueryTerm(piece, scope: .anywhere)
            }

            if isExclusion { excludeTerms.append(scopedTerm) } else { includeTerms.append(scopedTerm) }
        }
    }

    private static func splitQuery(_ raw: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var inQuote = false

        for char in raw {
            if char == "\"" {
                inQuote.toggle()
                continue
            }
            if char.isWhitespace, !inQuote {
                if !current.isEmpty {
                    parts.append(current)
                    current.removeAll(keepingCapacity: true)
                }
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }

    private static func parseExtensions(_ raw: String) -> Set<String> {
        Set(raw.split(separator: ",").map {
            String($0).trimmingCharacters(in: CharacterSet(charactersIn: ". ")).lowercased()
        }.filter { !$0.isEmpty })
    }

    private static func parseSort(_ raw: String) -> SearchSort? {
        switch raw {
        case "relevance", "rank", "score": .relevance
        case "name", "n": .name
        case "path", "p": .path
        case "date", "modified", "new", "newest", "dm": .modifiedNewest
        case "old", "oldest": .modifiedOldest
        case "size", "big", "largest": .sizeLargest
        case "small", "smallest": .sizeSmallest
        default: nil
        }
    }

    private static func parseSizeRule(_ raw: String) -> SizeRule? {
        let op: SizeRule.Operator
        let value: Substring
        if raw.hasPrefix(">=") {
            op = .greaterOrEqual
            value = raw.dropFirst(2)
        } else if raw.hasPrefix("<=") {
            op = .lessOrEqual
            value = raw.dropFirst(2)
        } else if raw.hasPrefix(">") {
            op = .greaterThan
            value = raw.dropFirst()
        } else if raw.hasPrefix("<") {
            op = .lessThan
            value = raw.dropFirst()
        } else if raw.hasPrefix("=") {
            op = .equal
            value = raw.dropFirst()
        } else {
            op = .greaterOrEqual
            value = Substring(raw)
        }

        guard let bytes = parseByteCount(String(value)) else { return nil }
        return SizeRule(op: op, bytes: bytes)
    }

    private static func parseByteCount(_ raw: String) -> Int64? {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else { return nil }

        let numberPart = cleaned.prefix { $0.isNumber || $0 == "." }
        let unit = cleaned.dropFirst(numberPart.count)
        guard let number = Double(numberPart) else { return nil }

        let multiplier: Double
        switch unit {
        case "", "b", "byte", "bytes": multiplier = 1
        case "k", "kb": multiplier = 1_024
        case "m", "mb": multiplier = 1_024 * 1_024
        case "g", "gb": multiplier = 1_024 * 1_024 * 1_024
        case "t", "tb": multiplier = 1_024 * 1_024 * 1_024 * 1_024
        default: return nil
        }
        return Int64(number * multiplier)
    }

    private static func parseDateRule(_ raw: String) -> DateRule? {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        switch raw {
        case "today":
            return DateRule(after: today, before: calendar.date(byAdding: .day, value: 1, to: today))
        case "yesterday":
            return DateRule(after: calendar.date(byAdding: .day, value: -1, to: today), before: today)
        case "week", "thisweek", "last7d", "7d":
            return DateRule(after: calendar.date(byAdding: .day, value: -7, to: now), before: nil)
        case "month", "thismonth", "last30d", "30d":
            return DateRule(after: calendar.date(byAdding: .day, value: -30, to: now), before: nil)
        default:
            break
        }

        if raw.hasPrefix(">"), let date = parseDate(String(raw.dropFirst())) {
            return DateRule(after: date, before: nil)
        }
        if raw.hasPrefix("<"), let date = parseDate(String(raw.dropFirst())) {
            return DateRule(after: nil, before: calendar.date(byAdding: .day, value: 1, to: date))
        }
        if let date = parseDate(raw) {
            return DateRule(after: date, before: calendar.date(byAdding: .day, value: 1, to: date))
        }
        return nil
    }

    private static func parseDate(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        for format in ["yyyy-MM-dd", "yyyy/MM/dd", "yyyyMMdd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }
        return nil
    }
}

enum SearchEngine {
    static func search(_ rawQuery: String, in entries: [FileEntry], limit: Int = 500, sort: SearchSort = .relevance) -> [FileEntry] {
        let query = ParsedQuery(rawQuery.trimmingCharacters(in: .whitespacesAndNewlines))
        let effectiveSort = query.requestedSort ?? sort
        let isEmptyQuery = query.includeTerms.isEmpty
            && query.excludeTerms.isEmpty
            && query.extensions.isEmpty
            && query.excludedExtensions.isEmpty
            && query.wantsFolders == nil
            && query.sizeRules.isEmpty
            && query.dateRules.isEmpty

        if isEmptyQuery {
            return Array(sortEntries(entries, sort: effectiveSort).prefix(limit))
        }

        var ranked: [(entry: FileEntry, score: Int)] = []
        ranked.reserveCapacity(min(entries.count, limit * 4))

        for entry in entries {
            if let wantsFolders = query.wantsFolders, entry.isDirectory != wantsFolders { continue }
            if !query.extensions.isEmpty, !query.extensions.contains(entry.fileExtension) { continue }
            if query.excludedExtensions.contains(entry.fileExtension) { continue }
            if !query.sizeRules.allSatisfy({ $0.matches(entry.size) }) { continue }
            if !query.dateRules.allSatisfy({ $0.matches(entry.modifiedAt) }) { continue }

            let name = entry.name.lowercased()
            let path = entry.path.lowercased()
            if query.excludeTerms.contains(where: { $0.matches(lowerName: name, lowerPath: path) }) { continue }

            var score = entry.isDirectory ? 2 : 0
            var matched = true

            for term in query.includeTerms {
                guard let termScore = term.score(lowerName: name, lowerPath: path) else {
                    matched = false
                    break
                }
                score += termScore
            }

            if matched {
                score -= min(entry.path.count / 12, 80)
                ranked.append((entry, score))
            }
        }

        if effectiveSort == .relevance {
            ranked.sort {
                if $0.score != $1.score { return $0.score > $1.score }
                return compare($0.entry, $1.entry, sort: .name)
            }
            return ranked.prefix(limit).map(\.entry)
        }
        return Array(sortEntries(ranked.map(\.entry), sort: effectiveSort).prefix(limit))
    }

    private static func sortEntries(_ entries: [FileEntry], sort: SearchSort) -> [FileEntry] {
        entries.sorted { compare($0, $1, sort: sort) }
    }

    private static func compare(_ lhs: FileEntry, _ rhs: FileEntry, sort: SearchSort) -> Bool {
        switch sort {
        case .relevance:
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        case .name:
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        case .path:
            return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
        case .modifiedNewest:
            return (lhs.modifiedAt ?? .distantPast) > (rhs.modifiedAt ?? .distantPast)
        case .modifiedOldest:
            return (lhs.modifiedAt ?? .distantFuture) < (rhs.modifiedAt ?? .distantFuture)
        case .sizeLargest:
            return (lhs.size ?? -1) > (rhs.size ?? -1)
        case .sizeSmallest:
            return (lhs.size ?? Int64.max) < (rhs.size ?? Int64.max)
        }
    }
}
