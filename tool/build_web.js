// Compila l'app web e la prepara per Firebase Hosting, nella sottocartella
// /app dello stesso sito delle pagine legali.
//
//   node tool/build_web.js
//   (con notifiche: WEB_PUSH_VAPID_KEY=... node tool/build_web.js)
//
// Poi: firebase deploy --only hosting
//
// Risultato (non versionato, vedi .gitignore):
//   hosting/app/                     → l'app Flutter
//   hosting/firebase-messaging-sw.js → service worker delle notifiche, che
//                                      Firebase cerca nella radice del sito
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const out = path.join(root, 'hosting', 'app');

const vapid = process.env.WEB_PUSH_VAPID_KEY ?? '';
const defines = vapid ? ` --dart-define=WEB_PUSH_VAPID_KEY=${vapid}` : '';
if (!vapid) console.log('WEB_PUSH_VAPID_KEY non impostata: notifiche web spente.');

execSync(`flutter build web --release --base-href /app/${defines}`, {
  cwd: root,
  stdio: 'inherit',
  shell: true,
});

fs.rmSync(out, { recursive: true, force: true });
fs.cpSync(path.join(root, 'build', 'web'), out, { recursive: true });
fs.copyFileSync(
  path.join(root, 'web', 'firebase-messaging-sw.js'),
  path.join(root, 'hosting', 'firebase-messaging-sw.js'),
);
console.log('Pronta in hosting/app. Pubblica con: firebase deploy --only hosting');
