// Test delle regole di sicurezza (firestore.rules / storage.rules).
//   cd tool/rules_test && npm install && npm test
// Le scritture riproducono quelle fatte dall'app in lib/repositories/*.
import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
  increment,
  deleteField,
  Timestamp,
  writeBatch,
} from 'firebase/firestore';
import { ref, uploadBytes, deleteObject } from 'firebase/storage';

let env;

const verified = (uid, extra = {}) => ({ email_verified: true, ...extra });

const fs = (uid, claims) =>
  (uid ? env.authenticatedContext(uid, claims ?? verified(uid)) : env.unauthenticatedContext()).firestore();
const st = (uid, claims) =>
  (uid ? env.authenticatedContext(uid, claims ?? verified(uid)) : env.unauthenticatedContext()).storage();
const admin = () => fs('admin1', verified('admin1', { admin: true }));

const newReport = (uid) => ({
  note: 'Bottiglie nel parco',
  photoUrl: null,
  latitude: 43.9,
  longitude: 12.8,
  geohash: 'srbj2v0000',
  uid,
  status: 'segnalata',
  type: 'Discarica abusiva',
  address: 'Via Roma',
  createdAt: serverTimestamp(),
});

const today = () => Math.floor(Date.now() / 86400000);

/** Crea una segnalazione come fa l'app: report + contatore nello stesso batch. */
function createReport(db, id, data, quota) {
  const batch = writeBatch(db);
  batch.set(doc(db, `reports/${id}`), data);
  batch.update(doc(db, `users/${data.uid}`), { reportQuota: quota });
  return batch.commit();
}

async function seed(path, data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), data);
  });
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-trashpotting',
    firestore: { rules: readFileSync('../../firestore.rules', 'utf8') },
    storage: { rules: readFileSync('../../storage.rules', 'utf8') },
  });
});

after(async () => env?.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await seed('users/alice', { username: 'Alice' });
  await seed('users/bruno', { username: 'Bruno' });
  await seed('users/mallory', { username: 'Mallory', blocked: true });
  await seed('reports/r1', { ...newReport('alice'), createdAt: Timestamp.now() });
});

describe('accesso anonimo', () => {
  test('non può leggere né scrivere', async () => {
    await assertFails(getDoc(doc(fs(null), 'reports/r1')));
    await assertFails(setDoc(doc(fs(null), 'reports/x'), newReport('anon')));
  });
});

describe('profili', () => {
  test('il proprietario crea e aggiorna il proprio profilo', async () => {
    await assertSucceeds(setDoc(doc(fs('carla'), 'users/carla'),
      { username: 'Carla', updatedAt: serverTimestamp(), createdAt: serverTimestamp() }, { merge: true }));
    await assertSucceeds(setDoc(doc(fs('alice'), 'users/alice'),
      { onboardingComplete: true }, { merge: true }));
  });

  test("non può salvare l'email nel profilo pubblico", async () => {
    await assertFails(setDoc(doc(fs('carla'), 'users/carla'),
      { username: 'Carla', email: 'carla@x.it' }));
  });

  test("non può sbloccarsi da solo né modificare il profilo altrui", async () => {
    await assertFails(updateDoc(doc(fs('mallory'), 'users/mallory'), { blocked: false }));
    await assertFails(updateDoc(doc(fs('bruno'), 'users/alice'), { username: 'Hack' }));
  });

  test("l'admin blocca e sblocca un utente, ma non ne cambia il nome", async () => {
    await assertSucceeds(updateDoc(doc(admin(), 'users/bruno'),
      { blocked: true, blockedAt: serverTimestamp(), blockedBy: 'admin1' }));
    await assertSucceeds(updateDoc(doc(admin(), 'users/bruno'), { blocked: false }));
    await assertFails(updateDoc(doc(admin(), 'users/bruno'), { username: 'X' }));
  });

  test('una claim admin finta (non sul token) non vale', async () => {
    await assertFails(updateDoc(doc(fs('bruno'), 'users/alice'), { blocked: true }));
  });
});

