import { createClient } from 'npm:@supabase/supabase-js@2'
import {
  corsHeaders, json, normalizeAccessName, verifyRecoveryAnswer,
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
    const action = String(body?.action || '')
    const accessName = String(body?.access_name || '').trim()
    if (!accessName) throw new Error('Informe seu nome de acesso')
    const accessKey = normalizeAccessName(accessName)
    const { data: profile } = await admin.from('profiles').select('id').eq('access_key', accessKey).maybeSingle()
    if (!profile?.id) return json({ error: 'Não encontramos uma recuperação configurada para esse acesso.' }, 404)
    const { data: sec } = await admin.from('account_security').select('*').eq('user_id', profile.id).maybeSingle()
    if (!sec?.activated_at || !sec?.recovery_question_key || !sec?.recovery_answer_hash) return json({ error: 'Não encontramos uma recuperação configurada para esse acesso.' }, 404)

    if (action === 'question') {
      return json({ ok: true, question_key: sec.recovery_question_key })
    }
    if (action !== 'reset') return json({ error: 'Ação inválida' }, 400)
    if (isLocked(sec.recovery_locked_until)) return json({ error: 'Muitas tentativas. Aguarde alguns minutos e tente novamente.' }, 429)

    const answer = String(body?.recovery_answer || '').trim()
    const password = String(body?.new_password || '')
    if (!answer) throw new Error('Informe sua resposta de recuperação')
    if (password.length < 8) throw new Error('A nova senha precisa ter pelo menos 8 caracteres')
    const valid = await verifyRecoveryAnswer(answer, sec.recovery_answer_hash)
    if (!valid) {
      const attempts = Number(sec.recovery_failed_attempts || 0) + 1
      await admin.from('account_security').update({
        recovery_failed_attempts: attempts,
        recovery_locked_until: attempts >= 5 ? new Date(Date.now() + 15 * 60 * 1000).toISOString() : null,
      }).eq('user_id', profile.id)
      return json({ error: attempts >= 5 ? 'Muitas tentativas. Recuperação bloqueada por 15 minutos.' : 'Resposta de recuperação incorreta.' }, attempts >= 5 ? 429 : 400)
    }

    const { error: authError } = await admin.auth.admin.updateUserById(profile.id, { password })
    if (authError) throw authError
    await admin.from('account_security').update({ recovery_failed_attempts: 0, recovery_locked_until: null }).eq('user_id', profile.id)
    return json({ ok: true })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : String(error) }, 400)
  }
})
