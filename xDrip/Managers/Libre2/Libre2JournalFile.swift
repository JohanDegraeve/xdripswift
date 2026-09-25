import Foundation

/// Shared durable JSON file operations. Each caller keeps its own file and decides how
/// to handle missing or corrupt data; this helper never combines or resets journals.
enum Libre2JournalFile {
    static func url(_ name: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DirectLibre", isDirectory: true)
            .appendingPathComponent(name)
    }

    static func load<T: Decodable>(_ type: T.Type, from url: URL, fallback: T) throws -> T {
        guard FileManager.default.fileExists(atPath: url.path) else { return fallback }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }

    static func save<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
        let file = try FileHandle(forWritingTo: url)
        defer { try? file.close() }
        try file.synchronize()
    }
}
