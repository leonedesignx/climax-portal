import { createClient } from 'npm:@supabase/supabase-js@2'
import {
  corsHeaders, json, generateActivationCode, generateRandomPassword, hashActivationCode,
  getPublicKey, getSecretKey,
} from '../_shared/auth-utils.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Método não permitido' }, 405)
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const authHeader = req.headers.get('Authorization') || ''
    const requester = createClient(supabaseUrl, getPublicKey(), {
      global: { headers: { Authorization: authHeader } }, auth: { persistSession: false, autoRefreshToken: false },
    })
    const admin = createClient(supabaseUrl, getSecretKey(), { auth: { persistSession: false, autoRefreshToken: false } })
    const { data: userData, error: userError } = await requester.auth.getUser()
    if (userError || !userData.user) return json({ error: 'Sessão inválida' }, 401)
    const { data: requesterProfile } = await admin.from('profiles').select('role').eq('id', userData.user.id).single()
    if (requesterProfile?.role !== 'admin') return json({ error: 'Acesso negado' }, 403)

    const { user_id } = await req.json()
    if (!user_id) throw new Error('user_id é obrigatório')
    const code = generateActivationCode()
    const codeHash = await hashActivationCode(code)
    const expires = new Date(Date.now() + 72 * 60 * 60 * 1000).toISOString()
    const { error: authError } = await admin.auth.admin.updateUserById(user_id, { password: generateRandomPassword() })
    if (authError) throw authError
    const { error: secError } = await admin.from('account_security').upsert({
      user_id,
      activation_code_hash: codeHash,
      activation_expires_at: expires,
      activation_failed_attempts: 0,
      activation_locked_until: null,
      activated_at: null,
      recovery_question_key: null,
      recovery_answer_hash: null,
      recovery_failed_attempts: 0,
      recovery_locked_until: null,
    })
    if (secError) throw secError
    return json({ ok: true, activation_code: code, expires_at: expires })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : String(error) }, 400)
  }
})
