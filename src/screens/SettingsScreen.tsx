import { speak, voicesFor } from '../tts'
import type { Lang } from '../types'
import { go } from '../useHashRoute'
import { useSettings } from '../useSettings'

const SAMPLE: Record<Lang, string> = { zh: '我们一起去公园玩。', en: 'The quick brown fox jumps over the lazy dog.' }

export function SettingsScreen() {
  const { settings, update, voicesReady } = useSettings()

  const voiceSection = (lang: Lang) => {
    const list = voicesFor(lang)
    const key = lang === 'zh' ? 'zhVoiceURI' : 'enVoiceURI'
    const current = settings[key] ?? list[0]?.voiceURI ?? ''
    return (
      <section className="panel">
        <h2>{lang === 'zh' ? '中文 voice (zh-CN)' : 'English voice (en-GB)'}</h2>
        {voicesReady && list.length === 0 && (
          <p className="muted">
            No {lang === 'zh' ? 'Chinese' : 'English'} voice found. On iPad: Settings → Accessibility → Spoken Content → Voices.
          </p>
        )}
        <div className="row">
          <select className="field grow" value={current} onChange={(e) => update({ [key]: e.target.value })}>
            {list.map((v) => (
              <option key={v.voiceURI} value={v.voiceURI}>
                {v.name} · {v.lang}
              </option>
            ))}
          </select>
          <button className="btn" onClick={() => speak(SAMPLE[lang], lang, { voiceURI: current, rate: settings.rate })}>
            ▶ Test
          </button>
        </div>
      </section>
    )
  }

  return (
    <main className="screen">
      <header className="bar">
        <button className="btn ghost" onClick={() => go('/parent')}>← Back</button>
        <h1>Voices &amp; pace</h1>
        <span />
      </header>
      {voiceSection('zh')}
      {voiceSection('en')}
      <p className="muted small">
        Best quality: download a Premium or Enhanced voice on the iPad (Settings → Accessibility → Spoken Content → Voices), then pick it here.
      </p>
      <section className="panel">
        <h2>Pace</h2>
        <label className="slider">
          <span>Speech rate</span>
          <input type="range" min={0.5} max={1.1} step={0.05} value={settings.rate} onChange={(e) => update({ rate: +e.target.value })} />
          <output>{settings.rate.toFixed(2)}×</output>
        </label>
        <label className="slider">
          <span>Mock 听写: gap between the two readings</span>
          <input type="range" min={1} max={10} step={1} value={settings.repeatGapSec} onChange={(e) => update({ repeatGapSec: +e.target.value })} />
          <output>{settings.repeatGapSec}s</output>
        </label>
        <label className="slider">
          <span>Mock 听写: writing time before the next item</span>
          <input type="range" min={3} max={40} step={1} value={settings.itemGapSec} onChange={(e) => update({ itemGapSec: +e.target.value })} />
          <output>{settings.itemGapSec}s</output>
        </label>
      </section>
    </main>
  )
}
