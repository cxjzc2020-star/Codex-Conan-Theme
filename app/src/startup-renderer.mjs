// Runs inside the real Codex page. Uses the installed loader markup and its CSS.
export function installStartup(options){
  if(location.protocol!=='app:')return {installed:false,reason:'not-app'};
  if(window.__CONAN_STARTUP__)return {installed:true,reused:true};
  const root=document.getElementById(options.rootId??'root');
  if(!root||new URLSearchParams(location.search).get('initialRoute')?.startsWith('/avatar-overlay'))return {installed:false,reason:'not-main'};
  const original=root.querySelector('.startup-loader');
  const holder=document.createElement('div');holder.innerHTML=options.nativeMarkup;
  const loader=original?.cloneNode(true)??holder.firstElementChild;
  if(!loader?.querySelector('.startup-loader__logo')||!loader.querySelector('.startup-loader__overlay'))return {installed:false,reason:'no-native-logo'};
  const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
  const state={phase:'preparing',nativeReused:true,originalNode:false,nativeSource:original?'cloned-node':'installed-markup',reduced,videoEnded:false,error:null,entered:false,entryDurationMs:350};
  window.__CONAN_STARTUP__=state;
  const css=document.createElement('style');css.id='conan-startup-style';
  css.textContent=`#conan-startup-stage{position:fixed;inset:0;z-index:2147483646;background:#060d18;opacity:0;transition:opacity 350ms ease;isolation:isolate}
    #conan-startup-stage .startup-loader{position:absolute;inset:0;width:100%;height:100%;background:#060d18;--startup-logo-shimmer-base:rgba(255,255,255,.68)}
    #conan-startup-stage .startup-loader__logo{z-index:2;transition:opacity 300ms ease}
    #conan-startup-stage video,#conan-startup-stage img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;z-index:3;opacity:1;transition:opacity 500ms ease}
    #conan-startup-stage[data-phase=loading] video,#conan-startup-stage[data-phase=loading] img{opacity:0;pointer-events:none}
    #conan-startup-stage[data-phase=playing] .startup-loader__logo{visibility:hidden}
    @media(prefers-reduced-motion:reduce){#conan-startup-stage,#conan-startup-stage *{transition:none!important}}`;
  document.head.appendChild(css);
  const stage=document.createElement('div');stage.id='conan-startup-stage';stage.dataset.phase='playing';stage.setAttribute('aria-label','正在启动 Codex');
  // Leave the app's original bootstrap tree intact during the crossfade.
  // Reuse its exact definition in this same renderer, without another window.
  stage.appendChild(loader);document.body.appendChild(stage);
  const controller={timer:null,observer:null,interval:null,finishTimer:null,video:null,urls:[]};
  let released=false,loadingStarted=0,readySince=0;
  const showStage=()=>{
    if(state.entered||released)return;
    stage.getBoundingClientRect(); // Commit transparent initial style before fading.
    state.entered=true;stage.style.opacity='1';
  };
  const mounted=()=>!!root.querySelector('main[data-app-shell-main-surface],main[class*="_MainContentSurface_"],.main-surface,input[type="email"],input[type="password"]')||[...root.querySelectorAll('button,a')].some(x=>/^(log ?in|sign ?in|登录|登入|continue with|使用.*登录)/i.test(x.textContent.trim()));
  const revealWallpaper=()=>{
    if(reduced)return;
    const media=document.getElementById('codex-dream-skin-media');
    media?.animate([{filter:'blur(16px) brightness(.82)'},{filter:'blur(0px) brightness(1)'}],{duration:800,easing:'ease-out'});
    // Wide static wallpapers are painted on body, not on main's pseudo-element.
    // Temporarily give that background its own layer so no text is filtered.
    const body=document.body,paint=getComputedStyle(body);
    if(!media&&paint.backgroundImage.includes('url(')){
      const layer=document.createElement('div');layer.id='conan-wallpaper-focus-backdrop';
      layer.style.cssText='position:fixed;inset:0;z-index:-1;pointer-events:none';
      layer.style.backgroundImage=paint.backgroundImage;layer.style.backgroundPosition=paint.backgroundPosition;
      layer.style.backgroundSize=paint.backgroundSize;layer.style.backgroundRepeat=paint.backgroundRepeat;
      const saved=['background-image','isolation'].map(key=>[key,body.style.getPropertyValue(key),body.style.getPropertyPriority(key)]);
      body.style.setProperty('background-image','none','important');body.style.setProperty('isolation','isolate','important');
      body.prepend(layer);state.backgroundReveal='body-image';
      layer.animate([{filter:'blur(16px) brightness(.82)'},{filter:'blur(0px) brightness(1)'}],{duration:800,easing:'ease-out'});
      setTimeout(()=>{layer.remove();for(const [key,value,priority] of saved){if(body.style.getPropertyValue(key)===(key==='isolation'?'isolate':'none')){if(value)body.style.setProperty(key,value,priority);else body.style.removeProperty(key);}}},850);
    }
    // Only background pseudo-elements are filtered. Text and controls stay sharp.
    const reveal=document.createElement('style');reveal.id='conan-wallpaper-reveal';
    reveal.textContent=`@keyframes conan-background-focus{from{filter:blur(16px) brightness(.82)}to{filter:blur(0px) brightness(1)}}
    html[data-dream-skin=active] main[data-app-shell-main-surface]::before,
    html[data-dream-skin=active] main[class*="_MainContentSurface_"]::before,
    html[data-dream-skin=active] .main-surface::before{animation:conan-background-focus 800ms ease-out both!important}`;
    document.head.appendChild(reveal);setTimeout(()=>reveal.remove(),850);
  };
  const cleanup=()=>{
    clearTimeout(controller.timer);clearTimeout(controller.finishTimer);clearInterval(controller.interval);controller.observer?.disconnect();
    document.removeEventListener('keydown',onKey,true);controller.video?.pause();
    stage.remove();css.remove();controller.urls.forEach(url=>URL.revokeObjectURL(url));state.phase='done';
  };
  const release=()=>{
    if(released)return;released=true;state.phase='revealing';
    revealWallpaper();stage.style.opacity='0';controller.finishTimer=setTimeout(cleanup,reduced?0:360);
  };
  const check=()=>{
    if(state.phase!=='loading'||released)return;
    if(!reduced&&performance.now()-loadingStarted<500)return;
    if(mounted()){
      if(!readySince)readySince=performance.now();
      const themed=document.documentElement.getAttribute('data-dream-skin')==='active';
      // Do not block an authentication page or an unknown UI behind an overlay.
      if(themed||performance.now()-readySince>5000){state.themeReady=themed;release();}
    }
  };
  const endVideo=()=>{
    if(state.videoEnded)return;state.videoEnded=true;
    showStage();
    controller.video?.pause();stage.dataset.phase='loading';state.phase='loading';loadingStarted=performance.now();
    setTimeout(check,reduced?0:520);
  };
  const onKey=event=>{if(event.key==='Escape'){event.preventDefault();if(!state.videoEnded)endVideo();else state.abort();}};
  document.addEventListener('keydown',onKey,true);
  controller.observer=new MutationObserver(check);controller.observer.observe(root,{childList:true,subtree:true});
  controller.observer.observe(document.documentElement,{attributes:true,attributeFilter:['data-dream-skin']});
  controller.interval=setInterval(check,250);
  state.abort=cleanup;
  state.acceptMedia=(chunks,mime)=>{
    const arrays=chunks.map(chunk=>Uint8Array.from(atob(chunk),c=>c.charCodeAt(0)));
    const url=URL.createObjectURL(new Blob(arrays,{type:mime}));controller.urls.push(url);
    if(mime==='image/gif'){
      const image=document.createElement('img');image.addEventListener('load',showStage,{once:true});image.addEventListener('error',()=>{state.error='image-decode';endVideo();},{once:true});image.src=url;stage.appendChild(image);state.phase='playing';
    }else{
      const video=document.createElement('video');controller.video=video;video.muted=options.muted;video.playsInline=true;video.preload='auto';
      video.src=url;video.addEventListener('ended',endVideo,{once:true});
      video.addEventListener('loadeddata',showStage,{once:true});
      video.addEventListener('error',()=>{state.error='video-decode';endVideo();},{once:true});stage.appendChild(video);
      state.phase='playing';video.play().catch(()=>{state.error='video-play';endVideo();});
    }
    controller.timer=setTimeout(endVideo,options.maxSeconds*1000);
    // Start the in-window crossfade once transfer is complete. An entirely
    // transparent video can be deferred by Chromium until it becomes visible.
    showStage();
    if(reduced||!options.enabled)endVideo();
    return true;
  };
  return {installed:true,nativeReused:true,originalNode:false,nativeSource:state.nativeSource,animation:getComputedStyle(loader.querySelector('.startup-loader__overlay')).animationName};
}
