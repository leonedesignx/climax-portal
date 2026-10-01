export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const enc = new TextEncoder()

export function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

export function normalizeAccessName(value = '') {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').trim().toLowerCase().replace(/\s+/g, ' ')
}

export function accessSlug(value = '') {
  return normalizeAccessName(value)
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/-+/g, '-')
}

export function internalEmail(accessName: string) {
  const slug = accessSlug(accessName)
  if (!slug) throw new Error('Nome de acesso inválido')
  return `${slug}@auth.climaxportal.com.br`
}

export function normalizeCode(value = '') {
  return value.toUpperCase().replace(/[^A-Z0-9]/g, '')
}

function toHex(bytes: Uint8Array) {
  return [...bytes].map((b) => b.toString(16).padStart(2, '0')).join('')
}

function fromBase64(value: string) {
  const raw = atob(value)
  return Uint8Array.from(raw, (c) => c.charCodeAt(0))
}

function toBase64(bytes: Uint8Array) {
  let s = ''
  bytes.forEach((b) => (s += String.fromCharCode(b)))
  return btoa(s)
}

export async function sha256(value: string) {
  const digest = await crypto.subtle.digest('SHA-256', enc.encode(value))
  return toHex(new Uint8Array(digest))
}

export async function hashActivationCode(code: string) {
  return sha256(normalizeCode(code))
}

export async function hashRecoveryAnswer(answer: string, iterations = 160000) {
  const salt = crypto.getRandomValues(new Uint8Array(16))
  const normalized = normalizeAccessName(answer)
  const key = await crypto.subtle.importKey('raw', enc.encode(normalized), 'PBKDF2', false, ['deriveBits'])
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', hash: 'SHA-256', salt, iterations },
    key,
    256,
  )
  return `pbkdf2$${iterations}$${toBase64(salt)}$${toBase64(new Uint8Array(bits))}`
}

export async function verifyRecoveryAnswer(answer: string, stored: string) {
  const [kind, iterText, saltText, hashText] = String(stored || '').split('$')
  if (kind !== 'pbkdf2' || !iterText || !saltText || !hashText) return false
  const iterations = Number(iterText)
  const salt = fromBase64(saltText)
  const expected = fromBase64(hashText)
  const normalized = normalizeAccessName(answer)
  const key = await crypto.subtle.importKey('raw', enc.encode(normalized), 'PBKDF2', false, ['deriveBits'])
  const bits = new Uint8Array(await crypto.subtle.deriveBits(
    { name: 'PBKDF2', hash: 'SHA-256', salt, iterations },
    key,
    expected.byteLength * 8,
  ))
  if (bits.length !== expected.length) return false
  let diff = 0
  for (let i = 0; i < bits.length; i++) diff |= bits[i] ^ expected[i]
  return diff === 0
}

const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
export function generateActivationCode() {
  const arr = crypto.getRandomValues(new Uint8Array(8))
  const value = [...arr].map((n) => CODE_CHARS[n % CODE_CHARS.length]).join('')
  return `CLX-${value.slice(0, 4)}-${value.slice(4)}`
}

export function generateRandomPassword(length = 40) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%*_-'
  const arr = crypto.getRandomValues(new Uint8Array(length))
  return [...arr].map((n) => chars[n % chars.length]).join('')
}

export function getPublicKey() {
  const legacy = Deno.env.get('SUPABASE_ANON_KEY')
  if (legacy) return legacy
  const raw = Deno.env.get('SUPABASE_PUBLISHABLE_KEYS')
  if (raw) {
    const parsed = JSON.parse(raw)
    return parsed.default || Object.values(parsed)[0]
  }
  throw new Error('Chave pública do Supabase indisponível')
}

export function getSecretKey() {
  const legacy = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (legacy) return legacy
  const raw = Deno.env.get('SUPABASE_SECRET_KEYS')
  if (raw) {
    const parsed = JSON.parse(raw)
    return parsed.default || Object.values(parsed)[0]
  }
  throw new Error('Chave secreta do Supabase indisponível')
}

export function isLocked(value: string | null | undefined) {
  return Boolean(value && new Date(value).getTime() > Date.now())
}
