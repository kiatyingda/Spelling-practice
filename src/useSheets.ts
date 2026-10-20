import { useCallback, useEffect, useState } from 'react'
import { listSheets } from './db'
import type { Sheet } from './types'

export function useSheets() {
  const [sheets, setSheets] = useState<Sheet[] | null>(null)
  const refresh = useCallback(() => {
    listSheets().then(setSheets)
  }, [])
  useEffect(refresh, [refresh])
  return { sheets, refresh }
}
