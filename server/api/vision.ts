import { timingSafeEqual } from 'node:crypto'
import Anthropic from '@anthropic-ai/sdk'
import { zodOutputFormat } from '@anthropic-ai/sdk/helpers/zod'
import { z } from 'zod'

/**
 * POST /api/vision — the only server route. Keeps ANTHROPIC_API_KEY off the iPad.
 *
 * Headers: `x-app-token: <APP_TOKEN>`.
 * Body (JSON), images are base64 JPEG, at most 4:
 *   { task: "extract", images }                      → { lang, title, items: [{ text, type }] }
 *   { task: "mark", images, lang, items: [{ n, text }] } → { results: [{ n, correct, written, note }] }
 */

const MODEL = 'claude-sonnet-5-5'
const MAX_IMAGES = 4

const Extracted = z.object({
  lang: z.enum(['zh', 'en']),
  title: z.string().describe('Lesson or list title if printed on the sheet, e.g. "第5课", else empty'),
  items: z.array(z.object({ text: z.string(), type: z.enum(['word', 'sentence']) })),
})

const Marked = z.object({
  results: z.array(
    z.object({
      n: z.number().int(),
      written: z.string().describe('Exactly what the child wrote for this number; empty if blank or unreadable'),
      correct: z.boolean(),
      note: z.string().describe('Short reason when wrong, e.g. "园 written as 圆"; empty when correct'),
    }),
  ),
})

const Body = z.discriminatedUnion('task', [
  z.object({ task: z.literal('extract'), images: z.array(z.string().min(1)).min(1).max(MAX_IMAGES) }),
  z.object({
    task: z.literal('mark'),
    images: z.array(z.string().min(1)).min(1).max(MAX_IMAGES),
    lang: z.enum(['zh', 'en']),
    items: z.array(z.object({ n: z.number().int(), text: z.string() })).min(1).max(60),
  }),
])

const EXTRACT_PROMPT = `This is a Singapore primary-school weekly dictation list: Chinese 听写 or English spelling.
List every item the teacher will test, in the order printed.
- Copy each item exactly as printed, including punctuation for sentences. Use simplified Chinese as printed.
- Skip headings, item numbers, dates, instructions, pinyin, translations and the child's name.
- type is "sentence" for a phrase or sentence (Chinese: has punctuation or more than 6 characters; English: 4+ words or ends with . ! ?), otherwise "word".
- lang is "zh" if the items are Chinese, "en" if English.`

const markPrompt = (lang: 'zh' | 'en', items: { n: number; text: string }[]) => `These photos show a child's handwritten ${lang === 'zh' ? '听写 (Chinese dictation)' : 'English spelling test'}, numbered 1 to ${items.length}.
The expected answers are:
${items.map((i) => `${i.n}. ${i.text}`).join('\n')}

For every number above, read what the child wrote next to that number and mark it the way a teacher would:
${lang === 'zh'
  ? '- Every character must be correct. A wrong, missing or extra character, or a clearly wrong component, is wrong. Neat handwriting is not required.\n- For sentences, punctuation counts.'
  : '- Spelling must be exact. Ignore capitalisation of the first letter. For sentences, missing or wrong words and end punctuation count.'}
- If a number is blank, missing or unreadable, it is wrong with written "".
Return one result per expected number, in order.`

const client = new Anthropic()

export async function POST(req: Request): Promise<Response> {
  if (!authorised(req)) return json({ error: 'unauthorised' }, 401)

  let body: z.infer<typeof Body>
  try {
    body = Body.parse(await req.json())
  } catch {
    return json({ error: 'bad request' }, 400)
  }

  const used = await countToday()
  if (used > dailyCap()) return json({ error: 'daily limit reached' }, 429)

  const images = body.images.map((data) => ({
    type: 'image' as const,
    source: { type: 'base64' as const, media_type: 'image/jpeg' as const, data },
  }))

  try {
    if (body.task === 'extract') {
      const res = await client.messages.parse({
        model: MODEL,
        max_tokens: 8000,
        output_config: { effort: 'medium', format: zodOutputFormat(Extracted) },
        messages: [{ role: 'user', content: [...images, { type: 'text', text: EXTRACT_PROMPT }] }],
      })
      if (res.stop_reason === 'refusal' || !res.parsed_output) return json({ error: 'could not read the sheet' }, 502)
      const out = res.parsed_output
      return json({ ...out, items: out.items.filter((i) => i.text.trim()) })
    }

    const res = await client.messages.parse({
      model: MODEL,
      max_tokens: 8000,
      output_config: { effort: 'high', format: zodOutputFormat(Marked) },
      messages: [{ role: 'user', content: [...images, { type: 'text', text: markPrompt(body.lang, body.items) }] }],
    })
    if (res.stop_reason === 'refusal' || !res.parsed_output) return json({ error: 'could not mark the page' }, 502)
    // Exactly one result per expected item, in order; anything the model skipped is a miss.
    const byN = new Map(res.parsed_output.results.map((r) => [r.n, r]))
    const results = body.items.map((i) => byN.get(i.n) ?? { n: i.n, written: '', correct: false, note: 'not found on the page' })
    return json({ results })
  } catch (err) {
    if (err instanceof Anthropic.RateLimitError) return json({ error: 'busy, try again shortly' }, 503)
    if (err instanceof Anthropic.APIError) {
      console.error('anthropic error', err.status, err.message)
      return json({ error: 'vision service error' }, 502)
    }
    throw err
  }
}

function authorised(req: Request): boolean {
  const expected = process.env.APP_TOKEN
  const got = req.headers.get('x-app-token')
  if (!expected || !got) return false
  const a = Buffer.from(got)
  const b = Buffer.from(expected)
  return a.length === b.length && timingSafeEqual(a, b)
}

const dailyCap = () => Number(process.env.DAILY_CAP ?? 60)

/**
 * Requests so far today (SGT), including this one. Uses Upstash Redis REST when configured
 * (UPSTASH_REDIS_REST_URL / _TOKEN, e.g. via the Vercel marketplace); otherwise a per-instance
 * counter, which only caps a warm instance.
 */
let memory = { day: '', count: 0 }
async function countToday(): Promise<number> {
  const day = new Date(Date.now() + 8 * 3600_000).toISOString().slice(0, 10)
  const url = process.env.UPSTASH_REDIS_REST_URL
  const token = process.env.UPSTASH_REDIS_REST_TOKEN
  if (url && token) {
    const key = `tingxie:vision:${day}`
    const res = await fetch(`${url}/pipeline`, {
      method: 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify([['INCR', key], ['EXPIRE', key, 172800]]),
    })
    if (res.ok) {
      const [incr] = (await res.json()) as { result: number }[]
      return incr.result
    }
    console.error('rate counter unavailable', res.status)
  }
  if (memory.day !== day) memory = { day, count: 0 }
  return ++memory.count
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } })
}
