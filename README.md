# 听写 Practice (iPad)

Native SwiftUI iPad app for Chinese 听写 and English spelling. A parent sets up each weekly sheet;
the child learns, drills, then does a mock 听写 on paper that the app marks from a photo.

The earlier PWA (steps 1–2 only) lives on the `pwa` branch.

## Stack
- SwiftUI, iPadOS 17+, landscape. SwiftData for storage, single device, no account.
- AVSpeechSynthesizer for zh-CN / en-GB dictation.
- PencilKit for English writing; hanzi-writer (bundled JS in a WKWebView) for Chinese stroke quizzes.
- VisionKit document scanner for the teacher's sheet and the written answers.
- `server/`: one Vercel function, `/api/vision`, that calls Claude. The Anthropic key never ships in the app.

## Mac setup (one-time)
1. Install Xcode from the App Store, open it once, and sign in: Xcode → Settings → Accounts → `+` → Apple ID.
   A free Apple ID is enough.
2. `brew install xcodegen`
3. `cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig` and fill in:
   - `DEVELOPMENT_TEAM`: Xcode → Settings → Accounts → your team → Team ID
     (or open the project once, pick the team under Signing & Capabilities, and copy it from Build Settings).
   - `APP_TOKEN` and `API_BASE_URL`: see **Server** below. Leave them blank until then; scanning won't work but everything else will.
4. `xcodegen` (run in the repo root). This writes `Tingxie.xcodeproj`, which is gitignored: re-run it after every `git pull`.
5. `open Tingxie.xcodeproj`

## Install on the iPad
1. Plug the iPad in, unlock it, tap **Trust**.
2. On the iPad: Settings → Privacy & Security → **Developer Mode** → on, then restart it.
3. In Xcode, pick the iPad as the run destination and press ⌘R.
4. First launch only: on the iPad, Settings → General → VPN & Device Management → your Apple ID → **Trust**.

**Free accounts expire after 7 days.** When the app stops opening, plug in and press ⌘R again. Data is kept.

Better voices: on the iPad, Settings → Accessibility → Spoken Content → Voices → download a Premium or
Enhanced Chinese (China mainland) and English (UK) voice. Then pick them in the app's parent settings.

## Server
`server/` is a separate Vercel project (set **Root Directory** to `server` when importing). Environment variables:

| Name | Value |
|---|---|
| `ANTHROPIC_API_KEY` | your Anthropic key |
| `APP_TOKEN` | any long random string; same value in `Config/Secrets.xcconfig` |

## CI
`.github/workflows/ios.yml` runs on every push: XcodeGen → `xcodebuild build test` on an iPad simulator,
and a typecheck of `server/`. A step counts as shipped only when CI is green on `main`.

## Build order
1. ~~Project shell, parent gate, CI, server skeleton~~
2. ~~SwiftData models + sheet editor + TTS + settings~~
3. Learn mode (PencilKit / hanzi-writer) + hints
4. Drill + mastery rules
5. `/api/vision` + document scanner capture
6. Mock 听写 + photo marking
7. Results + progress view
