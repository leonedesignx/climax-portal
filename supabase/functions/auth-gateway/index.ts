import { createClient } from 'npm:@supabase/supabase-js@2'

const C={
  'Access-Control-Allow-Origin':'*',
  'Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods':'POST, OPTIONS'
}
const R=(d:unknown,s=200)=>new Response(JSON.stringify(d),{status:s,headers:{...C,'Content-Type':'application/json'}})
const N=(v='')=>v.normalize('NFD').replace(/[\u0300-\u036f]/g,'').trim().toLowerCase().replace(/\s+/g,' ')
const E=new TextEncoder()
const B=(u:Uint8Array)=>{let s='';for(const x of u)s+=String.fromCharCode(x);return btoa(s)}

async function H(v:string){
  const d=await crypto.subtle.digest('SHA-256',E.encode(v))
  return [...new Uint8Array(d)].map(x=>x.toString(16).padStart(2,'0')).join('')
}
async function recoveryHash(answer:string){
  const salt=crypto.getRandomValues(new Uint8Array(16)),iterations=180000
  const key=await crypto.subtle.importKey('raw',E.encode(N(answer)),'PBKDF2',false,['deriveBits'])
  const bits=await crypto.subtle.deriveBits({name:'PBKDF2',hash:'SHA-256',salt,iterations},key,256)
  return `pbkdf2$${iterations}$${B(salt)}$${B(new Uint8Array(bits))}`
}

Deno.serve(async(req)=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:C})
  if(req.method!=='POST')return R({error:'Método não permitido.'},405)
  const url=Deno.env.get('SUPABASE_URL'),key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if(!url||!key)return R({error:'Configuração interna incompleta.'},500)
  const db=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}})
  try{
    const b=await req.json(),a=String(b?.action||'')
    if(a==='health')return R({ok:true})

    if(a==='admin-rescue-reset'){
      const name=String(b?.access_name||'').trim(),token=String(b?.rescue_token||'').trim(),pw=String(b?.temporary_password||'')
      if(!name||!token||pw.length<8)return R({error:'Dados inválidos.'},400)
      const {data:p}=await db.from('profiles').select('id,role').eq('access_key',N(name)).maybeSingle()
      if(!p?.id||p.role!=='admin')return R({error:'Código inválido.'},400)
      const {data:t}=await db.from('admin_rescue_tokens').select('token_hash,expires_at,used_at').eq('user_id',p.id).maybeSingle()
      if(!t||t.used_at||!t.expires_at||new Date(t.expires_at).getTime()<Date.now())return R({error:'Código inválido ou expirado.'},400)
      if(await H(token)!==t.token_hash)return R({error:'Código inválido ou expirado.'},400)
      const {error:e}=await db.auth.admin.updateUserById(p.id,{password:pw});if(e)throw e
      await db.from('profiles').update({must_change_password:true}).eq('id',p.id)
      await db.from('admin_rescue_tokens').update({used_at:new Date().toISOString()}).eq('user_id',p.id)
      return R({ok:true})
    }


    // Administrative password reset: authenticate the caller and authorize using
    // the server-owned profile role, never editable user metadata.
    if(a==='admin-reset-access'){
      const authorization=req.headers.get('Authorization')||''
      if(!authorization.startsWith('Bearer '))return R({error:'Sessão inválida.'},401)
      const {data:caller,error:callerError}=await db.auth.getUser(authorization.slice(7))
      if(callerError||!caller.user)return R({error:'Sessão inválida.'},401)
      const {data:actor,error:actorError}=await db.from('profiles').select('role').eq('id',caller.user.id).maybeSingle()
      if(actorError)throw actorError
      if(actor?.role!=='admin')return R({error:'Acesso negado.'},403)
      const userId=String(b?.user_id||''),password=String(b?.temporary_password||'')
      if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(userId))return R({error:'Cliente inválido.'},400)
      if(password.length<8||password.length>72)return R({error:'A senha temporária deve ter entre 8 e 72 caracteres.'},400)
      const {data:target,error:targetError}=await db.from('profiles').select('id,role,client_id,must_change_password').eq('id',userId).maybeSingle()
      if(targetError)throw targetError
      if(!target||target.role!=='client'||!target.client_id)return R({error:'O acesso não pertence a um cliente vinculado.'},400)
      // Set the first-access requirement before changing credentials; if Auth
      // rejects the password, restore the previous requirement.
      const {error:profileError}=await db.from('profiles').update({must_change_password:true,updated_at:new Date().toISOString()}).eq('id',userId).eq('role','client').select('id').single()
      if(profileError)throw profileError
      const {error:passwordError}=await db.auth.admin.updateUserById(userId,{password})
      if(passwordError){
        await db.from('profiles').update({must_change_password:target.must_change_password}).eq('id',userId).eq('role','client')
        throw passwordError
      }
      return R({ok:true})
    }

    if(a==='configure-recovery'){
      const h=req.headers.get('Authorization')||''
      if(!h.startsWith('Bearer '))return R({error:'Sessão inválida.'},401)
      const {data:u,error:ue}=await db.auth.getUser(h.slice(7))
      if(ue||!u.user)return R({error:'Sessão inválida.'},401)
      const q=String(b?.question_key||''),ans=String(b?.recovery_answer||'').trim()
      if(!['favorite_media','first_pet','birth_city','private_word'].includes(q)||ans.length<2)return R({error:'Recuperação inválida.'},400)
      const hash=await recoveryHash(ans),now=new Date().toISOString()
      const {error:se}=await db.from('account_security').upsert({
        user_id:u.user.id,recovery_question_key:q,recovery_answer_hash:hash,
        recovery_failed_attempts:0,recovery_locked_until:null,activated_at:now,updated_at:now
      },{onConflict:'user_id'});if(se)throw se
      const {error:pe}=await db.from('profiles').update({must_change_password:false,updated_at:now}).eq('id',u.user.id);if(pe)throw pe
      return R({ok:true})
    }

    return R({error:'Ação inválida.'},400)
  }catch(e){return R({error:e instanceof Error?e.message:String(e)},400)}
})
