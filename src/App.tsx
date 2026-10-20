import { LongPress } from './LongPress'
import { go, useHashRoute } from './useHashRoute'

export default function App() {
  const route = useHashRoute()

  if (route.startsWith('/parent')) {
    return (
      <main className="screen">
        <header className="bar">
          <button className="btn ghost" onClick={() => go('/')}>← Back</button>
          <h1>Parent</h1>
          <span />
        </header>
        <section className="empty">
          <p>Sheets will be set up here.</p>
        </section>
      </main>
    )
  }

  return (
    <main className="screen">
      <header className="bar">
        <h1>听写</h1>
        <LongPress onDone={() => go('/parent')}>Hold for parent</LongPress>
      </header>
      <section className="empty">
        <p className="lead">No sheets yet.</p>
        <p className="muted">Ask a grown-up to add this week's list.</p>
      </section>
    </main>
  )
}
