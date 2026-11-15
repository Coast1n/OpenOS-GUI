const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');
const files=[];
function walk(dir){for(const e of fs.readdirSync(path.join(root,dir),{withFileTypes:true})){const p=dir+'/'+e.name;if(e.isDirectory()){if(p==='tests/results')continue;walk(p);}else files.push(p);}}
for(const dir of ['lib','editor','examples','tools','docs','dist','tests'])walk(dir);
for(const name of fs.readdirSync(path.join(root,'tests/results')).filter(n=>/^STAGE[0-9]+\.md$/.test(n)))files.push('tests/results/'+name);
files.push('package.json','package-lock.json','installer.lua');
const entries=files.sort().map(file=>{let content=fs.readFileSync(path.join(root,file),'utf8');if(file.startsWith('tests/results/'))content=content.replace(/\[([^\]]+)\]\(stage[0-9]+-run-[^)]*\)/g,'$1（原始记录保留在开发工作区）');return {path:file,mode:'100644',type:'blob',content};});
entries.push({path:'README.md',mode:'100644',type:'blob',content:fs.readFileSync(path.join(root,'PUBLISH-README.md'),'utf8')});
entries.push({path:'.gitignore',mode:'100644',type:'blob',content:'node_modules/\n.publish/\ntests/results/*/\n'});
const bad=entries.filter(e=>/[A-Z]:\\(?:Users|E_UserData)\\/i.test(e.content)||/[a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12}/i.test(e.content));if(bad.length)throw Error('Private local details in '+bad.map(e=>e.path).join(','));
fs.mkdirSync(path.join(root,'.publish'),{recursive:true});fs.writeFileSync(path.join(root,'.publish/files.json'),JSON.stringify(entries));console.log(JSON.stringify({files:entries.length,bytes:entries.reduce((n,e)=>n+Buffer.byteLength(e.content),0)}));
