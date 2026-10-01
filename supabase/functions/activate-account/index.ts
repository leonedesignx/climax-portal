import { createClient } from 'npm:@supabase/supabase-js@2'
import {
  corsHeaders, json, normalizeAccessName, hashActivationCode, hashRecoveryAnswer,
  getSecretKey, isLocked,
} from '../_shared/auth-utils.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Método não permitido' }, 405)
  try {
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, getSecretKey(), {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    const body = await req.json()
    const action = String(body?.action || 'activate')
    const accessName = String(body?.access_name || '').trim()
    const code = String(body?.activation_code || '').trim()
    const password = String(body?.password || '')
    const question = String(body?.recovery_question || '')
    const answer = String(body?.recovery_answer || '').trim()
    if (!accessName || !code) throw new Error('Informe nome de acesso e código temporário')
    if (!['verify','activate'].includes(action)) throw new Error('Ação inválida')
    if (action === 'activate' && password.length < 8) throw new Error('A senha precisa ter pelo menos 8 caracteres')
    if (action === 'activate' && (!question || answer.length < 2)) throw new Error('Configure sua recuperação de conta')

    const accessKey = normalizeAccessName(accessName)
    const { data: profile } = await admin.from('profiles').select('id,auth_email').eq('access_key', accessKey).maybeSingle()
    if (!profile?.id) return json({ error: 'Nome de acesso ou código temporário inválido.' }, 400)
    const { data: sec } = await admin.from('account_security').select('*').eq('user_id', profile.id).maybeSingle()
    if (!sec) return json({ error: 'Primeiro acesso não configurado para esta conta.' }, 400)
    if (sec.activated_at) return json({ error: 'Este acesso já foi ativado. Entre usando sua senha.' }, 409)
    if (isLocked(sec.activation_locked_until)) return json({ error: 'Muitas tentativas. Aguarde alguns minutos e tente novamente.' }, 429)
    if (!sec.activation_expires_at || new Date(sec.activation_expires_at).getTime() < Date.now()) return json({ error: 'Seu código de primeiro acesso expirou. Solicite um novo código à Clímax.' }, 410)

    const candidate = await hashActivationCode(code)
    if (candidate !== sec.activation_code_hash) {
      const attempts = Number(sec.activation_failed_attempts || 0) + 1
      await admin.from('account_security').update({
        activation_failed_attempts: attempts,
        activation_locked_until: attempts >= 5 ? new Date(Date.now() + 15 * 60 * 1000).toISOString() : null,
      }).eq('user_id', profile.id)
      return json({ error: attempts >= 5 ? 'Muitas tentativas. Acesso bloqueado por 15 minutos.' : 'Nome de acesso ou código temporário inválido.' }, attempts >= 5 ? 429 : 400)
    }

    if (action === 'verify') {
      return json({ ok: true })
    }

    const recoveryHash = await hashRecoveryAnswer(answer)
    const { error: authError } = await admin.auth.admin.updateUserById(profile.id, { password })
    if (authError) throw authError
    const { error: securityError } = await admin.from('account_security').update({
      activation_code_hash: null,
      activation_expires_at: null,
      activation_failed_attempts: 0,
      activation_locked_until: null,
      activated_at: new Date().toISOString(),
      recovery_question_key: question,
      recovery_answer_hash: recoveryHash,
      recovery_failed_attempts: 0,
      recovery_locked_until: null,
    }).eq('user_id', profile.id)
    if (securityError) throw securityError
    return json({ ok: true, auth_email: profile.auth_email })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : String(error) }, 400)
  }
})
