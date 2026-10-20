import { createStore, del, get, keys, getMany, set } from 'idb-keyval'
import type { Item, ItemType, Lang, Sheet } from './types'
import { uid } from './id'

const store = createStore('tingxie', 'kv')
const SHEET = 'sheet:'

export async function listSheets(): Promise<Sheet[]> {
  const ks = (await keys(store)).filter((k): k is string => typeof k === 'string' && k.startsWith(SHEET))
  const sheets = (await getMany<Sheet>(ks, store)).filter((s): s is Sheet => !!s)
  return sheets.sort((a, b) => b.createdAt - a.createdAt)
}

export const getSheet = (id: string) => get<Sheet>(SHEET + id, store)
export const saveSheet = (s: Sheet) => set(SHEET + s.id, s, store)
export const deleteSheet = (id: string) => del(SHEET + id, store)

export interface Settings {
  zhVoiceURI: string | null
  enVoiceURI: string | null
  rate: number
  /** Mock 听写: seconds between the two readings of one item. */
  repeatGapSec: number
  /** Mock 听写: seconds after the second reading before the next item. */
  itemGapSec: number
}

export const DEFAULT_SETTINGS: Settings = {
  zhVoiceURI: null,
  enVoiceURI: null,
  rate: 0.85,
  repeatGapSec: 3,
  itemGapSec: 10,
}

export async function getSettings(): Promise<Settings> {
  return { ...DEFAULT_SETTINGS, ...((await get<Partial<Settings>>('settings', store)) ?? {}) }
}
export const saveSettings = (s: Settings) => set('settings', s, store)

const ZH_PUNCT = /[。，！？；：、,.!?]/
export function guessType(text: string, lang: Lang): ItemType {
  const t = text.trim()
  if (lang === 'zh') return ZH_PUNCT.test(t) || [...t].length > 6 ? 'sentence' : 'word'
  return /[.!?]$/.test(t) || t.split(/\s+/).length >= 4 ? 'sentence' : 'word'
}

export function newItem(text: string, lang: Lang, type?: ItemType): Item {
  return {
    id: uid(),
    text: text.trim(),
    type: type ?? guessType(text, lang),
    status: 'new',
    cleanStreak: 0,
    lastSeenSession: null,
    misses: 0,
  }
}

export function newSheet(lang: Lang): Sheet {
  return { id: uid(), title: '', lang, createdAt: Date.now(), items: [] }
}
