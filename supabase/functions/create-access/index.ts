import { createClient } from 'npm:@supabase/supabase-js@2'
import {
  corsHeaders, json, normalizeAccessName, internalEmail,
  generateActivationCode, generateRandomPassword, hashActivationCode,
  getPublicKey, getSecretKey,
} from '../_shared/auth-utils.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Método não permitido' }, 405)

  let createdUserId: string | null = null
  let createdClientId: string | null = null
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const authHeader = req.headers.get('Authorization') || ''
    const requester = createClient(supabaseUrl, getPublicKey(), {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false, autoRefreshToken: false },
    })
    const admin = createClient(supabaseUrl, getSecretKey(), {
      auth: { persistSession: false, autoRefreshToken: false },
    })

    const { data: userData, error: userError } = await requester.auth.getUser()
    if (userError || !userData.user) return json({ error: 'Sessão inválida' }, 401)
    const { data: requesterProfile } = await admin.from('profiles').select('role').eq('id', userData.user.id).single()
    if (requesterProfile?.role !== 'admin') return json({ error: 'Acesso negado' }, 403)

    const body = await req.json()
    const name = String(body?.name || '').trim()
    const accessName = String(body?.access_name || '').trim()
    const contactName = String(body?.contact_name || '').trim()
    const contactEmail = String(body?.contact_email || '').trim() || null
    const recoveryEmail = String(body?.recovery_email || '').trim() || null
    const category = String(body?.category || 'Social Media').trim() || 'Social Media'
    const clientId = body?.client_id ? String(body.client_id) : null
    if (!name && !clientId) throw new Error('Informe o nome do cliente')
    if (!accessName) throw new Error('Informe o nome de acesso')

    const accessKey = normalizeAccessName(accessName)
    const authEmail = internalEmail(accessName)
    const { data: exists } = await admin.from('profiles').select('id').eq('access_key', accessKey).maybeSingle()
    if (exists?.id) return json({ error: 'Esse nome de acesso já está em uso.' }, 409)

    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email: authEmail,
      password: generateRandomPassword(),
      email_confirm: true,
      user_metadata: { full_name: contactName || name || accessName, access_name: accessName },
    })
    if (createError) throw createError
    createdUserId = created.user.id

    let finalClientId = clientId
    if (!finalClientId) {
      const { data: client, error: clientError } = await admin.from('clients').insert({
        name,
        initials: name.split(/\s+/).filter(Boolean).slice(0,2).map((x:string)=>x[0]).join('').toUpperCase(),
        contact_name: contactName || null,
        contact_email: contactEmail,
        category,
        created_by: userData.user.id,
      }).select().single()
      if (clientError) throw clientError
      finalClientId = client.id
      createdClientId = client.id

      const monthStart = new Date().toISOString().slice(0,7) + '-01'
      const { data: editorial, error: edError } = await admin.from('editorials').insert({
        client_id: finalClientId,
        month_start: monthStart,
        created_by: userData.user.id,
      }).select().single()
      if (edError) throw edError
      const { error: versionError } = await admin.from('editorial_versions').insert({
        editorial_id: editorial.id,
        version: 1,
        status: 'draft',
        created_by: userData.user.id,
      })
      if (versionError) throw versionError
    }

    const { error: profileError } = await admin.from('profiles').update({
      role: 'client', client_id: finalClientId,
      full_name: contactName || name || accessName,
      access_name: accessName, access_key: accessKey,
      auth_email: authEmail, recovery_email: recoveryEmail,
    }).eq('id', created.user.id)
    if (profileError) throw profileError

    if (body?.commercial) {
      const c = body.commercial
      await admin.from('client_commercials').upsert({
        client_id: finalClientId,
        services: Array.isArray(c.services) ? c.services : [],
        monthly_fee: c.monthly_fee ?? null,
        deliverables_per_month: c.deliverables_per_month ?? null,
        contract_status: c.contract_status || 'none',
        pricing_plan: c.pricing_plan || {},
        internal_notes: c.internal_notes || null,
      })
    }

    const activationCode = generateActivationCode()
    const activationHash = await hashActivationCode(activationCode)
    const expires = new Date(Date.now() + 72 * 60 * 60 * 1000).toISOString()
    const { error: securityError } = await admin.from('account_security').upsert({
      user_id: created.user.id,
      activation_code_hash: activationHash,
      activation_expires_at: expires,
      activation_failed_attempts: 0,
      activation_locked_until: null,
      activated_at: null,
      recovery_question_key: null,
      recovery_answer_hash: null,
      recovery_failed_attempts: 0,
      recovery_locked_until: null,
    })
    if (securityError) throw securityError

    return json({
      ok: true,
      client_id: finalClientId,
      user_id: created.user.id,
      access_name: accessName,
      activation_code: activationCode,
      expires_at: expires,
    })
  } catch (error) {
    try {
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!
      const admin = createClient(supabaseUrl, getSecretKey(), { auth: { persistSession: false, autoRefreshToken: false } })
      if (createdUserId) await admin.auth.admin.deleteUser(createdUserId)
      if (createdClientId) await admin.from('clients').delete().eq('id', createdClientId)
    } catch (_) {}
    return json({ error: error instanceof Error ? error.message : String(error) }, 400)
  }
})
