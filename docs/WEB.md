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

## Ancora da fare
- Notifiche push sul web: `web/firebase-messaging-sw.js` + chiave VAPID.
- App Check sul web: reCAPTCHA Enterprise (insieme ad App Check Android).
- Pubblicazione: oggi Hosting serve le pagine legali da `hosting/`; per
  l'app web serve un secondo sito Hosting (o una sottocartella).
