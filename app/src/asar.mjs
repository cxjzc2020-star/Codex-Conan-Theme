import fs from 'node:fs/promises';

// Read only the bounded startup HTML from the installed archive. Never patch it.
export async function readNativeStartup(archive) {
  const file=await fs.open(archive,'r');
  try {
    const prefix=Buffer.alloc(16);await file.read(prefix,0,16,0);
    const length=prefix.readUInt32LE(12);
    if(length<2||length>30*1024*1024)throw new Error('Unsupported application archive header');
    const bytes=Buffer.alloc(length);await file.read(bytes,0,length,16);
    const tree=JSON.parse(bytes.toString('utf8'));
    const entry=tree.files?.webview?.files?.['index.html'];
    if(!entry||entry.unpacked||entry.size>128*1024||!/^\d+$/.test(entry.offset))throw new Error('Unsupported native startup entry');
    const htmlBytes=Buffer.alloc(entry.size);
    await file.read(htmlBytes,0,entry.size,8+prefix.readUInt32LE(4)+Number(entry.offset));
    const html=htmlBytes.toString('utf8');
    const start=html.search(/<div\s+class="startup-loader"[\s>]/);
    if(start<0||!html.includes('startup-openai-blossom-shimmer'))throw new Error('Native startup structure changed');
    const tags=/<\/?div\b[^>]*>/g;tags.lastIndex=start;
    let depth=0,end=-1;
    for(let match;(match=tags.exec(html));){
      depth+=match[0].startsWith('</')?-1:1;
      if(depth===0){end=tags.lastIndex;break;}
    }
    const markup=html.slice(start,end);
    if(end<0||!markup.includes('startup-loader__overlay')||/<(?:script|iframe|img|object)\b|\bon\w+\s*=/i.test(markup))throw new Error('Unsupported native loader markup');
    return {markup,animation:'startup-openai-blossom-shimmer'};
  }finally{await file.close();}
}
