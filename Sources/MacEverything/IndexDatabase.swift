import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum IndexDatabase {
    static var fileURL: URL {
        IndexStore.directoryURL.appendingPathComponent("file-index.sqlite")
    }

    static func load() throws -> StoredIndex {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let db = try open(readOnly: true)
        defer { sqlite3_close(db) }

        let version = Int(readMetadata(db: db, key: "version") ?? "0") ?? 0
        guard version == StoredIndex.currentVersion else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let createdAt = Date(timeIntervalSince1970: Double(readMetadata(db: db, key: "createdAt") ?? "0") ?? 0)
        let roots = decodeStringArray(readMetadata(db: db, key: "roots"))
        let excludedPaths = decodeStringArray(readMetadata(db: db, key: "excludedPaths"))
        let entries = try readEntries(db: db)

        return StoredIndex(
            version: version,
            createdAt: createdAt,
            roots: roots,
            excludedPaths: excludedPaths,
            entries: entries
        )
    }

    static func save(entries: [FileEntry], roots: [URL], excludedPaths: [String]) throws {
        try FileManager.default.createDirectory(at: IndexStore.directoryURL, withIntermediateDirectories: true)
        let db = try open(readOnly: false)
        defer { sqlite3_close(db) }

        try execute(db, "PRAGMA journal_mode=WAL")
        try execute(db, "PRAGMA synchronous=NORMAL")
        try createSchema(db: db)
        try dropIndexes(db: db)
        try execute(db, "BEGIN IMMEDIATE TRANSACTION")
        do {
            try execute(db, "DELETE FROM metadata")
            try? clearFTS(db: db)
            try execute(db, "DELETE FROM entries")
            try writeMetadata(db: db, key: "version", value: String(StoredIndex.currentVersion))
            try writeMetadata(db: db, key: "createdAt", value: String(Date().timeIntervalSince1970))
            try writeMetadata(db: db, key: "roots", value: encodeStringArray(roots.map(\.path)))
            try writeMetadata(db: db, key: "excludedPaths", value: encodeStringArray(AppSettings.normalized(paths: excludedPaths)))
            try insert(entries: entries, db: db)
            try execute(db, "COMMIT")
            try createIndexes(db: db)
        } catch {
            try? execute(db, "ROLLBACK")
            throw error
        }
    }

    static func applyChanges(upserts: [FileEntry], removals: [String]) throws {
        guard !upserts.isEmpty || !removals.isEmpty else { return }
        try FileManager.default.createDirectory(at: IndexStore.directoryURL, withIntermediateDirectories: true)
        let db = try open(readOnly: false)
        defer { sqlite3_close(db) }

        try execute(db, "PRAGMA journal_mode=WAL")
        try execute(db, "PRAGMA synchronous=NORMAL")
        try createSchema(db: db)
        try execute(db, "BEGIN IMMEDIATE TRANSACTION")
        do {
            for path in removals {
                try deletePathAndChildren(path, db: db)
            }
            for entry in upserts {
                try deletePathAndChildren(entry.path, db: db)
            }
            try insert(entries: upserts, db: db)
            try writeMetadata(db: db, key: "updatedAt", value: String(Date().timeIntervalSince1970))
            try execute(db, "COMMIT")
        } catch {
            try? execute(db, "ROLLBACK")
            throw error
        }
    }

    static func candidatePaths(for rawQuery: String, limit: Int = 5_000) -> [String]? {
        guard let matchQuery = makeFTSQuery(from: rawQuery) else { return nil }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        do {
            let db = try open(readOnly: true)
            defer { sqlite3_close(db) }

            let sql = """
            SELECT path
            FROM entries_fts
            WHERE entries_fts MATCH ?
            LIMIT ?
            """
            var statement: OpaquePointer?
            try prepare(db, sql, statement: &statement)
            defer { sqlite3_finalize(statement) }
            bindText(statement, 1, matchQuery)
            sqlite3_bind_int(statement, 2, Int32(limit))

            var paths: [String] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                if let text = sqlite3_column_text(statement, 0) {
                    paths.append(String(cString: text))
                }
            }
            return paths.isEmpty ? nil : paths
        } catch {
            return nil
        }
    }

    private static func open(readOnly: Bool) throws -> OpaquePointer? {
        var db: OpaquePointer?
        let flags = readOnly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE)
        let result = sqlite3_open_v2(fileURL.path, &db, flags, nil)
        guard result == SQLITE_OK, let db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Could not open database"
            if let db { sqlite3_close(db) }
            throw NSError(domain: "MacEverything.SQLite", code: Int(result), userInfo: [NSLocalizedDescriptionKey: message])
        }
        return db
    }

    private static func createSchema(db: OpaquePointer?) throws {
        try execute(db, """
        CREATE TABLE IF NOT EXISTS metadata (
            key TEXT PRIMARY KEY NOT NULL,
            value TEXT NOT NULL
        )
        """)
        try execute(db, """
        CREATE TABLE IF NOT EXISTS entries (
            path TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            is_directory INTEGER NOT NULL,
            modified_at REAL,
            size INTEGER,
            lower_name TEXT NOT NULL,
            lower_path TEXT NOT NULL,
            extension TEXT NOT NULL
        )
        """)
        try? execute(db, """
        CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts USING fts5(
            path,
            name,
            extension,
            tokenize='unicode61'
        )
        """)
    }

    private static func clearFTS(db: OpaquePointer?) throws {
        try execute(db, "DELETE FROM entries_fts")
    }

    private static func dropIndexes(db: OpaquePointer?) throws {
        try execute(db, "DROP INDEX IF EXISTS idx_entries_name")
        try execute(db, "DROP INDEX IF EXISTS idx_entries_extension")
        try execute(db, "DROP INDEX IF EXISTS idx_entries_modified")
        try execute(db, "DROP INDEX IF EXISTS idx_entries_size")
    }

    private static func createIndexes(db: OpaquePointer?) throws {
        try execute(db, "CREATE INDEX IF NOT EXISTS idx_entries_name ON entries(name)")
        try execute(db, "CREATE INDEX IF NOT EXISTS idx_entries_extension ON entries(extension)")
        try execute(db, "CREATE INDEX IF NOT EXISTS idx_entries_modified ON entries(modified_at)")
        try execute(db, "CREATE INDEX IF NOT EXISTS idx_entries_size ON entries(size)")
    }

    private static func readEntries(db: OpaquePointer?) throws -> [FileEntry] {
        let sql = """
        SELECT path, name, is_directory, modified_at, size
        FROM entries
        ORDER BY name COLLATE NOCASE ASC
        """
        var statement: OpaquePointer?
        try prepare(db, sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        var entries: [FileEntry] = []
        entries.reserveCapacity(100_000)

        while sqlite3_step(statement) == SQLITE_ROW {
            let path = String(cString: sqlite3_column_text(statement, 0))
            let name = String(cString: sqlite3_column_text(statement, 1))
            let isDirectory = sqlite3_column_int(statement, 2) != 0
            let modifiedAt: Date?
            if sqlite3_column_type(statement, 3) == SQLITE_NULL {
                modifiedAt = nil
            } else {
                modifiedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))
            }
            let size: Int64?
            if sqlite3_column_type(statement, 4) == SQLITE_NULL {
                size = nil
            } else {
                size = sqlite3_column_int64(statement, 4)
            }
            entries.append(FileEntry(path: path, name: name, isDirectory: isDirectory, modifiedAt: modifiedAt, size: size))
        }

        return entries
    }

    private static func deletePathAndChildren(_ path: String, db: OpaquePointer?) throws {
        let prefix = path + "/"
        try deleteFromTable("entries", path: path, prefix: prefix, db: db)
        try? deleteFromTable("entries_fts", path: path, prefix: prefix, db: db)
    }

    private static func deleteFromTable(_ table: String, path: String, prefix: String, db: OpaquePointer?) throws {
        let sql = "DELETE FROM \(table) WHERE path = ? OR substr(path, 1, ?) = ?"
        var statement: OpaquePointer?
        try prepare(db, sql, statement: &statement)
        defer { sqlite3_finalize(statement) }
        bindText(statement, 1, path)
        sqlite3_bind_int(statement, 2, Int32(prefix.count))
        bindText(statement, 3, prefix)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw sqliteError(db)
        }
    }

    private static func insert(entries: [FileEntry], db: OpaquePointer?) throws {
        let sql = """
        INSERT INTO entries (path, name, is_directory, modified_at, size, lower_name, lower_path, extension)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """
        var statement: OpaquePointer?
        try prepare(db, sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        let ftsStatement = try? prepareFTSInsert(db: db)
        defer { sqlite3_finalize(ftsStatement) }

        for entry in entries {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            bindText(statement, 1, entry.path)
            bindText(statement, 2, entry.name)
            sqlite3_bind_int(statement, 3, entry.isDirectory ? 1 : 0)
            if let modifiedAt = entry.modifiedAt {
                sqlite3_bind_double(statement, 4, modifiedAt.timeIntervalSince1970)
            } else {
                sqlite3_bind_null(statement, 4)
            }
            if let size = entry.size {
                sqlite3_bind_int64(statement, 5, size)
            } else {
                sqlite3_bind_null(statement, 5)
            }
            bindText(statement, 6, entry.name.lowercased())
            bindText(statement, 7, entry.path.lowercased())
            bindText(statement, 8, entry.fileExtension)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw sqliteError(db)
            }

            if let ftsStatement {
                try insertFTS(entry: entry, statement: ftsStatement, db: db)
            }
        }
    }

    private static func prepareFTSInsert(db: OpaquePointer?) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        try prepare(db, "INSERT INTO entries_fts (path, name, extension) VALUES (?, ?, ?)", statement: &statement)
        return statement
    }

    private static func insertFTS(entry: FileEntry, statement: OpaquePointer?, db: OpaquePointer?) throws {
        sqlite3_reset(statement)
        sqlite3_clear_bindings(statement)
        bindText(statement, 1, entry.path)
        bindText(statement, 2, entry.name.lowercased())
        bindText(statement, 3, entry.fileExtension)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw sqliteError(db)
        }
    }

    private static func writeMetadata(db: OpaquePointer?, key: String, value: String) throws {
        var statement: OpaquePointer?
        try prepare(db, "INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)", statement: &statement)
        defer { sqlite3_finalize(statement) }
        bindText(statement, 1, key)
        bindText(statement, 2, value)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw sqliteError(db)
        }
    }

    private static func readMetadata(db: OpaquePointer?, key: String) -> String? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT value FROM metadata WHERE key = ?", -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }
        bindText(statement, 1, key)
        guard sqlite3_step(statement) == SQLITE_ROW, let text = sqlite3_column_text(statement, 0) else {
            return nil
        }
        return String(cString: text)
    }

    private static func execute(_ db: OpaquePointer?, _ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw sqliteError(db)
        }
    }

    private static func prepare(_ db: OpaquePointer?, _ sql: String, statement: inout OpaquePointer?) throws {
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError(db)
        }
    }

    private static func bindText(_ statement: OpaquePointer?, _ index: Int32, _ value: String) {
        sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
    }

    private static func sqliteError(_ db: OpaquePointer?) -> NSError {
        let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite error"
        return NSError(domain: "MacEverything.SQLite", code: Int(sqlite3_errcode(db)), userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static func encodeStringArray(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values), let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    private static func decodeStringArray(_ value: String?) -> [String] {
        guard let value, let data = value.data(using: .utf8), let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
    }

    private static func sanitizedFTSTerm(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else { return nil }
        if value.hasPrefix("!") || value.hasPrefix("-") { return nil }
        if value.contains(":") || value.contains("|") { return nil }
        let wantsPrefix = value.hasSuffix("*")
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "*?"))
        let pieces = value.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        guard !pieces.isEmpty else { return nil }
        return pieces.map { $0 + (wantsPrefix ? "*" : "") }.joined(separator: " AND ")
    }

    private static func makeFTSQuery(from rawQuery: String) -> String? {
        let words = rawQuery.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let clean = words.compactMap { sanitizedFTSTerm($0) }
        guard !clean.isEmpty else { return nil }
        return clean.joined(separator: " AND ")
    }
}
