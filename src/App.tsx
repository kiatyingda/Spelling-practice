import { ChildHome } from './screens/ChildHome'
import { ParentHome } from './screens/ParentHome'
import { SettingsScreen } from './screens/SettingsScreen'
import { SheetEditor } from './screens/SheetEditor'
import { useHashRoute } from './useHashRoute'

export default function App() {
  const route = useHashRoute()
  const parts = route.split('/').filter(Boolean)

  if (parts[0] === 'parent') {
    if (parts[1] === 'settings') return <SettingsScreen />
    if (parts[1] === 'sheet' && parts[2] === 'new') {
      const lang = parts[3] === 'en' ? 'en' : 'zh'
      return <SheetEditor key={`new-${lang}`} lang={lang} />
    }
    if (parts[1] === 'sheet' && parts[2]) return <SheetEditor key={parts[2]} id={parts[2]} />
    return <ParentHome />
  }
  return <ChildHome />
}
