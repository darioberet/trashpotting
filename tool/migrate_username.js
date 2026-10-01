// Migrazione una tantum al campo `username` e rimozione delle email da
// Firestore (vedi lib/models/app_user_profile.dart):
//
//   users/{uid}         displayName -> username, rimuove email e displayName
//   leaderboard/{uid}   name -> username (preso dal profilo se presente)
//   reports/{id}        in event.creator, event.participants[] e
//                       cleaningOwner: displayName -> username, rimuove email
//
//   cd tool
//   npm install firebase-admin
//   set GOOGLE_APPLICATION_CREDENTIALS=path\to\service-account.json
//   node migrate_username.js            (anteprima, non scrive nulla)
//   node migrate_username.js --write    (scrive su Firestore)

const admin = require('firebase-admin');

const write = process.argv.includes('--write');

admin.initializeApp({ projectId: 'trashpotting-app' });
const db = admin.firestore();
const { FieldValue } = admin.firestore;

const clean = (value) =>
  typeof value === 'string' && value.trim() !== '' ? value.trim() : null;

/** Scrive a blocchi di 400 operazioni (limite batch: 500). */
function batcher() {
  let batch = db.batch();
  let pending = 0;
  let total = 0;
  return {
    async update(ref, data) {
      total++;
      if (!write) return;
      batch.update(ref, data);
      if (++pending === 400) {
        await batch.commit();
        batch = db.batch();
        pending = 0;
      }
    },
    async flush() {
      if (write && pending > 0) await batch.commit();
      return total;
    },
  };
}

async function main() {
  const out = batcher();

  // 1. Profili
  const usernames = new Map();
  for (const doc of (await db.collection('users').get()).docs) {
    const data = doc.data();
    const username = clean(data.username) ?? clean(data.displayName);
    if (username) usernames.set(doc.id, username);

    const update = {};
    if (username && data.username !== username) update.username = username;
    if ('email' in data) update.email = FieldValue.delete();
    if ('displayName' in data) update.displayName = FieldValue.delete();
    if (Object.keys(update).length === 0) continue;
    console.log(`users/${doc.id}: username=${username ?? '-'}`);
    await out.update(doc.ref, update);
  }

  // 2. Classifica
  for (const doc of (await db.collection('leaderboard').get()).docs) {
    const data = doc.data();
    const legacy = clean(data.name);
    const username =
      usernames.get(doc.id) ??
      clean(data.username) ??
      (legacy && legacy !== 'Utente' ? legacy : null);

    const update = {};
    if (username && data.username !== username) update.username = username;
    if ('name' in data) update.name = FieldValue.delete();
    if (Object.keys(update).length === 0) continue;
    console.log(`leaderboard/${doc.id}: username=${username ?? '-'}`);
    await out.update(doc.ref, update);
  }

  // 3. Profili incorporati nelle segnalazioni
  const migrateProfile = (p) => {
    if (!p || typeof p !== 'object') return p;
    const { email, displayName, ...rest } = p;
    const username =
      usernames.get(rest.uid) ?? clean(rest.username) ?? clean(displayName);
    return { ...rest, username: username ?? null };
  };
  const needsMigration = (p) =>
    p && typeof p === 'object' && ('email' in p || 'displayName' in p);

  for (const doc of (await db.collection('reports').get()).docs) {
    const data = doc.data();
    const update = {};
    if (needsMigration(data.cleaningOwner)) {
      update.cleaningOwner = migrateProfile(data.cleaningOwner);
    }
    const event = data.event;
    if (
      event &&
      (needsMigration(event.creator) ||
        (event.participants ?? []).some(needsMigration))
    ) {
      update.event = {
        ...event,
        creator: migrateProfile(event.creator),
        participants: (event.participants ?? []).map(migrateProfile),
      };
    }
    if (Object.keys(update).length === 0) continue;
    console.log(`reports/${doc.id}: ${Object.keys(update).join(', ')}`);
    await out.update(doc.ref, update);
  }

  const total = await out.flush();
  console.log(
    `${total} documenti ${write ? 'aggiornati' : 'da aggiornare (usa --write)'}.`,
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
