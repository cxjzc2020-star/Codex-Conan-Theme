import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {readNativeStartup} from './asar.mjs';
import {Cdp,debuggerUrl,getJson} from './cdp.mjs';
import {installStartup} from './startup-renderer.mjs';

export async function attachStartup({port,browserId,archive,introPath,muted=true,maxSeconds=6,enabled=true}){
  const native=await readNativeStartup(archive);
  const ext=path.extname(introPath).toLowerCase();
  if(!['.mp4','.gif'].includes(ext))throw new Error('Startup media must be MP4 or GIF');
  const stat=await fs.stat(introPath);if(!stat.isFile()||stat.size<1||stat.size>150*1024*1024)throw new Error('Invalid startup media size');
  const version=await getJson(port,'/json/version');
  const anchor=await new Cdp(debuggerUrl(version.webSocketDebuggerUrl,port,'browser',browserId)).open();
  try{
    const deadline=Date.now()+10000;
    do{
    if(anchor.closed)throw new Error('Original browser closed');
    const targets=(await getJson(port,'/json/list')).filter(t=>t.type==='page'&&t.url?.startsWith('app://'));
    for(const target of targets){
      const page=await new Cdp(debuggerUrl(target.webSocketDebuggerUrl,port,'page',target.id)).open();
      try{
        if(anchor.closed)throw new Error('Original browser closed');
        const result=await page.evaluate(`(${installStartup.toString()})(${JSON.stringify({nativeMarkup:native.markup,muted,maxSeconds,enabled})})`);
        if(!result?.installed)continue;
        if(result.reused)return result;
        await page.evaluate('window.__CONAN_STARTUP_CHUNKS__=[];true');
        const file=await fs.open(introPath,'r');
        try{
          const chunk=Buffer.alloc(512*1024);
          let offset=0;
          while(offset<stat.size){
            const {bytesRead}=await file.read(chunk,0,Math.min(chunk.length,stat.size-offset),offset);
            if(!bytesRead)throw new Error('Startup media changed while reading');
            await page.evaluate(`window.__CONAN_STARTUP_CHUNKS__.push(${JSON.stringify(chunk.subarray(0,bytesRead).toString('base64'))});true`);offset+=bytesRead;
          }
        }finally{await file.close();}
        await page.evaluate(`window.__CONAN_STARTUP__.acceptMedia(window.__CONAN_STARTUP_CHUNKS__,${JSON.stringify(ext==='.gif'?'image/gif':'video/mp4')});delete window.__CONAN_STARTUP_CHUNKS__;true`);
        const surface=await page.evaluate(`(async()=>{
          const deadline=Date.now()+4000;
          while(Date.now()<deadline){
            const state=window.__CONAN_STARTUP__,stage=document.getElementById('conan-startup-stage');
            if(state?.phase==='done'&&state.themeReady)return {stageReady:true,mainReady:true};
            if(stage&&state?.entered&&Number(getComputedStyle(stage).opacity)>=.999&&getComputedStyle(stage).backgroundColor==='rgb(6, 13, 24)'){
              const media=stage.querySelector('video,img');
              if(state?.videoEnded||(media?.tagName==='VIDEO'&&media.readyState>=2)||(media?.tagName==='IMG'&&media.complete&&media.naturalWidth>0))return {stageReady:true,mediaReady:true};
            }
            await new Promise(resolve=>setTimeout(resolve,25));
          }
          const stage=document.getElementById('conan-startup-stage'),state=window.__CONAN_STARTUP__;
          throw new Error('Startup surface did not become ready: '+JSON.stringify({phase:state?.phase,entered:state?.entered,error:state?.error,background:stage?getComputedStyle(stage).backgroundColor:null,mediaReady:stage?.querySelector('video')?.readyState}));
        })()`);
        return {...result,...surface};
      }catch(error){
        await page.evaluate('window.__CONAN_STARTUP__?.abort?.();delete window.__CONAN_STARTUP_CHUNKS__;true').catch(()=>{});
        throw error;
      }finally{page.close();}
    }
    await new Promise(resolve=>setTimeout(resolve,200));
    }while(Date.now()<deadline);
    throw new Error('No compatible native startup surface');
  }finally{anchor.close();}
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  try{
    const [port,browserId,archive,settingsPath]=process.argv.slice(2);
    const settings=JSON.parse((await fs.readFile(settingsPath,'utf8')).replace(/^\uFEFF/,''));
    console.log(JSON.stringify(await attachStartup({port:Number(port),browserId,archive,introPath:settings.introPath,muted:settings.muted,maxSeconds:settings.maxSeconds,enabled:settings.introEnabled})));
  }catch(error){console.error(error.message);process.exitCode=1;}
}
