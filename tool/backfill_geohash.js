// Aggiunge il campo `geohash` alle segnalazioni create prima della ricerca
// per raggio (lib/core/geohash.dart). Da eseguire una sola volta:
//
//   cd tool
//   npm install firebase-admin geofire-common
//   set GOOGLE_APPLICATION_CREDENTIALS=path\to\service-account.json
//   node backfill_geohash.js            (anteprima, non scrive nulla)
//   node backfill_geohash.js --write    (scrive su Firestore)
//
// geofire-common usa lo stesso algoritmo e la stessa precisione (10) dell'app.

const admin = require('firebase-admin');
const { geohashForLocation } = require('geofire-common');

const write = process.argv.includes('--write');

admin.initializeApp({ projectId: 'trashpotting-app' });
const db = admin.firestore();

async function main() {
  const snap = await db.collection('reports').get();
  let batch = db.batch();
  let pending = 0;
  let updated = 0;

  for (const doc of snap.docs) {
    const { latitude, longitude, geohash } = doc.data();
    if (geohash || typeof latitude !== 'number' || typeof longitude !== 'number') {
      continue;
    }
    const hash = geohashForLocation([latitude, longitude]);
    console.log(`${doc.id}: ${hash}`);
    updated++;
    if (!write) continue;
    batch.update(doc.ref, { geohash: hash });
    if (++pending === 400) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (write && pending > 0) await batch.commit();

  console.log(
    `${updated} segnalazioni ${write ? 'aggiornate' : 'da aggiornare (usa --write)'} su ${snap.size}.`,
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
