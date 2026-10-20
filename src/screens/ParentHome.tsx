import { go } from '../useHashRoute'
import { useSheets } from '../useSheets'
import { ProgressBar } from './Progress'

export function ParentHome() {
  const { sheets } = useSheets()
  return (
    <main className="screen">
      <header className="bar">
        <button className="btn ghost" onClick={() => go('/')}>← Done</button>
        <h1>Parent</h1>
        <button className="btn" onClick={() => go('/parent/settings')}>Voices &amp; pace</button>
      </header>
      <div className="row">
        <button className="btn primary" onClick={() => go('/parent/sheet/new/zh')}>+ 中文 听写 sheet</button>
        <button className="btn primary" onClick={() => go('/parent/sheet/new/en')}>+ English spelling sheet</button>
      </div>
      {sheets && sheets.length === 0 && <p className="muted">No sheets yet. Add this week's list.</p>}
      <ul className="list">
        {sheets?.map((s) => (
          <li key={s.id}>
            <button className="list-row" onClick={() => go(`/parent/sheet/${s.id}`)}>
              <span className="tag">{s.lang === 'zh' ? '中文' : 'EN'}</span>
              <span className="grow">
                <strong>{s.title}</strong>
                <span className="muted small"> · {s.items.length} items · {new Date(s.createdAt).toLocaleDateString('en-SG')}</span>
              </span>
              <span className="mini"><ProgressBar sheet={s} /></span>
              <span aria-hidden>›</span>
            </button>
          </li>
        ))}
      </ul>
    </main>
  )
}
