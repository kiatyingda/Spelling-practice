import { LongPress } from '../LongPress'
import { go } from '../useHashRoute'
import { useSheets } from '../useSheets'
import { ProgressBar, ProgressLegend } from './Progress'

export function ChildHome() {
  const { sheets } = useSheets()
  return (
    <main className="screen">
      <header className="bar">
        <h1>听写</h1>
        <LongPress onDone={() => go('/parent')}>Hold for parent</LongPress>
      </header>
      {sheets && sheets.length === 0 && (
        <section className="empty">
          <p className="lead">No sheets yet.</p>
          <p className="muted">Ask a grown-up to add this week's list.</p>
        </section>
      )}
      <section className="cards">
        {sheets?.map((s) => (
          <article key={s.id} className="card">
            <div className="card-head">
              <span className="tag">{s.lang === 'zh' ? '中文' : 'English'}</span>
              {s.testReady && <span className="tag good">Test-ready</span>}
            </div>
            <h2>{s.title}</h2>
            <ProgressBar sheet={s} />
            <ProgressLegend sheet={s} />
            <button className="btn primary wide" disabled title="Learn mode arrives in step 3">
              Learn
            </button>
          </article>
        ))}
      </section>
    </main>
  )
}
