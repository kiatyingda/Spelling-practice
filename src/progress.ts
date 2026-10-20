import type { Sheet } from './types'

export function counts(s: Sheet) {
  const c = { new: 0, learning: 0, mastered: 0 }
  for (const i of s.items) c[i.status]++
  return c
}
