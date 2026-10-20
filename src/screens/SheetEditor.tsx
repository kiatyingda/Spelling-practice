import { useEffect, useRef, useState } from 'react'
import { deleteSheet, getSheet, guessType, newItem, newSheet, saveSheet } from '../db'
import { speak } from '../tts'
import type { Item, Lang, Sheet } from '../types'
import { go } from '../useHashRoute'
import { useSettings } from '../useSettings'

/** Create or edit a sheet. Reused by the photo-capture confirm screen in step 5 via `initial`. */
export function SheetEditor({ id, lang, initial }: { id?: string; lang?: Lang; initial?: Sheet }) {
  const [draft, setDraft] = useState<Sheet | null>(initial ?? null)
  const original = useRef<Map<string, string>>(new Map())
  const [paste, setPaste] = useState('')
  const { settings } = useSettings()

  useEffect(() => {
    if (initial) return
    if (id) {
      getSheet(id).then((s) => {
        if (!s) return go('/parent')
        original.current = new Map(s.items.map((i) => [i.id, i.text]))
        setDraft(s)
      })
    } else {
      setDraft(newSheet(lang ?? 'zh'))
    }
  }, [id, lang, initial])

  if (!draft) return null
  const isNew = !id
  const voiceURI = draft.lang === 'zh' ? settings.zhVoiceURI : settings.enVoiceURI

  const setItems = (items: Item[]) => setDraft({ ...draft, items })
  const patchItem = (i: number, patch: Partial<Item>) =>
    setItems(draft.items.map((it, j) => (j === i ? { ...it, ...patch } : it)))
  const move = (i: number, d: -1 | 1) => {
    const j = i + d
    if (j < 0 || j >= draft.items.length) return
    const items = [...draft.items]
    ;[items[i], items[j]] = [items[j], items[i]]
    setItems(items)
  }
  const addLines = () => {
    const lines = paste.split(/\n+/).map((l) => l.trim()).filter(Boolean)
    if (!lines.length) return
    setItems([...draft.items, ...lines.map((l) => newItem(l, draft.lang))])
    setPaste('')
  }

  const save = async () => {
    const items = draft.items
      .map((it) => ({ ...it, text: it.text.trim() }))
      .filter((it) => it.text)
      // Changing an item's text means it's a different word: reset its progress.
      .map((it) => {
        const was = original.current.get(it.id)
        return was !== undefined && was !== it.text
          ? { ...it, status: 'new' as const, cleanStreak: 0, misses: 0, lastSeenSession: null }
          : it
      })
    if (!items.length) return alert('Add at least one item.')
    const title = draft.title.trim() || `Week of ${new Date(draft.createdAt).toLocaleDateString('en-SG', { day: 'numeric', month: 'short' })}`
    const changed = items.some((it) => original.current.get(it.id) !== it.text) || items.length !== original.current.size
    await saveSheet({ ...draft, title, items, testReady: changed ? false : draft.testReady })
    go('/parent')
  }

  const remove = async () => {
    if (!confirm(`Delete "${draft.title || 'this sheet'}"? Progress will be lost.`)) return
    await deleteSheet(draft.id)
    go('/parent')
  }

  return (
    <main className="screen">
      <header className="bar">
        <button className="btn ghost" onClick={() => go('/parent')}>← Cancel</button>
        <h1>{isNew ? 'New sheet' : 'Edit sheet'}</h1>
        <button className="btn primary" onClick={save}>Save</button>
      </header>

      <div className="row">
        <input
          className="field grow"
          placeholder="Title, e.g. 第5课 听写"
          value={draft.title}
          onChange={(e) => setDraft({ ...draft, title: e.target.value })}
        />
        <div className="seg-toggle" role="group" aria-label="Language">
          {(['zh', 'en'] as const).map((l) => (
            <button
              key={l}
              className={draft.lang === l ? 'on' : ''}
              disabled={!isNew}
              onClick={() => setDraft({ ...draft, lang: l })}
            >
              {l === 'zh' ? '中文' : 'English'}
            </button>
          ))}
        </div>
      </div>

      <ol className="items">
        {draft.items.map((it, i) => (
          <li key={it.id} className="item-row">
            <span className="num">{i + 1}</span>
            <input
              className="field grow"
              lang={draft.lang === 'zh' ? 'zh-CN' : 'en-GB'}
              value={it.text}
              autoCapitalize="off"
              autoCorrect="off"
              spellCheck={false}
              onChange={(e) => patchItem(i, { text: e.target.value })}
              onBlur={(e) => {
                // Re-guess the type for fresh items only; respect a manual toggle.
                if (!original.current.has(it.id)) patchItem(i, { type: guessType(e.target.value, draft.lang) })
              }}
            />
            <button className="btn icon" aria-label="Play" onClick={() => speak(it.text, draft.lang, { voiceURI, rate: settings.rate })}>
              ▶
            </button>
            <button
              className="btn chip"
              onClick={() => patchItem(i, { type: it.type === 'word' ? 'sentence' : 'word' })}
            >
              {it.type === 'word' ? (draft.lang === 'zh' ? '词语' : 'Word') : draft.lang === 'zh' ? '句子' : 'Sentence'}
            </button>
            <button className="btn icon" aria-label="Move up" disabled={i === 0} onClick={() => move(i, -1)}>↑</button>
            <button className="btn icon" aria-label="Move down" disabled={i === draft.items.length - 1} onClick={() => move(i, 1)}>↓</button>
            <button className="btn icon danger" aria-label="Delete" onClick={() => setItems(draft.items.filter((_, j) => j !== i))}>
              ✕
            </button>
          </li>
        ))}
      </ol>

      <section className="add-box">
        <textarea
          className="field"
          rows={4}
          lang={draft.lang === 'zh' ? 'zh-CN' : 'en-GB'}
          placeholder={draft.lang === 'zh' ? '一行一个词语或句子\n例如：\n美丽\n我们一起去公园。' : 'One word or sentence per line'}
          value={paste}
          autoCapitalize="off"
          autoCorrect="off"
          spellCheck={false}
          onChange={(e) => setPaste(e.target.value)}
        />
        <button className="btn" onClick={addLines} disabled={!paste.trim()}>Add items</button>
      </section>

      {!isNew && (
        <button className="btn danger-outline" onClick={remove}>Delete sheet</button>
      )}
    </main>
  )
}
