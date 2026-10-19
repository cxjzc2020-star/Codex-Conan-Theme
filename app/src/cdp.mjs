export function debuggerUrl(value,port,kind,id){
  const url=new URL(value);
  if(url.protocol!=='ws:'||!['127.0.0.1','localhost','[::1]'].includes(url.hostname)||Number(url.port)!==port||url.username||url.password||url.search||url.hash||url.pathname!==`/devtools/${kind}/${id}`||!/^[A-Za-z0-9._-]{1,200}$/.test(id))throw new Error('Rejected debugger endpoint');
  return url.href;
}
export async function getJson(port,route){
  if(!Number.isInteger(port)||port<1024||port>65535)throw new Error('Invalid port');
  const response=await fetch(`http://127.0.0.1:${port}${route}`,{redirect:'error',signal:AbortSignal.timeout(3000)});
  if(!response.ok)throw new Error('CDP request failed');
  const text=await response.text();if(text.length>2*1024*1024)throw new Error('CDP response too large');
  return JSON.parse(text);
}
export class Cdp {
  constructor(url){this.ws=new WebSocket(url);this.pending=new Map();this.sequence=0;this.closed=false;}
  async open(){
    await new Promise((resolve,reject)=>{
      const timeout=setTimeout(()=>{this.close();reject(new Error('CDP open timeout'));},4000);
      this.ws.addEventListener('open',()=>{clearTimeout(timeout);resolve();},{once:true});
      this.ws.addEventListener('error',()=>{clearTimeout(timeout);reject(new Error('CDP socket failed'));},{once:true});
    });
    this.ws.addEventListener('message',event=>{
      let m;try{m=JSON.parse(String(event.data));}catch{this.close();return;}
      const item=this.pending.get(m.id);if(!item)return;
      this.pending.delete(m.id);clearTimeout(item.timeout);
      if(m.error)item.reject(new Error(m.error.message));else item.resolve(m.result);
    });
    this.ws.addEventListener('close',()=>this.close());
    return this;
  }
  send(method,params={}){
    if(this.closed)return Promise.reject(new Error('CDP closed'));
    return new Promise((resolve,reject)=>{
      const id=++this.sequence;
      const timeout=setTimeout(()=>{this.pending.delete(id);reject(new Error(`CDP timeout: ${method}`));},15000);
      this.pending.set(id,{resolve,reject,timeout});this.ws.send(JSON.stringify({id,method,params}));
    });
  }
  async evaluate(expression){
    const r=await this.send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});
    if(r.exceptionDetails)throw new Error(r.exceptionDetails.exception?.description||r.exceptionDetails.text||'Renderer evaluation failed');
    return r.result?.value;
  }
  close(){
    if(this.closed)return;this.closed=true;
    for(const item of this.pending.values()){clearTimeout(item.timeout);item.reject(new Error('CDP closed'));}
    this.pending.clear();try{this.ws.close();}catch{}
  }
}
