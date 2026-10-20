/** crypto.randomUUID needs a secure context; LAN dev on http://<ip> isn't one. */
export function uid(): string {
  if (typeof globalThis.crypto?.randomUUID === 'function') {
    try {
      return crypto.randomUUID()
    } catch {
      /* fall through */
    }
  }
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 10)
}
