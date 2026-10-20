import { timingSafeEqual } from 'node:crypto'

/**
 * POST /api/vision — the only server route. Keeps ANTHROPIC_API_KEY off the iPad.
 * Callers must send `x-app-token: <APP_TOKEN>`. Sheet extraction and answer marking land in step 5.
 */
export async function POST(req: Request): Promise<Response> {
  if (!authorised(req)) return json({ error: 'unauthorised' }, 401)
  return json({ error: 'not implemented' }, 501)
}

function authorised(req: Request): boolean {
  const expected = process.env.APP_TOKEN
  const got = req.headers.get('x-app-token')
  if (!expected || !got) return false
  const a = Buffer.from(got)
  const b = Buffer.from(expected)
  return a.length === b.length && timingSafeEqual(a, b)
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } })
}
