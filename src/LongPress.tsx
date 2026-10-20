import { useRef, useState, type ReactNode } from 'react'

/** Parent gate: hold for `ms` to trigger. A kid tapping won't get through. */
export function LongPress({ ms = 1500, onDone, children }: { ms?: number; onDone: () => void; children: ReactNode }) {
  const timer = useRef<number | undefined>(undefined)
  const [holding, setHolding] = useState(false)
  const start = () => {
    setHolding(true)
    timer.current = window.setTimeout(() => {
      setHolding(false)
      onDone()
    }, ms)
  }
  const cancel = () => {
    setHolding(false)
    window.clearTimeout(timer.current)
  }
  return (
    <button
      className={`gate ${holding ? 'holding' : ''}`}
      style={{ ['--hold-ms' as string]: `${ms}ms` }}
      onPointerDown={start}
      onPointerUp={cancel}
      onPointerLeave={cancel}
      onPointerCancel={cancel}
      onContextMenu={(e) => e.preventDefault()}
    >
      {children}
    </button>
  )
}
