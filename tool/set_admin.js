// Gestione degli admin di Trashpotting (custom claim `admin: true`).
// Usa le credenziali della Firebase CLI (`firebase login`) di un account
// con accesso al progetto: niente service account, niente costi.
//
//   node tool/set_admin.js list
//   node tool/set_admin.js add <email>
//   node tool/set_admin.js remove <email>
//
// Dopo l'aggiunta, l'utente vede i poteri admin al prossimo avvio dell'app
// (che rinnova il token) o rifacendo il login.
const path = require('path');
const os = require('os');
const fs = require('fs');

const PROJECT = 'trashpotting-app';
const API = `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT}`;

async function accessToken() {
  const ftLib = path.join(
    process.env.APPDATA ?? path.join(os.homedir(), '.npm-global'),
    'npm/node_modules/firebase-tools/lib/auth.js',
  );
  const auth = require(ftLib);
  const store = JSON.parse(
    fs.readFileSync(
      path.join(os.homedir(), '.config/configstore/firebase-tools.json'),
      'utf8',
    ),
  );
  const refresh = store.tokens?.refresh_token;
  if (!refresh) throw new Error('Esegui prima: firebase login');
  const t = await auth.getAccessToken(refresh, [
    'https://www.googleapis.com/auth/cloud-platform',
  ]);
  return t.access_token;
}

async function call(token, endpoint, body) {
  const res = await fetch(`${API}/${endpoint}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const json = await res.json();
  if (!res.ok) throw new Error(`${endpoint}: ${json.error?.message ?? res.status}`);
  return json;
}

const claimsOf = (user) => JSON.parse(user.customAttributes || '{}');

async function findByEmail(token, email) {
  const { users } = await call(token, 'accounts:lookup', { email: [email] });
  if (!users?.length) throw new Error(`Nessun utente con email ${email}`);
  return users[0];
}

async function main() {
  const [cmd, email] = process.argv.slice(2);
  const token = await accessToken();

  if (cmd === 'list') {
    let pageToken;
    const admins = [];
    do {
      const page = await call(token, 'accounts:query', { returnUserInfo: true, limit: 500, offset: pageToken });
      for (const u of page.userInfo ?? []) {
        if (claimsOf(u).admin === true) admins.push(u.email ?? u.localId);
      }
      pageToken = page.userInfo?.length === 500 ? (Number(pageToken ?? 0) + 500).toString() : undefined;
    } while (pageToken);
    console.log(admins.length ? admins.join('\n') : 'Nessun admin.');
    return;
  }

  if ((cmd !== 'add' && cmd !== 'remove') || !email) {
    console.log('Uso: node tool/set_admin.js list | add <email> | remove <email>');
    process.exit(1);
  }

  const user = await findByEmail(token, email);
  const claims = claimsOf(user);
  if (cmd === 'add') claims.admin = true;
  else delete claims.admin;
  await call(token, 'accounts:update', {
    localId: user.localId,
    customAttributes: JSON.stringify(claims),
  });
  console.log(`${email}: admin ${cmd === 'add' ? 'aggiunto' : 'rimosso'}.`);
}

main().catch((e) => {
  console.error(e.message ?? e);
  process.exit(1);
});
