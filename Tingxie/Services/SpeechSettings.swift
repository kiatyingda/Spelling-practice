import AVFoundation

/// Parent-controlled voice and pace. Stored in UserDefaults (keys shared with @AppStorage).
struct SpeechSettings {
    enum Key {
        static let zhVoice = "zhVoiceID"
        static let enVoice = "enVoiceID"
        static let pace = "pace"
        static let repeatGap = "repeatGapSec"
        static let itemGap = "itemGapSec"
        static let apiBaseURL = "apiBaseURL"
    }

    static let defaultPace = 0.85
    static let defaultRepeatGap = 3.0
    static let defaultItemGap = 10.0

    var zhVoiceID: String?
    var enVoiceID: String?
    /// Multiplier on the system's normal speaking rate (0.5–1.1).
    var pace: Double

    static var current: SpeechSettings {
        let d = UserDefaults.standard
        return SpeechSettings(
            zhVoiceID: d.string(forKey: Key.zhVoice).flatMap { $0.isEmpty ? nil : $0 },
            enVoiceID: d.string(forKey: Key.enVoice).flatMap { $0.isEmpty ? nil : $0 },
            pace: d.object(forKey: Key.pace) as? Double ?? defaultPace)
    }

    func voiceID(for lang: Lang) -> String? { lang == .zh ? zhVoiceID : enVoiceID }

    static func utteranceRate(pace: Double) -> Float {
        let r = AVSpeechUtteranceDefaultSpeechRate * Float(pace)
        return min(max(r, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
    }
}
