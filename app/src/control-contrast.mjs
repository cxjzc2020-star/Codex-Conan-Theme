import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {Cdp,debuggerUrl,getJson} from './cdp.mjs';

// This stylesheet is project-owned compatibility CSS, separate from upstream Safe CSS.
export function installControlContrast(css){
  if(location.protocol!=='app:'||new URLSearchParams(location.search).get('initialRoute')?.startsWith('/avatar-overlay'))return false;
  const previous=window.__CONAN_CONTROL_CONTRAST__;
  if(previous?.version===3&&previous.css===css)return true;
  previous?.cleanup();
  const state={version:3,css,cleanup:null};
  try{
    const sheet=new CSSStyleSheet();sheet.replaceSync(css);
    document.adoptedStyleSheets=[...document.adoptedStyleSheets,sheet];
    state.cleanup=()=>{document.adoptedStyleSheets=document.adoptedStyleSheets.filter(item=>item!==sheet);delete window.__CONAN_CONTROL_CONTRAST__;};
  }catch{
    const element=document.createElement('style');element.id='conan-control-contrast';element.textContent=css;
    (document.head??document.documentElement).appendChild(element);
    state.cleanup=()=>{element.remove();delete window.__CONAN_CONTROL_CONTRAST__;};
  }
  window.__CONAN_CONTROL_CONTRAST__=state;
  return true;
}

// Chrome owns early-document registrations per CDP session. Keep those sessions
// open for reloads and discover new windows, matching the wallpaper watcher's life.
export async function watchControlContrast({port,browserId,stateFile,pauseFile,signal}){
  const version=await getJson(port,'/json/version');
  const anchor=await new Cdp(debuggerUrl(version.webSocketDebuggerUrl,port,'browser',browserId)).open();
  const css=await fs.readFile(new URL('./control-contrast.css',import.meta.url),'utf8');
  const source=`(${installControlContrast.toString()})(${JSON.stringify(css)})`;
  const pages=new Map();
  const cleanPage=async item=>{
    if(item.identifier)await item.page.send('Page.removeScriptToEvaluateOnNewDocument',{identifier:item.identifier}).catch(()=>{});
    item.identifier=null;
    await item.page.evaluate('window.__CONAN_CONTROL_CONTRAST__?.cleanup();true').catch(()=>{});
  };
  try{
    while(!anchor.closed&&!signal?.aborted){
      const paused=await fs.access(pauseFile).then(()=>true,()=>false);
      const targets=(await getJson(port,'/json/list')).filter(t=>t.type==='page'&&t.url?.startsWith('app://')&&!t.url.includes('avatar-overlay'));
      const ids=new Set(targets.map(t=>t.id));
      for(const [id,item] of pages){if(!ids.has(id)||item.page.closed){item.page.close();pages.delete(id);}}
      let transientError=null;
      for(const target of targets){
        if(anchor.closed||signal?.aborted)break;
        let item=pages.get(target.id);
        try{
        if(!item&&!paused){
          item={page:await new Cdp(debuggerUrl(target.webSocketDebuggerUrl,port,'page',target.id)).open(),identifier:null};
          pages.set(target.id,item);
        }
        if(!item)continue;
        if(paused){if(item.identifier)await cleanPage(item);continue;}
        if(!item.identifier)item.identifier=(await item.page.send('Page.addScriptToEvaluateOnNewDocument',{source})).identifier;
        await item.page.evaluate(source);
        }catch(error){
          // Reloads can destroy a context between enumeration and evaluation.
          // Reconnect that surface next cycle without losing the other windows.
          item?.page.close();pages.delete(target.id);transientError=error.message;
        }
      }
      await fs.mkdir(path.dirname(stateFile),{recursive:true});
      const temporary=stateFile+'.tmp-'+process.pid;
      await fs.writeFile(temporary,JSON.stringify({browserId,pid:process.pid,paused,pages:pages.size,error:transientError}));
      await fs.rename(temporary,stateFile);
      await new Promise(resolve=>setTimeout(resolve,700));
    }
  }catch(error){if(!anchor.closed)throw error;}
  finally{
    for(const item of pages.values()){await cleanPage(item);item.page.close();}
    anchor.close();
  }
  return {pass:true,stopped:true};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  try{
    const [mode,port,browserId,stateFile,pauseFile]=process.argv.slice(2);
    if(mode!=='watch'||!path.isAbsolute(stateFile??'')||!path.isAbsolute(pauseFile??''))throw new Error('Expected watch, port, browser identity, absolute state and pause paths');
    console.log(JSON.stringify(await watchControlContrast({port:Number(port),browserId,stateFile,pauseFile})));
  }catch(error){console.error(error.message);process.exitCode=1;}
}
