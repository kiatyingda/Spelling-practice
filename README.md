# 听写 Practice

Chinese 听写 and English spelling practice PWA for iPad (with or without Apple Pencil).
Parent sets up each weekly sheet; child learns, drills, then does a mock 听写 on paper.

## Stack
Vite + React + TypeScript, `vite-plugin-pwa`, IndexedDB (`idb-keyval`), `hanzi-writer`,
Web Speech API. One Vercel serverless route, `/api/vision`, calls Claude with `ANTHROPIC_API_KEY`
(server env only — never `VITE_`-prefixed).

## Run
```bash
npm install
npm run dev        # http://<lan-ip>:5173 — open on the iPad on the same Wi-Fi
npm run build && npm run preview
```
Install on iPad: Safari → Share → Add to Home Screen.

## Deploy
Import the repo in Vercel (framework: Vite). Set `ANTHROPIC_API_KEY` in Project → Settings →
Environment Variables.

## Build order
1. ~~Scaffold + PWA manifest + Vercel config~~
2. Sheet CRUD (manual entry) + TTS
3. Learn mode (zh hanzi-writer, en canvas) + hints
4. Drill + mastery rules
5. `/api/vision` sheet extraction
6. Mock 听写 + photo marking
7. Results + progress view
