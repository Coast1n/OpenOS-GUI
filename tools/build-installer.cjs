const fs = require('node:fs');
const path = require('node:path');
const lua = require('moonsharp-luaparse');
const root = path.resolve(__dirname, '..');
function adler(data) { let a=1,b=0; for (const byte of data) {a=(a+byte)%65521;b=(b+a)%65521;} return b*65536+a; }
const entries = ['ocgui.lua','edit.lua'].map(name=>{const data=fs.readFileSync(path.join(root,'dist',name));return {name,bytes:data.length,adler:adler(data)};});
let offline=fs.readFileSync(path.join(root,'editor/install.lua'),'utf8');
const old='local root = shell.resolve((...) or "/home/OpenOS-GUI")';
if(!offline.includes(old))throw Error('Offline installer changed');
offline=offline.replace(old,'local root = stage');
const template=fs.readFileSync(path.join(root,'tools/installer-template.lua'),'utf8');
const source=template.replace('@@PAYLOADS@@',entries.map(e=>'{name="'+e.name+'", bytes='+e.bytes+', checksum='+e.adler+'}').join(',\n  ')).replace('@@INSTALL@@',offline);
lua.parse(source,{luaVersion:'5.3'});
if (source.includes('"/tmp/ocgui-install"') || !source.includes('"/home/.ocgui-install"')) {
  throw Error('Payload staging must not use the 64 KiB OpenComputers tmpfs');
}
fs.writeFileSync(path.join(root,'installer.lua'),source);
console.log('Generated installer.lua: Coast1n/OpenOS-GUI; payload sizes and Adler-32 checked before installation.');
