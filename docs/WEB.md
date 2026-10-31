# Versione web

Stesso codice dell'app Android (`flutter build web`, output in `build/web`).

## Già fatto nel codice
- Foto: compresse e caricate come byte (`putData`), anteprime con
  `localPhotoProvider` (`widgets/local_photo.dart`): funzionano anche nel
  browser, dove il "percorso" della foto è un indirizzo `blob:`.
- Schermi larghi: l'app sta in una colonna da 480 px (`widgets/phone_frame.dart`).
- Posizione: sul web non c'è il blocco "posizione obbligatoria"; la mappa la
  chiede al browser (serve HTTPS) e, se rifiutata, parte dal centro Italia.
- Crashlytics è già escluso sul web (`main.dart`).

## Da configurare (una volta, dalle console)
1. **Foto visibili nel browser (CORS di Storage).** Flutter web scarica le
   immagini con richieste che lo Storage deve autorizzare:
   `gcloud storage buckets update gs://trashpotting-app.firebasestorage.app --cors-file=storage-cors.json`
   (oppure `gsutil cors set storage-cors.json gs://trashpotting-app.firebasestorage.app`).
   Se il sito avrà un dominio diverso, aggiungerlo in `storage-cors.json`.
2. **Google Maps.** La chiave in `web/index.html` deve avere abilitata la
   "Maps JavaScript API" e, in Google Cloud Console → Credenziali, essere
   limitata ai referrer del sito (`https://trashpotting-app.web.app/*`, …).
3. **Firebase Auth.** Il dominio del sito va in Authentication →
   Impostazioni → Domini autorizzati (quelli `web.app`/`firebaseapp.com` ci
   sono già).

## Pubblicazione
L'app web sta nella sottocartella `/app` dello stesso sito delle pagine
legali (`https://trashpotting-app.web.app/app/`).
1. `node tool/build_web.js` (con le notifiche:
   `WEB_PUSH_VAPID_KEY=... node tool/build_web.js`): compila con base
   `/app/`, copia in `hosting/app/` e mette `firebase-messaging-sw.js` nella
   radice del sito. I file generati non sono versionati.
2. `firebase deploy --only hosting`: pubblica pagine legali **e** app web.
   Se `hosting/app/` non esiste, si pubblicano solo le pagine legali.

## Notifiche push sul web (rimandate)
**Decisione:** per ora niente notifiche sul web. Si compila senza
`WEB_PUSH_VAPID_KEY`, quindi restano spente; il codice resta pronto per quando
si vorranno attivare.

- Codice pronto: `PushService` registra il browser (piattaforma `web`) se la
  build ha la chiave VAPID; il service worker è `web/firebase-messaging-sw.js`;
  le Cloud Functions aggiungono il link che apre la segnalazione.
- Da fare: creare la chiave in Console Firebase → Impostazioni progetto →
  Cloud Messaging → Certificati push web, e ripubblicare le functions.
- Su iPhone funzionano solo se il sito è aggiunto alla schermata Home.

## Ancora da fare
- App Check sul web: reCAPTCHA Enterprise (insieme ad App Check Android).
