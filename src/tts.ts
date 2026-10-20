import type { Lang } from './types'

export const TTS_LANG: Record<Lang, string> = { zh: 'zh-CN', en: 'en-GB' }

const NOVELTY = /eddy|flo|grandma|grandpa|reed|rocko|sandy|shelley|bad news|bahh|bells|boing|bubbles|cellos|good news|jester|organ|superstar|trinoids|whisper|wobble|zarvox|albert|fred|junior|ralph|kathy/i
const PREFERRED: Record<Lang, RegExp> = {
  zh: /tingting|ting-ting|lili|lilian|yu-?shu|xiaoxiao|yunxi|li-mu/i,
  en: /daniel|kate|serena|stephanie|arthur|martha|oliver|sonia|libby|ryan/i,
}

let cache: SpeechSynthesisVoice[] = []

/** iOS returns [] until voiceschanged fires; resolve on first non-empty list (or after 1.5s). */
export function loadVoices(): Promise<SpeechSynthesisVoice[]> {
  if (!('speechSynthesis' in window)) return Promise.resolve([])
  const now = speechSynthesis.getVoices()
  if (now.length) return Promise.resolve((cache = now))
  return new Promise((resolve) => {
    const done = () => resolve((cache = speechSynthesis.getVoices()))
    speechSynthesis.addEventListener('voiceschanged', done, { once: true })
    setTimeout(done, 1500)
  })
}

const norm = (l: string) => l.replace('_', '-').toLowerCase()

export function voicesFor(lang: Lang, all = cache): SpeechSynthesisVoice[] {
  const prefix = lang === 'zh' ? 'zh' : 'en'
  return all.filter((v) => norm(v.lang).startsWith(prefix)).sort((a, b) => score(b, lang) - score(a, lang))
}

function score(v: SpeechSynthesisVoice, lang: Lang): number {
  const l = norm(v.lang)
  let s = 0
  if (l === norm(TTS_LANG[lang])) s += 100
  else if (lang === 'zh' && l.startsWith('zh-cn')) s += 100
  else if (lang === 'en' && /en-(sg|au|ie|nz)/.test(l)) s += 40
  if (/premium/i.test(v.name)) s += 30
  if (/enhanced|natural|neural/i.test(v.name)) s += 20
  if (PREFERRED[lang].test(v.name)) s += 10
  if (NOVELTY.test(v.name)) s -= 80
  if (v.localService) s += 5
  return s
}

export function pickVoice(lang: Lang, uri: string | null): SpeechSynthesisVoice | undefined {
  const list = voicesFor(lang)
  return list.find((v) => v.voiceURI === uri) ?? list[0]
}

export interface SpeakOpts {
  voiceURI?: string | null
  rate?: number
}

/** Resolves when speech ends. Safari sometimes drops onend, so a length-based timeout backs it up. */
export function speak(text: string, lang: Lang, opts: SpeakOpts = {}): Promise<void> {
  if (!('speechSynthesis' in window)) return Promise.resolve()
  speechSynthesis.cancel()
  const u = new SpeechSynthesisUtterance(text)
  u.lang = TTS_LANG[lang]
  const v = pickVoice(lang, opts.voiceURI ?? null)
  if (v) u.voice = v
  u.rate = opts.rate ?? 0.85
  return new Promise((resolve) => {
    const perChar = lang === 'zh' ? 400 : 120
    const timer = setTimeout(resolve, 2000 + [...text].length * perChar / u.rate)
    const end = () => {
      clearTimeout(timer)
      resolve()
    }
    u.onend = end
    u.onerror = end
    speechSynthesis.speak(u)
  })
}

export const stopSpeaking = () => {
  if ('speechSynthesis' in window) speechSynthesis.cancel()
}