describe('segnalazioni', () => {
  test('un utente verificato crea una segnalazione propria (con contatore)', async () => {
    await assertSucceeds(createReport(fs('bruno'), 'r2', newReport('bruno'), { day: today(), count: 1 }));
  });

  test('senza aggiornare il contatore la segnalazione è rifiutata', async () => {
    await assertFails(setDoc(doc(fs('bruno'), 'reports/r2'), newReport('bruno')));
  });

  test('non può crearla a nome di altri, già pulita o con campi extra', async () => {
    const q = { day: today(), count: 1 };
    await assertFails(createReport(fs('bruno'), 'r2', newReport('alice'), q));
    await assertFails(createReport(fs('bruno'), 'r2', { ...newReport('bruno'), status: 'ripulita' }, q));
    await assertFails(createReport(fs('bruno'), 'r2', { ...newReport('bruno'), points: 99 }, q));
  });

  test('email non verificata o utente bloccato non possono creare', async () => {
    const q = { day: today(), count: 1 };
    await assertFails(createReport(fs('bruno', { email_verified: false }), 'r2', newReport('bruno'), q));
    await assertFails(createReport(fs('mallory'), 'r2', newReport('mallory'), q));
  });

  test("limite giornaliero: l'11ª segnalazione è rifiutata", async () => {
    await seed('users/bruno', { username: 'Bruno', reportQuota: { day: today(), count: 9 } });
    await assertSucceeds(createReport(fs('bruno'), 'r10', newReport('bruno'), { day: today(), count: 10 }));
    await assertFails(createReport(fs('bruno'), 'r11', newReport('bruno'), { day: today(), count: 11 }));
  });

  test('il contatore non si può azzerare né spostare in avanti', async () => {
    await seed('users/bruno', { username: 'Bruno', reportQuota: { day: today(), count: 10 } });
    await assertFails(updateDoc(doc(fs('bruno'), 'users/bruno'), { reportQuota: { day: today(), count: 0 } }));
    await assertFails(createReport(fs('bruno'), 'r2', newReport('bruno'), { day: today(), count: 1 }));
    await assertFails(createReport(fs('bruno'), 'r2', newReport('bruno'), { day: today() + 1, count: 1 }));
  });

  test('il giorno dopo il contatore riparte da 1', async () => {
    await seed('users/bruno', { username: 'Bruno', reportQuota: { day: today() - 1, count: 10 } });
    await assertSucceeds(createReport(fs('bruno'), 'r2', newReport('bruno'), { day: today(), count: 1 }));
  });

  test('flusso pulizia: presa in carico e completamento', async () => {
    const db = fs('bruno');
    await assertSucceeds(updateDoc(doc(db, 'reports/r1'), {
      status: 'puliziaInCorso',
      cleaningOwner: { uid: 'bruno', username: 'Bruno' },
      cleaningStartedAt: serverTimestamp(),
    }));
    // Un altro utente non può completarla.
    await assertFails(updateDoc(doc(fs('alice'), 'reports/r1'), {
      status: 'ripulita', cleanupPhotoUrl: 'x', cleanedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(doc(db, 'reports/r1'), {
      status: 'ripulita', cleanupPhotoUrl: 'https://x/y.jpg', cleanedAt: serverTimestamp(),
    }));
  });

  test('non si può prendere in carico a nome di altri', async () => {
    await assertFails(updateDoc(doc(fs('bruno'), 'reports/r1'), {
      status: 'puliziaInCorso',
      cleaningOwner: { uid: 'alice', username: 'Alice' },
      cleaningStartedAt: serverTimestamp(),
    }));
  });

  test('evento: creazione, partecipazione, solo il creatore avvia la pulizia', async () => {
    const event = {
      creator: { uid: 'alice', username: 'Alice' },
      scheduledAt: Timestamp.fromDate(new Date('2030-01-01')),
      participants: [{ uid: 'alice', username: 'Alice' }],
    };
    await assertSucceeds(updateDoc(doc(fs('alice'), 'reports/r1'), { status: 'eventoCreato', event }));
    await assertSucceeds(updateDoc(doc(fs('bruno'), 'reports/r1'), {
      event: { ...event, participants: [...event.participants, { uid: 'bruno', username: 'Bruno' }] },
    }));
    // Il partecipante non può cambiare data o creatore.
    await assertFails(updateDoc(doc(fs('bruno'), 'reports/r1'), {
      event: { ...event, scheduledAt: Timestamp.now() },
    }));
    await assertFails(updateDoc(doc(fs('bruno'), 'reports/r1'), {
      status: 'puliziaInCorso',
      cleaningOwner: { uid: 'bruno', username: 'Bruno' },
      cleaningStartedAt: serverTimestamp(),
    }));
  });

  test("anonimizzazione all'eliminazione dell'account", async () => {
    await assertSucceeds(updateDoc(doc(fs('alice'), 'reports/r1'), { uid: null }));
  });

  test("solo l'admin cancella e archivia", async () => {
    await assertFails(deleteDoc(doc(fs('alice'), 'reports/r1')));
    await assertFails(setDoc(doc(fs('alice'), 'removedReports/r1'), { x: 1 }));
    await assertSucceeds(setDoc(doc(admin(), 'removedReports/r1'), { removedBy: 'admin1' }));
    await assertSucceeds(deleteDoc(doc(admin(), 'reports/r1')));
  });
});

describe('voti della community', () => {
  const near = { latitude: 43.9005, longitude: 12.8005 }; // ~70 m da r1
  const far = { latitude: 43.95, longitude: 12.8 }; // ~5.5 km

  function vote(db, uid, kind, pos, reportUpdate) {
    const batch = writeBatch(db);
    batch.set(doc(db, `reports/r1/votes/${uid}`), { vote: kind, ...pos, createdAt: serverTimestamp() });
    if (reportUpdate) batch.update(doc(db, 'reports/r1'), reportUpdate);
    return batch.commit();
  }

  beforeEach(async () => {
    await seed('users/carla', { username: 'Carla' });
  });

  test('"C\'è ancora" vicino al punto rende la segnalazione aperta', async () => {
    await assertSucceeds(vote(fs('bruno'), 'bruno', 'present', near, { confirmations: 1, status: 'aperta' }));
  });

  test('un solo voto per utente', async () => {
    await assertSucceeds(vote(fs('bruno'), 'bruno', 'present', near, { confirmations: 1, status: 'aperta' }));
    await assertFails(vote(fs('bruno'), 'bruno', 'gone', near, { goneVotes: 1 }));
  });

  test("l'autore non vota sulla propria segnalazione", async () => {
    await assertFails(vote(fs('alice'), 'alice', 'present', near, { confirmations: 1, status: 'aperta' }));
  });

  test('non si vota da lontano', async () => {
    await assertFails(vote(fs('bruno'), 'bruno', 'present', far, { confirmations: 1, status: 'aperta' }));
  });

  test('voto e contatori devono andare insieme', async () => {
    await assertFails(vote(fs('bruno'), 'bruno', 'present', near, null));
    await assertFails(updateDoc(doc(fs('bruno'), 'reports/r1'), { confirmations: 1, status: 'aperta' }));
    await assertFails(vote(fs('bruno'), 'bruno', 'present', near, { confirmations: 5, status: 'aperta' }));
  });

  test('due "Non c\'è più" rendono la segnalazione sparita', async () => {
    // Primo voto: lo stato non cambia (e non può già diventare sparita).
    await assertFails(vote(fs('bruno'), 'bruno', 'gone', near, { goneVotes: 1, status: 'sparita' }));
    await assertSucceeds(vote(fs('bruno'), 'bruno', 'gone', near, { goneVotes: 1 }));
    // Secondo voto: diventa sparita, obbligatoriamente.
    await assertFails(vote(fs('carla'), 'carla', 'gone', near, { goneVotes: 2 }));
    await assertSucceeds(vote(fs('carla'), 'carla', 'gone', near, { goneVotes: 2, status: 'sparita' }));
    // Non si vota più su una segnalazione sparita.
    await assertFails(vote(fs('mallory'), 'mallory', 'present', near, { confirmations: 1, status: 'aperta' }));
  });

  test("solo l'admin ripristina una segnalazione sparita", async () => {
    await seed('reports/r1', { ...newReport('alice'), createdAt: Timestamp.now(), status: 'sparita', goneVotes: 2 });
    await assertFails(updateDoc(doc(fs('bruno'), 'reports/r1'), { status: 'segnalata', goneVotes: 0 }));
    await assertSucceeds(updateDoc(doc(admin(), 'reports/r1'), { status: 'segnalata', goneVotes: 0 }));
  });

  test('il proprio voto si legge, quelli altrui no', async () => {
    await assertSucceeds(vote(fs('bruno'), 'bruno', 'present', near, { confirmations: 1, status: 'aperta' }));
    await assertSucceeds(getDoc(doc(fs('bruno'), 'reports/r1/votes/bruno')));
    await assertFails(getDoc(doc(fs('carla'), 'reports/r1/votes/bruno')));
  });
});

describe('classifica', () => {
  test('ognuno aumenta solo i propri punti, di 1 o 2', async () => {
    const db = fs('bruno');
    await assertSucceeds(setDoc(doc(db, 'leaderboard/bruno'), { username: 'Bruno', points: increment(1) }, { merge: true }));
    await assertSucceeds(setDoc(doc(db, 'leaderboard/bruno'), { username: 'Bruno', points: increment(2) }, { merge: true }));
    await assertFails(setDoc(doc(db, 'leaderboard/bruno'), { points: increment(50) }, { merge: true }));
    await assertFails(setDoc(doc(db, 'leaderboard/alice'), { username: 'Alice', points: increment(1) }, { merge: true }));
  });

  test("aggiornare lo username senza punti è consentito", async () => {
    await seed('leaderboard/bruno', { username: 'B', points: 3 });
    await assertSucceeds(updateDoc(doc(fs('bruno'), 'leaderboard/bruno'), { username: 'Bruno' }));
  });

  test('un utente bloccato non guadagna punti', async () => {
    await assertFails(setDoc(doc(fs('mallory'), 'leaderboard/mallory'), { username: 'M', points: increment(1) }, { merge: true }));
  });
});

describe('segnalazioni di contenuti (flags)', () => {
  const flag = (uid) => ({
    reportId: 'r1', reporterUid: uid, reportAuthorUid: 'alice',
    reason: 'Foto inappropriata', status: 'open', createdAt: serverTimestamp(),
  });

  test("un utente segnala un contenuto una volta e vede solo la propria", async () => {
    await assertSucceeds(getDoc(doc(fs('bruno'), 'flags/r1_bruno'))); // non esiste ancora
    await assertSucceeds(setDoc(doc(fs('bruno'), 'flags/r1_bruno'), flag('bruno')));
    await assertSucceeds(getDoc(doc(fs('bruno'), 'flags/r1_bruno')));
    await assertFails(setDoc(doc(fs('bruno'), 'flags/r1_bruno'), flag('bruno')));
    await assertFails(setDoc(doc(fs('bruno'), 'flags/r1_alice'), flag('alice')));
  });

  test("solo l'admin legge la coda e la gestisce", async () => {
    await seed('flags/r1_bruno', flag('bruno'));
    await assertFails(getDoc(doc(fs('alice'), 'flags/r1_bruno')));
    await assertSucceeds(getDoc(doc(admin(), 'flags/r1_bruno')));
    await assertSucceeds(updateDoc(doc(admin(), 'flags/r1_bruno'), { status: 'dismissed' }));
  });
});

describe('storage', () => {
  const jpg = new Uint8Array([0xff, 0xd8, 0xff]);
  const meta = { contentType: 'image/jpeg' };

  test('carica solo nella propria cartella e solo immagini', async () => {
    await assertSucceeds(uploadBytes(ref(st('bruno'), 'report_photos/bruno/1.jpg'), jpg, meta));
    await assertFails(uploadBytes(ref(st('bruno'), 'report_photos/alice/1.jpg'), jpg, meta));
    await assertFails(uploadBytes(ref(st('bruno'), 'report_photos/bruno/1.txt'), jpg, { contentType: 'text/plain' }));
    await assertSucceeds(uploadBytes(ref(st('bruno'), 'cleanup_photos/r1/bruno/1.jpg'), jpg, meta));
  });

  test("l'admin elimina foto altrui, gli altri no", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(), 'report_photos/alice/1.jpg'), jpg, meta);
    });
    await assertFails(deleteObject(ref(st('bruno'), 'report_photos/alice/1.jpg')));
    await assertSucceeds(deleteObject(ref(st('admin1', verified('admin1', { admin: true })), 'report_photos/alice/1.jpg')));
  });
});
