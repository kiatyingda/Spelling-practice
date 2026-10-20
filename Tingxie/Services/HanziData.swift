import Foundation

/// hanzi-writer stroke data per character: fetched once from the CDN, then served from
/// Application Support so practice works offline.
actor HanziData {
    static let shared = HanziData()

    private static let cdn = URL(string: "https://cdn.jsdelivr.net/npm/hanzi-writer-data@2.0.1/")!
    private let dir: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("hanzi-writer-data", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    nonisolated static func isHan(_ ch: Character) -> Bool {
        ch.unicodeScalars.count == 1 && ch.unicodeScalars.first!.properties.isIdeographic
    }

    nonisolated static func characters(in text: String) -> [String] {
        var seen = Set<Character>()
        return text.filter { isHan($0) && seen.insert($0).inserted }.map(String.init)
    }

    /// Raw JSON for one character, or nil if it isn't cached and the network is unavailable.
    func json(for ch: String) async -> Data? {
        let file = dir.appendingPathComponent(ch.unicodeScalars.map { String($0.value, radix: 16) }.joined() + ".json")
        if let data = try? Data(contentsOf: file) { return data }
        do {
            let (data, response) = try await URLSession.shared.data(from: Self.cdn.appendingPathComponent(ch + ".json"))
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  (try? JSONSerialization.jsonObject(with: data)) != nil else { return nil }
            try? data.write(to: file, options: .atomic)
            return data
        } catch {
            return nil
        }
    }

    func prefetch(_ text: String) async {
        for ch in Self.characters(in: text) { _ = await json(for: ch) }
    }
}
