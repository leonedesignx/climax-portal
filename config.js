window.CLIMAX_CONFIG = {
  SUPABASE_URL: 'https://iruuxauxsthosgcavtsj.supabase.co',
  SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_kI6KYWExB_4mRVwjq1AAaw_dvfypDMt',
  SUPABASE_ANON_KEY: '',
  DEMO_MODE: false
};

window.PORTAL_BRAND_LOGO = './portal-logo-new.svg';
(function applyPortalBrand(){
  const logo=window.PORTAL_BRAND_LOGO;
  const apply=()=>{
    document.querySelectorAll('.brand-logo,.mobile-logo,.auth-showcase-logo,.auth-mobile-logo,.boot-loader-icon').forEach(img=>{ if(img && img.src!==new URL(logo,location.href).href) img.src=logo; });
    let icon=document.querySelector('link[rel~="icon"]');
    if(!icon){ icon=document.createElement('link'); icon.rel='icon'; document.head.appendChild(icon); }
    icon.href=logo;
  };
  apply();
  document.addEventListener('DOMContentLoaded',apply,{once:true});
  const observer=new MutationObserver(apply);
  observer.observe(document.documentElement,{subtree:true,childList:true});
  window.addEventListener('load',()=>setTimeout(()=>{apply();observer.disconnect();},1600),{once:true});
})();
