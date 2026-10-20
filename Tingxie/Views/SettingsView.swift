import AVFoundation
import SwiftUI

struct SettingsView: View {
    let onClose: () -> Void

    @AppStorage(SpeechSettings.Key.zhVoice) private var zhVoice = ""
    @AppStorage(SpeechSettings.Key.enVoice) private var enVoice = ""
    @AppStorage(SpeechSettings.Key.pace) private var pace = SpeechSettings.defaultPace
    @AppStorage(SpeechSettings.Key.repeatGap) private var repeatGap = SpeechSettings.defaultRepeatGap
    @AppStorage(SpeechSettings.Key.itemGap) private var itemGap = SpeechSettings.defaultItemGap
    @AppStorage(SpeechSettings.Key.apiBaseURL) private var apiBaseURL = ""

    private static let sample: [Lang: String] = [.zh: "我们一起去公园玩。", .en: "The quick brown fox jumps over the lazy dog."]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(title: "Voices & pace") {
                    Button("← Back", action: onClose).buttonStyle(.surface)
                } trailing: {
                    EmptyView()
                }
                voicePanel(.zh, selection: $zhVoice)
                voicePanel(.en, selection: $enVoice)
                Text("Best quality: download a Premium or Enhanced voice on the iPad (Settings → Accessibility → Spoken Content → Voices), then pick it here.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)

                Panel {
                    Text("Pace").font(.title3.weight(.semibold))
                    slider("Speech rate", value: $pace, in: 0.5...1.1, step: 0.05, format: { String(format: "%.2f×", $0) })
                    slider("Mock 听写: gap between the two readings", value: $repeatGap, in: 1...10, step: 1, format: { "\(Int($0))s" })
                    slider("Mock 听写: writing time before the next item", value: $itemGap, in: 3...40, step: 1, format: { "\(Int($0))s" })
                }

                Panel {
                    Text("Photo marking server").font(.title3.weight(.semibold))
                    TextField(AppConfig.defaultAPIBaseURL.isEmpty ? "https://your-project.vercel.app" : AppConfig.defaultAPIBaseURL, text: $apiBaseURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .fieldStyle()
                    Text(AppConfig.appToken.isEmpty ? "No APP_TOKEN in this build: add it to Config/Secrets.xcconfig." : "App token is set.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .screen()
    }

    private func voicePanel(_ lang: Lang, selection: Binding<String>) -> some View {
        let voices = Speech.voices(for: lang)
        return Panel {
            Text(lang == .zh ? "中文 voice (zh-CN)" : "English voice (en-GB)").font(.title3.weight(.semibold))
            if voices.isEmpty {
                Text("No \(lang == .zh ? "Chinese" : "English") voice found. On iPad: Settings → Accessibility → Spoken Content → Voices.")
                    .foregroundStyle(Theme.muted)
            }
            HStack(spacing: 12) {
                Picker("Voice", selection: selection) {
                    Text("Automatic\(voices.first.map { " (\($0.name))" } ?? "")").tag("")
                    ForEach(voices, id: \.identifier) { v in
                        Text("\(v.name) · \(v.language)\(Self.qualityLabel(v.quality))").tag(v.identifier)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, minHeight: Theme.touch, alignment: .leading)
                Button("▶ Test") {
                    Task { await Speech.shared.speak(Self.sample[lang] ?? "", lang: lang) }
                }
                .buttonStyle(.surface)
            }
        }
    }

    private static func qualityLabel(_ q: AVSpeechSynthesisVoiceQuality) -> String {
        switch q {
        case .premium: " · Premium"
        case .enhanced: " · Enhanced"
        default: ""
        }
    }

    private func slider(_ label: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double, format: @escaping (Double) -> String) -> some View {
        HStack(spacing: 16) {
            Text(label).frame(maxWidth: .infinity, alignment: .leading)
            Slider(value: value, in: range, step: step).frame(width: 260)
            Text(format(value.wrappedValue)).monospacedDigit().frame(width: 64, alignment: .trailing)
        }
        .frame(minHeight: Theme.touch)
    }
}
