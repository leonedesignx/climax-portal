/* Client branding and the daily entry assistant. Shared by admin preview and client login. */
let clientBrandings={},portalUserPreferences={theme_mode:'brand',welcome_dismissed_on:null};
let portalThemeMode='dark',previewThemeMode='brand',appearanceSignature='',entryStartedUser=null,entryQuestionPending=false;
let entryState=null,entryTimer=null,entrySequence=0,entryIntroResolve=null,entryQuestionUserId=null;
const BRAND_DEFAULTS={enabled:false,primary_color:'#ADF403',secondary_color:'#C7FF3B',background_color:'#090A08',welcome_name:'',welcome_greeting:'neutral',avatar_path:null,avatarUrl:''};
const BRAND_CSS_PROPERTIES=['--bg','--bg-2','--panel','--panel-2','--panel-3','--line','--line-strong','--text','--muted','--muted-2','--lime','--lime-soft','--lime-ink','--on-accent','--accent-rgb','--brand-secondary','--shadow'];
function portalBrand(clientId){return {...BRAND_DEFAULTS,...(clientBrandings[clientId]||{})}}
function validBrandHex(value){return /^#[0-9a-f]{6}$/i.test(String(value||''))}
function hexRgb(value){const h=String(value).slice(1);return [0,2,4].map(i=>parseInt(h.slice(i,i+2),16))}
function rgbHex(rgb){return '#'+rgb.map(n=>Math.max(0,Math.min(255,Math.round(n))).toString(16).padStart(2,'0')).join('')}
function mixBrand(a,b,t){const x=hexRgb(a),y=hexRgb(b);return rgbHex(x.map((n,i)=>n+(y[i]-n)*t))}
function brandLuminance(hex){return hexRgb(hex).map(n=>{n/=255;return n<=.04045?n/12.92:Math.pow((n+.055)/1.055,2.4)}).reduce((v,n,i)=>v+n*[.2126,.7152,.0722][i],0)}
function brandContrast(a,b){const x=brandLuminance(a),y=brandLuminance(b);return (Math.max(x,y)+.05)/(Math.min(x,y)+.05)}
function brandTokens(brand){
 const background=validBrandHex(brand.background_color)?brand.background_color:BRAND_DEFAULTS.background_color;
 const primary=validBrandHex(brand.primary_color)?brand.primary_color:BRAND_DEFAULTS.primary_color;
 const secondary=validBrandHex(brand.secondary_color)?brand.secondary_color:primary;
 const light=brandLuminance(background)>.179,text=light?'#000000':'#FFFFFF';
 const surface=light?mixBrand(background,'#FFFFFF',.50):brandLuminance(background)>.12?mixBrand(background,'#000000',.09):mixBrand(background,'#FFFFFF',.045);
 const readable=value=>{let c=value;for(let i=0;i<=20&&Math.min(brandContrast(c,surface),brandContrast(c,background))<4.5;i++)c=mixBrand(value,text,(i+1)/21);return c};
 let accent=primary;
 for(let step=0;step<=20&&Math.min(brandContrast(accent,surface),brandContrast(accent,background))<4.5;step++)accent=mixBrand(primary,light?'#000000':'#FFFFFF',(step+1)/21);
 const onAccent=brandContrast('#101114',accent)>brandContrast('#FFFFFF',accent)?'#101114':'#FFFFFF';
 return {light,values:{'--bg':background,'--bg-2':mixBrand(background,text,.025),'--panel':surface,'--panel-2':mixBrand(background,text,.065),'--panel-3':mixBrand(background,text,.10),'--line':mixBrand(background,text,.17),'--line-strong':mixBrand(background,text,.26),'--text':text,'--muted':readable(mixBrand(text,background,.30)),'--muted-2':readable(mixBrand(text,background,.43)),'--lime':accent,'--lime-soft':mixBrand(accent,text,.15),'--lime-ink':accent,'--on-accent':onAccent,'--accent-rgb':hexRgb(accent).join(','),'--brand-secondary':secondary,'--shadow':light?'0 22px 60px rgba(0,0,0,.12)':'0 22px 60px rgba(0,0,0,.34)'}};
}
function clearClientPalette(){
 BRAND_CSS_PROPERTIES.forEach(k=>document.documentElement.style.removeProperty(k));
 delete document.documentElement.dataset.clientPalette;
}
function applyClientPalette(brand){
 const tokens=brandTokens(brand.enabled?brand:BRAND_DEFAULTS);
 document.documentElement.dataset.theme=tokens.light?'light':'dark';
 document.documentElement.dataset.clientPalette='true';
 Object.entries(tokens.values).forEach(([k,v])=>document.documentElement.style.setProperty(k,v));
 const meta=document.getElementById('themeColorMeta');if(meta)meta.content=tokens.values['--bg'];
 return tokens;
}
function clientThemePreferenceKey(){return 'climax-client-theme:'+authUser?.id+':'+currentClient}
function readAdminTheme(){try{return localStorage.getItem('climax-theme')||(window.matchMedia('(prefers-color-scheme: light)').matches?'light':'dark')}catch(_){return 'dark'}}
function syncClientAppearance(){
 const scoped=backendReady&&role==='client',brand=scoped?portalBrand(currentClient):null;
 const mode=scoped?(actualRole==='client'?portalUserPreferences.theme_mode:previewThemeMode):readAdminTheme();
 const signature=JSON.stringify([scoped,currentClient,mode,brand?.enabled,brand?.primary_color,brand?.secondary_color,brand?.background_color]);
 if(signature===appearanceSignature){syncPortalLogos();return}
 appearanceSignature=signature;portalThemeMode=mode;
 clearClientPalette();
 if(scoped&&mode==='brand'){
  const tokens=applyClientPalette(brand);currentTheme=tokens.light?'light':'dark';
 }else{
  currentTheme=mode==='light'?'light':'dark';document.documentElement.dataset.theme=currentTheme;
  const meta=document.getElementById('themeColorMeta');if(meta)meta.content=currentTheme==='light'?'#f3f5ef':'#090a08';
 }
 document.querySelectorAll('.brand-logo,.mobile-logo,.auth-showcase-logo,.auth-mobile-logo').forEach(img=>{if(DARK_LOGO)img.src=currentTheme==='light'?LIGHT_LOGO:DARK_LOGO});
 syncThemeUI();syncPortalLogos();
}
async function loadPortalPersonalization(){
 const [branding,prefs]=await Promise.all([db.from('client_portal_branding').select('*'),db.from('portal_user_preferences').select('theme_mode,welcome_dismissed_on').eq('user_id',authUser.id).maybeSingle()]);
 if(branding.error)throw branding.error;if(prefs.error)throw prefs.error;
 clientBrandings={};(branding.data||[]).forEach(b=>clientBrandings[b.client_id]={...b,avatarUrl:''});
 const paths=(branding.data||[]).filter(b=>b.avatar_path);
 if(paths.length){
  const signed=await db.storage.from('client-branding').createSignedUrls(paths.map(b=>b.avatar_path),86400);
  if(signed.error)throw signed.error;
  (signed.data||[]).forEach((url,i)=>clientBrandings[paths[i].client_id].avatarUrl=url.signedUrl||'');
 }
 portalUserPreferences={theme_mode:'brand',welcome_dismissed_on:null,...(prefs.data||{})};
 appearanceSignature='';
}
async function persistPortalPreferences(patch){
 if(actualRole!=='client'||!authUser)return;
 const next={...portalUserPreferences,...patch};
 const r=await db.from('portal_user_preferences').upsert({user_id:authUser.id,theme_mode:next.theme_mode,welcome_dismissed_on:next.welcome_dismissed_on||null,updated_at:new Date().toISOString()},{onConflict:'user_id'});
 if(r.error)throw r.error;
 portalUserPreferences=next;
}
async function selectPortalAppearance(mode){
 if(!['brand','light','dark'].includes(mode))return;
 if(role==='client'){
  if(actualRole==='client'){
   try{await persistPortalPreferences({theme_mode:mode});try{localStorage.setItem(clientThemePreferenceKey(),mode)}catch(_){}}
   catch(e){toast('Não foi possível salvar a aparência. Tente novamente.','error');return}
  }else previewThemeMode=mode;
 }else{
  if(mode==='brand')return;
  try{localStorage.setItem('climax-theme',mode)}catch(_){}
 }
 appearanceSignature='';syncClientAppearance();closeModal();closeMobileMore();closeProfile();render();
}
function openPortalAppearance(){
 const client=role==='client',brand=client?portalBrand(currentClient):null;
 const sampleBrand=brand?.enabled?brand:BRAND_DEFAULTS;
 const modes=client?[['brand','No seu modo',brand.enabled?'A identidade da sua marca.':'A paleta padrão do seu espaço.'],['light','Modo claro','Uma interface clara e confortável.'],['dark','Modo escuro','O visual escuro da Clímax.']]:[['light','Modo claro','Uma interface clara e confortável.'],['dark','Modo escuro','O visual escuro da Clímax.']];
 openModal('Aparência do portal','<p class="appearance-intro">Escolha como você quer ver seu espaço.</p><div class="portal-appearance-choices">'+modes.map(([mode,title,description])=>'<button class="portal-appearance-choice '+(portalThemeMode===mode?'active':'')+'" data-portal-appearance="'+mode+'" aria-pressed="'+(portalThemeMode===mode)+'"><span class="appearance-sample appearance-'+mode+'" '+(mode==='brand'?'style="--sample-bg:'+sampleBrand.background_color+';--sample-accent:'+sampleBrand.primary_color+';--sample-secondary:'+sampleBrand.secondary_color+'"':'')+'><i></i><i></i><i></i></span><strong>'+title+'</strong><small>'+description+'</small>'+(mode==='brand'?'<span class="appearance-default">Padrão do seu portal</span>':'')+'</button>').join('')+'</div>','<button class="btn btn-secondary" data-close-modal>Fechar</button>');
 document.querySelectorAll('[data-portal-appearance]').forEach(b=>b.onclick=()=>selectPortalAppearance(b.dataset.portalAppearance));
}
function clientAvatarHTML(client,extra=''){
 const url=portalBrand(client.id).avatarUrl;
 return url?'<img class="client-brand-avatar '+extra+'" src="'+escapeHtml(url)+'" alt="Foto de '+escapeHtml(client.name)+'" loading="lazy">':escapeHtml(client.init||makeInitials(client.name));
}
function welcomeIdentity(client,brand){
 const name=brand.welcome_name.trim()||(client.contact||client.displaySubtitle||client.name||'').trim().split(/\s+/)[0];
 const greeting={neutral:'Boas-vindas',feminine:'Seja bem-vinda',masculine:'Seja bem-vindo'}[brand.welcome_greeting]||'Boas-vindas';
 return {name,greeting};
}
function portalToday(){const parts=Object.fromEntries(new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date()).map(p=>[p.type,p.value]));return parts.year+'-'+parts.month+'-'+parts.day}
function questionDismissedToday(){
 if(portalUserPreferences.welcome_dismissed_on===portalToday())return true;
 try{return localStorage.getItem('climax-entry-dismiss:'+authUser.id)===portalToday()}catch(_){return false}
}
function entryOverlayElement(){
 let overlay=document.getElementById('portalEntryOverlay');
 if(!overlay){
  overlay=document.createElement('div');overlay.id='portalEntryOverlay';overlay.className='portal-entry-overlay';overlay.hidden=true;
  overlay.setAttribute('role','dialog');overlay.setAttribute('aria-modal','true');overlay.setAttribute('aria-labelledby','portalEntryTitle');overlay.setAttribute('aria-hidden','true');
  document.body.appendChild(overlay);
  overlay.addEventListener('keydown',e=>{
   if(e.key==='Escape'){e.preventDefault();e.stopPropagation();closePortalEntry();return}
   if(e.key==='Tab'){const targets=[...overlay.querySelectorAll('button:not([disabled])')],first=targets[0],last=targets[targets.length-1];if(!targets.length)return;if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus()}else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus()}}
  });
 }
 return overlay;
}
function paintEntryOverlay(client,brand,preview=false){
 const overlay=entryOverlayElement(),tokens=brandTokens(brand.enabled?brand:BRAND_DEFAULTS);
 Object.entries(tokens.values).forEach(([k,v])=>overlay.style.setProperty(k,v));
 overlay.style.colorScheme=tokens.light?'light':'dark';
 entryState={token:++entrySequence,preview,userId:authUser?.id,client,brand,previousFocus:document.activeElement,previousOverflow:document.body.style.overflow};
 overlay.hidden=false;overlay.setAttribute('aria-hidden','false');document.body.style.overflow='hidden';
 return overlay;
}
function closePortalEntry(){
 clearTimeout(entryTimer);const state=entryState;entryState=null;entrySequence++;const resolveIntro=entryIntroResolve;entryIntroResolve=null;if(resolveIntro)resolveIntro();
 const overlay=document.getElementById('portalEntryOverlay');if(overlay){overlay.hidden=true;overlay.setAttribute('aria-hidden','true');overlay.replaceChildren()}
 if(state){document.body.style.overflow=state.previousOverflow||'';if(state.previousFocus?.isConnected)state.previousFocus.focus()}
}
function entryAvatar(brand,client){
 return brand.avatarUrl?'<img data-entry-avatar alt="">':'<span>'+escapeHtml(client.init||makeInitials(client.name))+'</span>';
}
async function showClientEntryIntro(client,brand,preview=false){
 const overlay=paintEntryOverlay(client,brand,preview),state=entryState,who=welcomeIdentity(client,brand);
 setSafeHTML(overlay,'<section class="entry-intro"><div class="entry-avatar">'+entryAvatar(brand,client)+'</div><small>SEU ESPAÇO NA CLÍMAX</small><h2 id="portalEntryTitle">'+escapeHtml(who.greeting)+(who.name?', '+escapeHtml(who.name):'')+'.</h2><p>Preparando seu portal.</p><div class="entry-loading-line"><i></i></div><button class="entry-skip" id="skipEntryIntro">Continuar</button></section>');
 const avatar=overlay.querySelector('[data-entry-avatar]');if(avatar)avatar.src=brand.avatarUrl;
 overlay.querySelector('#skipEntryIntro').focus();
 await new Promise(resolve=>{
  const finish=()=>{clearTimeout(entryTimer);entryIntroResolve=null;resolve()};entryIntroResolve=finish;
  overlay.querySelector('#skipEntryIntro').onclick=finish;
  entryTimer=setTimeout(finish,window.matchMedia('(prefers-reduced-motion: reduce)').matches?150:1150);
 });
 return entryState===state&&authUser?.id===state.userId;
}
function showClientEntryQuestion(client=clientById(currentClient),brand=portalBrand(client.id),preview=false){
 if(!preview&&questionDismissedToday()){closePortalEntry();return}
 let overlay=document.getElementById('portalEntryOverlay');
 if(!entryState)overlay=paintEntryOverlay(client,brand,preview);
 const who=welcomeIdentity(client,brand);
 const choices=[['editorial','calendar','Quero ver meu calendário editorial','Ideias e datas do seu planejamento.'],['contents','content','Quero ver meus conteúdos do mês','Artes, vídeos e materiais do seu mês.'],['approvals','check','Quero aprovar publicações','Veja o que está aguardando seu retorno.'],['tutorials','video','Quero ver os tutoriais','Uma ajuda rápida para usar o portal.']];
 setSafeHTML(overlay,'<section class="entry-question"><header><div><small>'+escapeHtml(client.name)+'</small><h2 id="portalEntryTitle">O que você procura no portal?</h2><p>Escolha um atalho para começar, '+escapeHtml(who.name||'vamos lá')+'.</p></div><button class="entry-close" id="closeEntryQuestion" aria-label="Fechar atalhos">×</button></header><div class="entry-shortcuts">'+choices.map(([key,icon,title,copy])=>'<button data-entry-destination="'+key+'"><span class="entry-shortcut-icon">'+ICONS[icon]+'</span><span><strong>'+title+'</strong><small>'+copy+'</small></span>'+ICONS.right+'</button>').join('')+'</div><div class="entry-question-footer"><button class="entry-dismiss-day" id="dismissEntryToday">Já conheço bem o portal. Não mostrar mais hoje :)</button><button class="entry-skip" id="skipEntryQuestion">Vou explorar por conta própria</button></div><p id="entryQuestionStatus" role="status"></p>'+(preview?'<div class="entry-preview-note">Prévia · nenhuma preferência do cliente será alterada.</div>':'')+'</section>');
 overlay.querySelector('#closeEntryQuestion').onclick=closePortalEntry;
 overlay.querySelector('#skipEntryQuestion').onclick=closePortalEntry;
 overlay.querySelectorAll('[data-entry-destination]').forEach(b=>b.onclick=()=>{
  const target=b.dataset.entryDestination;
  if(preview){closePortalEntry();toast('Este atalho abrirá '+({editorial:'o calendário editorial',contents:'os conteúdos do mês',approvals:'as publicações aguardando aprovação',tutorials:'os tutoriais'}[target])+' para o cliente.');return}
  closePortalEntry();
  if(document.getElementById('detailOverlay').classList.contains('open'))closeDetail();
  if(document.getElementById('modalWrap').classList.contains('open'))closeModal();
  activeFilter=target==='approvals'?'waiting':'all';
  if(target==='editorial'){route='editorial';editorialLayout='calendar';editorialMonth=currentMonthStart()}
  else if(target==='tutorials')route='tutorials';
  else{route='content';contentLayout='cards';contentMonthFilter=target==='contents'?currentMonthStart().slice(0,7):''}
  render();window.scrollTo({top:0,behavior:'smooth'});
 });
 overlay.querySelector('#dismissEntryToday').onclick=async()=>{
  if(preview){closePortalEntry();toast('Na conta do cliente, a pergunta ficará oculta até amanhã.');return}
  const button=overlay.querySelector('#dismissEntryToday');button.disabled=true;
  try{
   const today=portalToday();await persistPortalPreferences({welcome_dismissed_on:today});
   try{localStorage.setItem('climax-entry-dismiss:'+authUser.id,today)}catch(_){}
   closePortalEntry();toast('Tudo certo. Os atalhos voltam amanhã.');
  }catch(e){overlay.querySelector('#entryQuestionStatus').textContent='Não foi possível salvar. Tente novamente.';button.disabled=false}
 };
 overlay.querySelector('[data-entry-destination]').focus();
}
async function beginPortalClientEntry(){
 if(actualRole!=='client')return false;
 if(entryStartedUser===authUser.id)return false;
 entryStartedUser=authUser.id;
 const client=clientById(currentClient),brand=portalBrand(client.id);
 return showClientEntryIntro(client,brand);
}
async function previewClientEntry(client,brand){
 const valid=await showClientEntryIntro(client,brand,true);
 if(valid)showClientEntryQuestion(client,brand,true);
}
function brandColorField(label,id,value){
 return '<div class="brand-color-field"><label for="'+id+'">'+label+'</label><div><input type="color" id="'+id+'Picker" value="'+value+'" aria-label="'+label+'"><input type="text" id="'+id+'" value="'+value+'" maxlength="7" placeholder="#000000" autocomplete="off"></div></div>';
}
function openClientBranding(clientId){
 if(actualRole!=='admin'||role!=='admin')return;
 const client=clientById(clientId),saved=portalBrand(clientId),initial={...saved,enabled:clientBrandings[clientId]?.enabled??true};
 openModal('Personalizar portal · '+client.name,'<div class="branding-layout"><div class="branding-fields"><div class="field"><label class="visibility-option"><input id="clientBrandEnabled" type="checkbox" '+(initial.enabled?'checked':'')+'> Usar a paleta do cliente como padrão</label></div><p class="hint">O cliente poderá alternar entre a própria paleta, modo claro e modo escuro.</p><div class="brand-color-grid">'+brandColorField('Cor principal','brandPrimary',initial.primary_color)+brandColorField('Cor secundária','brandSecondary',initial.secondary_color)+brandColorField('Fundo do portal','brandBackground',initial.background_color)+'</div><p class="hint">As cores de texto e botões se ajustam para manter uma boa leitura.</p><div class="brand-photo-setting"><div class="brand-photo-preview" id="brandPhotoPreview">'+clientAvatarHTML(client)+'</div><div><label for="brandAvatarFile">Foto de perfil do cliente</label><input type="file" id="brandAvatarFile" accept="image/jpeg,image/png,image/webp"><small>JPG, PNG ou WebP · até 5 MB. Ajuste o recorte antes de salvar.</small><button class="mini-action" id="removeClientBrandPhoto">Remover foto</button></div></div><div class="avatar-crop-wrap" id="avatarCropWrap"><div class="avatar-crop-shell"><div class="avatar-crop-stage" id="avatarCropStage"><canvas id="avatarCropCanvas"></canvas><div class="avatar-crop-ring"></div></div><div class="avatar-crop-controls"><strong>Ajustar enquadramento</strong><p>Arraste a imagem e ajuste a aproximação.</p><input id="avatarCropZoom" type="range" value="1"></div></div></div><div class="form-grid"><div class="field"><label for="brandWelcomeName">Nome nas boas-vindas</label><input id="brandWelcomeName" maxlength="80" value="'+escapeHtml(initial.welcome_name)+'" placeholder="'+escapeHtml(client.contact||client.name)+'"></div><div class="field"><label for="brandGreeting">Saudação</label><select id="brandGreeting"><option value="neutral" '+(initial.welcome_greeting==='neutral'?'selected':'')+'>Boas-vindas</option><option value="feminine" '+(initial.welcome_greeting==='feminine'?'selected':'')+'>Seja bem-vinda</option><option value="masculine" '+(initial.welcome_greeting==='masculine'?'selected':'')+'>Seja bem-vindo</option></select></div></div></div><aside class="brand-live-preview" id="brandLivePreview"></aside></div>','<button class="btn btn-secondary" data-close-modal>Cancelar</button><button class="btn btn-secondary" id="previewClientWelcome">Testar boas-vindas</button><button class="btn" id="saveClientBranding">Salvar personalização</button>');
 document.getElementById('modalWrap').classList.add('branding-editing');
 let cropper=null,photoRemoved=false;
 const draft=()=>({...initial,enabled:document.getElementById('clientBrandEnabled').checked,primary_color:document.getElementById('brandPrimary').value.trim().toUpperCase(),secondary_color:document.getElementById('brandSecondary').value.trim().toUpperCase(),background_color:document.getElementById('brandBackground').value.trim().toUpperCase(),welcome_name:document.getElementById('brandWelcomeName').value.trim(),welcome_greeting:document.getElementById('brandGreeting').value,avatarUrl:photoRemoved?'':initial.avatarUrl});
 const validDraft=()=>{const b=draft();if(![b.primary_color,b.secondary_color,b.background_color].every(validBrandHex))throw new Error('Use cores no formato #RRGGBB, por exemplo #7C3AED.');return b};
 const updatePreview=()=>{
  const b=draft();if(![b.primary_color,b.secondary_color,b.background_color].every(validBrandHex))return;
  const preview=document.getElementById('brandLivePreview'),tokens=brandTokens(b.enabled?b:BRAND_DEFAULTS),who=welcomeIdentity(client,b);
  Object.entries(tokens.values).forEach(([k,v])=>preview.style.setProperty(k,v));
  setSafeHTML(preview,'<small>PRÉVIA DA PALETA</small><div class="brand-preview-identity"><span>'+clientAvatarHTML(client)+'</span><strong>'+escapeHtml(client.name)+'</strong></div><h3>'+escapeHtml(who.greeting)+(who.name?', '+escapeHtml(who.name):'')+'.</h3><p>Seu planejamento, seus conteúdos e todas as suas aprovações em um só lugar.</p><div class="brand-preview-card"><strong>Seu editorial do mês</strong><small>Ideias organizadas para o próximo ciclo.</small></div><span class="brand-preview-button">Ver meu planejamento '+ICONS.right+'</span><div class="brand-preview-swatches">'+[b.primary_color,b.secondary_color,b.background_color].map(color=>'<span style="background:'+color+'" title="'+color+'"></span>').join('')+'</div>');
 };
 ['brandPrimary','brandSecondary','brandBackground'].forEach(id=>{
  const text=document.getElementById(id),picker=document.getElementById(id+'Picker');
  text.oninput=()=>{if(validBrandHex(text.value))picker.value=text.value;updatePreview()};
  picker.oninput=()=>{text.value=picker.value.toUpperCase();updatePreview()};
 });
 ['brandWelcomeName','brandGreeting','clientBrandEnabled'].forEach(id=>document.getElementById(id).addEventListener('input',updatePreview));
 document.getElementById('brandAvatarFile').onchange=async()=>{
  const file=document.getElementById('brandAvatarFile').files?.[0];cropper=null;if(!file)return;
  if(!['image/jpeg','image/png','image/webp'].includes(file.type)||file.size>5*1024*1024){toast('Escolha uma imagem JPG, PNG ou WebP de até 5 MB.','error');document.getElementById('brandAvatarFile').value='';return}
  photoRemoved=false;document.getElementById('avatarCropWrap').classList.add('open');
  try{cropper=await createAvatarCropper(file)}catch(e){document.getElementById('avatarCropWrap').classList.remove('open');toast(formatError(e,'Não foi possível abrir a imagem.'),'error')}
 };
 document.getElementById('removeClientBrandPhoto').onclick=()=>{photoRemoved=true;cropper=null;document.getElementById('brandAvatarFile').value='';document.getElementById('avatarCropWrap').classList.remove('open');setSafeHTML('#brandPhotoPreview',escapeHtml(client.init));updatePreview()};
 document.getElementById('previewClientWelcome').onclick=async()=>{
  try{const b=validDraft();let url='';if(cropper){url=URL.createObjectURL(await cropper.toBlob());b.avatarUrl=url}await previewClientEntry(client,b);if(url)setTimeout(()=>URL.revokeObjectURL(url),60000)}
  catch(e){toast(formatError(e,'Confira a paleta.'),'error')}
 };
 const save=document.getElementById('saveClientBranding');
 save.onclick=()=>runBusy(save,'Salvando…',async()=>{
  const b=validDraft();let newPath=null,oldPath=saved.avatar_path||null,linked=false;
  if(document.getElementById('brandAvatarFile').files?.length&&!cropper)throw new Error('Aguarde a imagem abrir para ajustar o recorte.');
  try{
   let avatarPath=photoRemoved?null:oldPath;
   if(cropper){const blob=await cropper.toBlob();newPath=clientId+'/avatar-'+crypto.randomUUID()+'.jpg';const upload=await db.storage.from('client-branding').upload(newPath,blob,{contentType:'image/jpeg',upsert:false});if(upload.error)throw upload.error;avatarPath=newPath}
   const payload={client_id:clientId,enabled:b.enabled,primary_color:b.primary_color,secondary_color:b.secondary_color,background_color:b.background_color,welcome_name:b.welcome_name,welcome_greeting:b.welcome_greeting,avatar_path:avatarPath,updated_at:new Date().toISOString()};
   const result=await db.from('client_portal_branding').upsert(payload,{onConflict:'client_id'});if(result.error)throw result.error;linked=true;
   if(oldPath&&oldPath!==avatarPath){const removed=await db.storage.from('client-branding').remove([oldPath]);if(removed.error)console.warn('Foto anterior poderá ser removida em uma próxima manutenção.')}
   await loadPortalPersonalization();closeModal();render();toast('Personalização do portal salva.');
  }catch(e){if(newPath&&!linked){try{await db.storage.from('client-branding').remove([newPath])}catch(_){}}if(linked){closeModal();toast('Personalização salva. Atualize a página para carregar a prévia.');return}throw e}
 }).catch(e=>toast(formatError(e,'Não foi possível salvar a personalização.'),'error'));
 updatePreview();
}
/* Resolve the supplied vector identity from the current surface and appearance. */
function syncPortalLogos(){
 const custom=backendReady&&role==='client'&&portalThemeMode==='brand'&&portalBrand(currentClient).enabled;
 const variant=currentTheme==='light'?'black':custom?'white':'green';
 const full='./assets/brand/'+(variant==='green'?'climax-green.svg':'portal-'+variant+'.svg');
 const mark='./assets/brand/monogram-'+variant+'.svg';
 document.querySelectorAll('.brand-logo,.mobile-logo,.auth-showcase-logo,.auth-mobile-logo').forEach(img=>{if(img.getAttribute('src')!==full)img.src=full;img.alt='Clímax · Portal do cliente'});
 document.querySelectorAll('.brand-monogram,.boot-loader-icon').forEach(img=>{if(img.getAttribute('src')!==mark)img.src=mark});
}
