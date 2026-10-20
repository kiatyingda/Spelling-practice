import Foundation

/// Build-time values injected from Config/Secrets.xcconfig via Info.plist.
enum AppConfig {
    static var appToken: String { string("APP_TOKEN") }
    static var defaultAPIBaseURL: String { string("API_BASE_URL") }

    private static func string(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespaces) ?? ""
    }
}
