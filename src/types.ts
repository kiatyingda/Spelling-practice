export type Lang = 'zh' | 'en'
export type ItemType = 'word' | 'sentence'
export type ItemStatus = 'new' | 'learning' | 'mastered'

export interface Item {
  id: string
  text: string
  type: ItemType
  status: ItemStatus
  cleanStreak: number
  lastSeenSession: string | null
  misses: number
}

export interface Sheet {
  id: string
  title: string
  lang: Lang
  createdAt: number
  items: Item[]
  testReady?: boolean
}

export interface SessionLog {
  id: string
  sheetId: string
  mode: 'learn' | 'drill' | 'mock'
  startedAt: number
  endedAt: number
  masteredCount: number
}
