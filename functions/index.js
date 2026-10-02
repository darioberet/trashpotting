// Notifiche push di Trashpotting.
//
// Ogni notifica viene anche salvata in users/{uid}/notifications, così compare
// nella schermata Notifiche dell'app; poi viene inviata via FCM a tutti i
// dispositivi dell'utente (users/{uid}/devices/{token}).
//
//   1. Segnalazione ripulita     → all'autore
//   2. Promemoria evento          → ai partecipanti, il giorno prima
//   3. Nuova segnalazione vicina  → a chi è entro 5 km (max 1 al giorno)

const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { onDocumentUpdated, onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { setGlobalOptions, logger } = require('firebase-functions/v2');
const { geohashQueryBounds, distanceBetween } = require('geofire-common');

initializeApp();
const db = getFirestore();

// Vicino al database (eur3) e agli utenti; 1 istanza basta e limita i costi.
setGlobalOptions({ region: 'europe-west1', maxInstances: 3 });

const NEARBY_RADIUS_KM = 5;
const NEARBY_MIN_INTERVAL_MS = 24 * 60 * 60 * 1000;
const TIME_ZONE = 'Europe/Rome';

async function usernameOf(uid) {
  if (!uid) return null;
  const snap = await db.doc(`users/${uid}`).get();
  const name = snap.get('username');
  return typeof name === 'string' && name.trim() ? name.trim() : null;
}

/**
 * Salva la notifica nell'app e la invia ai dispositivi di [uid].
 * I token non più validi vengono rimossi.
 */
async function notify(uid, { type, title, body, reportId }) {
  await db.collection(`users/${uid}/notifications`).add({
    type,
    title,
    body,
    reportId: reportId ?? null,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  const devices = await db.collection(`users/${uid}/devices`).get();
  if (devices.empty) return;
  const tokens = devices.docs.map((d) => d.id);

  const res = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: { type, ...(reportId ? { reportId } : {}) },
    android: {
      priority: 'high',
      notification: { channelId: 'trashpotting_default', icon: 'ic_notification', color: '#1D9E75' },
    },
  });

  const stale = [];
  res.responses.forEach((r, i) => {
    const code = r.error?.code;
    if (code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token') {
      stale.push(devices.docs[i].ref.delete());
    }
  });
  await Promise.all(stale);
}

function shortTitle(report) {
  const note = (report.note ?? '').trim();
  if (!note) return 'la tua segnalazione';
  return note.length > 40 ? `«${note.slice(0, 40)}…»` : `«${note}»`;
}

// ── 1. Segnalazione ripulita → autore ──────────────────────────────────────
exports.onReportCleaned = onDocumentUpdated('reports/{reportId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (before.status === 'ripulita' || after.status !== 'ripulita') return;

  const author = after.uid;
  const cleaner = after.cleaningOwner?.uid;
  if (!author || author === cleaner) return;

  const cleanerName = after.cleaningOwner?.username || (await usernameOf(cleaner)) || 'un volontario';
  await notify(author, {
    type: 'report_cleaned',
    title: '🎉 Zona ripulita!',
    body: `${shortTitle(after)} è stata ripulita da ${cleanerName}. Grazie per averla segnalata!`,
    reportId: event.params.reportId,
  });
});

// ── 2. Promemoria evento → partecipanti, il giorno prima ───────────────────
// Scarto di Roma da UTC in un certo istante (es. +2h in estate), letto da
// Intl: non dipende dal fuso orario del server.
function romeOffsetMs(date) {
  const name = new Intl.DateTimeFormat('en-US', { timeZone: TIME_ZONE, timeZoneName: 'shortOffset' })
    .formatToParts(date).find((p) => p.type === 'timeZoneName').value; // "GMT+2"
  const m = name.match(/GMT([+-]\d+)(?::(\d+))?/);
  if (!m) return 0;
  const sign = m[1].startsWith('-') ? -1 : 1;
  return (Number(m[1]) * 60 + sign * Number(m[2] ?? 0)) * 60 * 1000;
}

