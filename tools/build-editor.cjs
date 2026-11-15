require('./build.cjs');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { bundleString, unbundleString } = require('luabundle');
const lua = require('moonsharp-luaparse');
const root = path.resolve(__dirname, '..');
const external = ['ocgui', 'unicode', 'shell', 'event', 'filesystem'];
const bundled = bundleString('return function(...)\n' + fs.readFileSync(path.join(root, 'editor/edit.lua'), 'utf8') + '\nend', {luaVersion: '5.3', isolate: false,
  rootModuleName: '__editor', paths: [path.join(root, 'lib/?.lua')], ignoredModuleNames: external, resolveModule(name) {
    if (external.includes(name)) return null;
    const file = path.join(root, 'lib', name.replaceAll('.', '/') + '.lua');
    return fs.existsSync(file) ? file : null;
  }});
const content = '-- OpenOS GUI editor; generated from editor/ and lib/ocedit/.\n'
  + fs.readFileSync(require.resolve('luabundle/LICENSE'), 'utf8').split(/\r?\n/).map(s => '-- ' + s).join('\n') + '\n'
  + 'local __ocedit_main = (function()\n' + bundled + '\nend)()\nreturn __ocedit_main(...)\n';
lua.parse(content, {luaVersion: '5.3'});
const modules = Object.keys(unbundleString(bundled).modules).sort();
if (modules.join(',') !== '__editor,ocedit.buffer,ocedit.storage') throw Error('Unexpected editor modules');
fs.writeFileSync(path.join(root, 'dist/edit.lua'), content);
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
fs.writeFileSync(path.join(root, 'dist/editor-manifest.json'), JSON.stringify({
  version: '0.1.0-dev', file: 'edit.lua', sha256: sha(content), modules, external,
  guiSha256: sha(fs.readFileSync(path.join(root, 'dist/ocgui.lua'))),
  verification: 'Lua 5.3 syntax and module inventory checked; OpenOS validation pending.'
}, null, 2) + '\n');
for (const file of ['editor/install.lua', 'editor/preview.lua', 'tests/run-editor.lua']) {
  if (fs.existsSync(path.join(root, file))) lua.parse(fs.readFileSync(path.join(root, file), 'utf8'), {luaVersion:'5.3'});
}
console.log(`edit.lua: ${Buffer.byteLength(content)} bytes; external single-file ocgui; SHA-256 ${sha(content)}`);
