import AVFoundation

/// Ranks installed voices: exact locale, Premium/Enhanced quality, then known good names.
/// Ported from the web version's ranking; novelty voices sink to the bottom.
struct VoiceCandidate: Equatable {
    var identifier: String
    var name: String
    var language: String
    var quality: AVSpeechSynthesisVoiceQuality

    private static let novelty = try! NSRegularExpression(
        pattern: "eddy|flo|grandma|grandpa|reed|rocko|sandy|shelley|bad news|bahh|bells|boing|bubbles|cellos|good news|jester|organ|superstar|trinoids|whisper|wobble|zarvox|albert|fred|junior|ralph|kathy",
        options: .caseInsensitive)
    private static let preferred: [Lang: NSRegularExpression] = [
        .zh: try! NSRegularExpression(pattern: "tingting|ting-ting|lili|lilian|yu-?shu|li-mu", options: .caseInsensitive),
        .en: try! NSRegularExpression(pattern: "daniel|kate|serena|stephanie|arthur|martha|oliver", options: .caseInsensitive),
    ]

    private static func matches(_ re: NSRegularExpression, _ s: String) -> Bool {
        re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    var normalisedLanguage: String { language.replacingOccurrences(of: "_", with: "-").lowercased() }

    func isFor(_ lang: Lang) -> Bool { normalisedLanguage.hasPrefix(lang == .zh ? "zh" : "en") }

    func score(for lang: Lang) -> Int {
        let l = normalisedLanguage
        var s = 0
        if l == lang.bcp47.lowercased() { s += 100 }
        else if lang == .en, ["en-sg", "en-au", "en-ie", "en-nz"].contains(where: l.hasPrefix) { s += 40 }
        switch quality {
        case .premium: s += 30
        case .enhanced: s += 20
        default: break
        }
        if let re = Self.preferred[lang], Self.matches(re, name) { s += 10 }
        if Self.matches(Self.novelty, name) { s -= 80 }
        return s
    }

    static func ranked(_ all: [VoiceCandidate], for lang: Lang) -> [VoiceCandidate] {
        all.filter { $0.isFor(lang) }
            .sorted { a, b in
                let (sa, sb) = (a.score(for: lang), b.score(for: lang))
                return sa != sb ? sa > sb : a.name < b.name
            }
    }
}

/// Dictation voice. `speak` resolves when the utterance finishes (or is interrupted).
@MainActor
final class Speech: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Speech()

    private let synth = AVSpeechSynthesizer()
    private var pending: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synth.delegate = self
        // Play even with the silent switch on; dictation is the whole point.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
    }

    static func voices(for lang: Lang) -> [VoiceCandidate] {
        let all = AVSpeechSynthesisVoice.speechVoices().map {
            VoiceCandidate(identifier: $0.identifier, name: $0.name, language: $0.language, quality: $0.quality)
        }
        return VoiceCandidate.ranked(all, for: lang)
    }

    func speak(_ text: String, lang: Lang, settings: SpeechSettings = .current) async {
        stop()
        let u = AVSpeechUtterance(string: text)
        let chosen = settings.voiceID(for: lang)
        let voice = chosen.flatMap(AVSpeechSynthesisVoice.init(identifier:))
            ?? Self.voices(for: lang).first.flatMap { AVSpeechSynthesisVoice(identifier: $0.identifier) }
            ?? AVSpeechSynthesisVoice(language: lang.bcp47)
        u.voice = voice
        u.rate = SpeechSettings.utteranceRate(pace: settings.pace)
        try? AVAudioSession.sharedInstance().setActive(true)
        await withCheckedContinuation { c in
            pending = c
            synth.speak(u)
        }
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        finish()
    }

    private func finish() {
        pending?.resume()
        pending = nil
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in self.finish() }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        Task { @MainActor in self.finish() }
    }
}
