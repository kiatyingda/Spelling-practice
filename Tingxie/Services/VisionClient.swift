import UIKit

/// Client for server/api/vision. The Anthropic key stays on the server; the app sends APP_TOKEN.
enum VisionClient {
    struct Extracted: Decodable {
        struct Line: Decodable {
            let text: String
            let type: String
        }

        let lang: String
        let title: String
        let items: [Line]
    }

    struct MarkItem: Encodable {
        let n: Int
        let text: String
    }

    struct Mark: Decodable, Equatable {
        let n: Int
        let written: String
        let correct: Bool
        let note: String
    }

    enum Failure: LocalizedError {
        case notConfigured
        case server(String)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .notConfigured: "Set the photo marking server in Parent → Voices & pace, and APP_TOKEN in Secrets.xcconfig."
            case .server(let message): message
            case .badResponse: "The server sent back something unexpected."
            }
        }
    }

    static var baseURL: URL? {
        let stored = UserDefaults.standard.string(forKey: SpeechSettings.Key.apiBaseURL) ?? ""
        let raw = (stored.isEmpty ? AppConfig.defaultAPIBaseURL : stored).trimmingCharacters(in: .whitespaces)
        return raw.isEmpty ? nil : URL(string: raw)
    }

    static func extract(_ pages: [UIImage]) async throws -> Extracted {
        try await post(["task": "extract", "images": pages.map(encode)])
    }

    static func mark(_ pages: [UIImage], lang: Lang, items: [MarkItem]) async throws -> [Mark] {
        struct Response: Decodable { let results: [Mark] }
        let payload = items.map { ["n": $0.n, "text": $0.text] as [String: Any] }
        let res: Response = try await post(["task": "mark", "images": pages.map(encode), "lang": lang.rawValue, "items": payload])
        return res.results
    }

    /// Long edge ≤ 1600px JPEG keeps four pages under Vercel's 4.5 MB body limit and is plenty for handwriting.
    static func encode(_ image: UIImage) -> String {
        let maxEdge: CGFloat = 1600
        let scale = min(1, maxEdge / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return (resized.jpegData(compressionQuality: 0.7) ?? Data()).base64EncodedString()
    }

    private static func post<T: Decodable>(_ body: [String: Any]) async throws -> T {
        guard let base = baseURL, !AppConfig.appToken.isEmpty else { throw Failure.notConfigured }
        var req = URLRequest(url: base.appendingPathComponent("api/vision"), timeoutInterval: 150)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(AppConfig.appToken, forHTTPHeaderField: "x-app-token")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw Failure.server(message.map { "Server: \($0)" } ?? "Server error (\(status)).")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw Failure.badResponse
        }
    }
}
