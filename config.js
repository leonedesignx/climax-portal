window.CLIMAX_CONFIG = {
  SUPABASE_URL: 'https://iruuxauxsthosgcavtsj.supabase.co',
  SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_kI6KYWExB_4mRVwjq1AAaw_dvfypDMt',
  SUPABASE_ANON_KEY: '',
  DEMO_MODE: false
};

// Choose the logo before authentication starts; never reset it after page load.
window.PORTAL_BRAND_LOGO = './portal-logo-new.svg';
window.syncPortalBrandImages = function(theme){
  const light=theme==='light';
  const logo=light?'./assets/brand/portal-light.svg':window.PORTAL_BRAND_LOGO;
  const mark='./assets/brand/monogram-'+(light?'black':'green')+'.svg';
  document.querySelectorAll('.brand-logo,.mobile-logo,.auth-showcase-logo,.auth-mobile-logo').forEach(img=>{
    if(img.getAttribute('src')!==logo)img.src=logo;
    img.alt='Clímax · Portal do cliente';
  });
  document.querySelectorAll('.brand-monogram,.boot-loader-icon').forEach(img=>{
    if(img.getAttribute('src')!==mark)img.src=mark;
  });
};
window.syncPortalBrandImages(document.documentElement.dataset.theme);
