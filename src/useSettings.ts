import { useCallback, useEffect, useState } from 'react'
import { DEFAULT_SETTINGS, getSettings, saveSettings, type Settings } from './db'
import { loadVoices } from './tts'

export function useSettings() {
  const [settings, setSettings] = useState<Settings>(DEFAULT_SETTINGS)
  const [voicesReady, setVoicesReady] = useState(false)
  useEffect(() => {
    getSettings().then(setSettings)
    loadVoices().then(() => setVoicesReady(true))
  }, [])
  const update = useCallback((patch: Partial<Settings>) => {
    setSettings((s) => {
      const next = { ...s, ...patch }
      saveSettings(next)
      return next
    })
  }, [])
  return { settings, update, voicesReady }
}
