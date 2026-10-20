import { counts } from '../progress'
import type { Sheet } from '../types'

/** new → learning → mastered as one segmented bar. */
export function ProgressBar({ sheet }: { sheet: Sheet }) {
  const c = counts(sheet)
  const total = sheet.items.length || 1
  return (
    <div className="progress" aria-label={`${c.mastered} of ${sheet.items.length} mastered`}>
      <span className="seg mastered" style={{ flexGrow: c.mastered / total }} />
      <span className="seg learning" style={{ flexGrow: c.learning / total }} />
      <span className="seg new" style={{ flexGrow: c.new / total }} />
    </div>
  )
}

export function ProgressLegend({ sheet }: { sheet: Sheet }) {
  const c = counts(sheet)
  return (
    <p className="legend">
      <span><i className="dot new" />{c.new} new</span>
      <span><i className="dot learning" />{c.learning} learning</span>
      <span><i className="dot mastered" />{c.mastered} mastered</span>
    </p>
  )
}
