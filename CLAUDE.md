# Trashpotting

App Flutter (Android; versione web in preparazione, vedi `docs/WEB.md`; solo italiano) per segnalare cumuli di
rifiuti ("trashpot") sulla mappa, organizzarne la pulizia ed eventi di
gruppo, con punti e classifica. Backend Firebase. Descrizione completa delle
funzionalità: `docs/FUNZIONALITA.md` (lunga, leggerla solo se serve).

## Regole di lavoro
- Una cosa alla volta; chiedere quando manca un'informazione.
- Lavorare su `develop`, commit piccoli. Merge su `main` solo su richiesta.
- Mai avviare/installare/usare l'app sul telefono se non richiesto
  esplicitamente: fermarsi a analyze + test + commit.
- Lingua dell'utente e dei commenti nel codice: italiano.
- Non eliminare gli account di test (`polivastro123+7..+11@gmail.com`).
- Passi finali, in quest'ordine e solo quando l'utente lo dice: pulizia dati
  di test → merge su main → Play Console → App Check (ora risponde 403, è previsto) → test chiuso.

Hosting già online (pagine legali + app web su `/app/`): prima di ogni
`firebase deploy --only hosting` rilanciare `node tool/build_web.js`.

## Comandi
- `flutter analyze` · `flutter test` (37 test, devono passare) · web: `node tool/build_web.js` (→ `hosting/app`)
- `dart format <file>` solo sui file toccati, mai su intere cartelle
  (`lib/`, `test/`): riformatta file non toccati.
- Icone: `dart run flutter_launcher_icons` · Splash:
  `dart run flutter_native_splash:create` (sorgenti in `assets/icon`,
  `assets/splash`, SVG originale `assets/icon/launcher_icon.svg`)
- Functions: `functions/index.js`: notifiche (onReportCreated,
  onReportCleaned, eventReminders) e punti (pointsOn*, con `pointsLedger`).
  I punti li assegna solo il server: l'app non scrive mai `points`.
- Regole: `firestore.rules`, `storage.rules`, `firestore.indexes.json`.
  Verifica senza pubblicare: `firebase deploy --only firestore:rules
  --dry-run`. Emulatore non disponibile (manca Java).
- Dettaglio segnalazione: `screens/report_detail_screen.dart` + blocchi in
  `screens/report_detail/` (part files), logica in
  `state/report_detail_view_model.dart`.

## Stack
Flutter 3.41 / Dart 3.11, Material 3, go_router, Phosphor icons
(`AppIcons`), google_fonts (Figtree), google_maps_flutter, geolocator,
Firebase: Auth, Firestore, Storage, Messaging, Crashlytics, Analytics,
App Check. Ambiente Windows: Bash (Git Bash) e PowerShell; niente Python,
c'è Node.

## Struttura `lib/`
- `app.dart`: router (redirect login → verifica email → onboarding),
  `MaterialApp` con `CompactTextScaler`, `LocationGate`, `BlockedGate`.
- `routes.dart`: percorsi (`/app/mappa`, `/app/report/:id`, …).
- `screens/`: una schermata per file. `main_shell.dart` = barra in basso
  (Mappa, Classifica, Profilo) + pulsante giallo "Segnala".
- `widgets/`: componenti condivisi (vedi sotto).
- `state/`: `AppSession` (utente, flag, messaggi snackbar), view model.
- `services/`: auth, posizione, foto, push, invio segnalazione.
- `repositories/`: accesso Firestore (report, classifica, profilo,
  notifiche, moderazione). I fake nei test implementano queste interfacce:
  aggiungendo un metodo astratto vanno aggiornati anche i fake.
- `models/`: `TrashpotReport`, `ReportFilter` (gruppi daPulire, inCorso,
  evento, pulite), profilo, notifiche.
- `core/`: stile mappa, marker e cluster, geohash, formati data, validatori.

## Design (redesign, solo tema chiaro)
- `kDarkThemeEnabled = false` in `theme/app_theme.dart`: tema scuro
  bloccato finché non viene rifatto.
- Colori in `theme/app_colors.dart`: greenBrand `#0B7A5C`, greenDark
  `#064E3B`, forest `#0E3B2E`, mint `#17B890`, yellow `#FFC53D` (pulsante
  principale), purple `#6E4CE0` (community), sfondo crema `#FAF7F0`.
  Icona/splash `#1BD17D`.
- Testo: `theme/compact_text_scaler.dart`. Fino a 16 invariato, sopra cresce
  a metà (26 → 21). Lì si regola la dimensione globale. Le dimensioni sono
  per lo più scritte nei singoli widget (`fontSize`).
- Componenti: `AppButton` (a rilievo), `AppTextField`, `TabHeader`,
  `BackHeader`, `ReportCard`, `UserAvatar`, `IllustratedMessage`,
  `Skeleton`, `MenuCard`/`MenuTile`/`SectionLabel` (liste di voci),
  `StateMessage` (vuoto/errore con "Riprova"). Pesi max `w800`. Riutilizzarli invece di crearne di nuovi.
- Il telefono dell'utente ha testo al 130%: evitare altezze fisse sul testo
  (usare `minHeight`), rischio overflow.