/** [inizio, fine) del giorno di Roma a [daysFromToday] giorni da oggi, in UTC. */
function romeDayBounds(daysFromToday) {
  const ymd = new Intl.DateTimeFormat('en-CA', {
    timeZone: TIME_ZONE, year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(new Date()); // YYYY-MM-DD
  const [y, mo, d] = ymd.split('-').map(Number);
  const midnight = (offsetDays) => {
    const guess = new Date(Date.UTC(y, mo - 1, d + offsetDays));
    return new Date(guess.getTime() - romeOffsetMs(guess));
  };
  return [midnight(daysFromToday), midnight(daysFromToday + 1)];
}

exports.eventReminders = onSchedule(
  { schedule: 'every day 18:00', timeZone: TIME_ZONE },
  async () => {
    const [start, end] = romeDayBounds(1);
    const snap = await db.collection('reports')
      .where('event.scheduledAt', '>=', Timestamp.fromDate(start))
      .where('event.scheduledAt', '<', Timestamp.fromDate(end))
      .get();

    for (const doc of snap.docs) {
      const report = doc.data();
      if (report.status !== 'eventoCreato') continue;
      const when = report.event.scheduledAt.toDate().toLocaleTimeString('it-IT', {
        timeZone: TIME_ZONE, hour: '2-digit', minute: '2-digit',
      });
      const place = report.address ? ` in ${report.address}` : '';
      const uids = [...new Set((report.event.participants ?? []).map((p) => p.uid).filter(Boolean))];
      await Promise.all(uids.map((uid) => notify(uid, {
        type: 'event_reminder',
        title: '📅 Domani si pulisce!',
        body: `Domani alle ${when} c'è la pulizia${place}. Porta guanti e sacchi!`,
        reportId: doc.id,
      })));
    }
    logger.info(`Promemoria inviati per ${snap.size} eventi`);
  },
);

// ── 3. Nuova segnalazione vicina → utenti entro 5 km, max 1 al giorno ──────
exports.onReportCreated = onDocumentCreated('reports/{reportId}', async (event) => {
  const report = event.data.data();
  const { latitude, longitude, uid: author } = report;
  if (typeof latitude !== 'number' || typeof longitude !== 'number') return;

  const center = [latitude, longitude];
  const bounds = geohashQueryBounds(center, NEARBY_RADIUS_KM * 1000);
  const snaps = await Promise.all(bounds.map(([s, e]) =>
    db.collectionGroup('notifyPrefs')
      .where('nearby', '==', true)
      .orderBy('geohash')
      .startAt(s)
      .endAt(e)
      .limit(500)
      .get()));

  const now = Date.now();
  const seen = new Set();
  const jobs = [];
  for (const doc of snaps.flatMap((s) => s.docs)) {
    const uid = doc.ref.parent.parent.id;
    if (uid === author || seen.has(uid)) continue;
    seen.add(uid);
    const p = doc.data();
    if (typeof p.latitude !== 'number' || typeof p.longitude !== 'number') continue;
    const km = distanceBetween([p.latitude, p.longitude], center);
    if (km > NEARBY_RADIUS_KM) continue;
    const last = p.lastNearbyAt?.toMillis?.() ?? 0;
    if (now - last < NEARBY_MIN_INTERVAL_MS) continue;

    jobs.push(doc.ref.update({ lastNearbyAt: FieldValue.serverTimestamp() })
      .then(() => notify(uid, {
        type: 'nearby_report',
        title: '📍 Nuova segnalazione vicino a te',
        body: `${km < 1 ? `A ${Math.round(km * 1000)} m` : `A ${km.toFixed(1)} km`} da te: ${shortTitle(report)}. Ti va di dare un'occhiata?`,
        reportId: event.params.reportId,
      })));
  }
  await Promise.all(jobs);
  logger.info(`Segnalazione ${event.params.reportId}: notificati ${jobs.length} utenti vicini`);
});
