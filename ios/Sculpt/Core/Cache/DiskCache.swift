import Foundation

/// A tiny Codable disk cache for stale-while-revalidate launches: persist the
/// last good value, show it instantly on next launch, then refresh in the
/// background. Lives in Caches/ so the OS can reclaim it under pressure.
enum DiskCache {
    private static let dir: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("sculpt-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private static func file(_ key: String) -> URL {
        dir.appendingPathComponent(key.replacingOccurrences(of: "/", with: "_") + ".json")
    }

    static func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            try? data.write(to: file(key), options: .atomic)
        }
    }

    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = try? Data(contentsOf: file(key)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func remove(_ key: String) {
        try? FileManager.default.removeItem(at: file(key))
    }

    static func clearAll() {
        try? FileManager.default.removeItem(at: dir)
    }
}
