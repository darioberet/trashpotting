# Trashpotting: funzionalità e funzionamento

Trashpotting è un'app Android (Flutter + Firebase) per **segnalare rifiuti abbandonati**, organizzarne la **pulizia** e premiare chi contribuisce con una **classifica**. Ogni segnalazione ha una posizione GPS, una foto facoltativa e un tipo di rifiuto, e attraversa un ciclo di vita: *segnalata → in corso → ripulita*.

Questo documento descrive ogni funzionalità: cosa fa per l'utente, come funziona dietro le quinte e dove si trova nel codice.

---

## Indice

1. [Architettura in breve](#1-architettura-in-breve)
2. [Account](#2-account): registrazione, verifica email, login, password, onboarding, eliminazione
3. [Posizione obbligatoria](#3-posizione-obbligatoria)
4. [Mappa](#4-mappa): ricerca per raggio, filtri, gruppi di marker, lista
5. [Segnalare un rifiuto](#5-segnalare-un-rifiuto)
6. [Dettaglio segnalazione](#6-dettaglio-segnalazione)
7. [Pulizia ed eventi](#7-pulizia-ed-eventi)
8. [Classifica e punti](#8-classifica-e-punti)
9. [Profilo](#9-profilo)
10. [Le mie segnalazioni](#10-le-mie-segnalazioni)
11. [Notifiche](#11-notifiche)
12. [Impostazioni e tema](#12-impostazioni-e-tema)
13. [Aiuto e feedback](#13-aiuto-e-feedback)
14. [Moderazione](#14-moderazione): segnalazione contenuti, admin, blocco utenti
15. [Sicurezza: regole Firestore e Storage](#15-sicurezza-regole-firestore-e-storage)
16. [Dati su Firestore](#16-dati-su-firestore)
17. [Costi e ottimizzazioni](#17-costi-e-ottimizzazioni)
18. [Strumenti di sviluppo](#18-strumenti-di-sviluppo)
19. [Limiti noti](#19-limiti-noti)

---

## 1. Architettura in breve

| Componente | Uso |
|---|---|
| **Flutter** (Dart) | app Android; struttura `screens/` (UI), `state/` (stato), `repositories/` (accesso ai dati), `services/` (logica), `core/` (utilità) |
| **Firebase Authentication** | account con email e password, verifica email, ruolo admin (custom claim) |
| **Cloud Firestore** (regione `eur3`) | segnalazioni, profili, classifica, contenuti segnalati |
| **Firebase Storage** (bucket `us-east1`) | foto delle segnalazioni, delle pulizie e dei profili |
| **Regole di sicurezza** | `firestore.rules` e `storage.rules`: decidono, sul server, chi può leggere e scrivere cosa |
| **App Check** | provider di debug nelle build di debug, Play Integrity in release (`lib/main.dart`) |
| **Crashlytics / Analytics** | crash e navigazione tra schermate (raccolta disattivata in debug) |
| **Google Maps SDK** | mappa principale e mini-mappa nel dettaglio |

Non ci sono Cloud Functions: tutta la logica gira nell'app, e le regole di sicurezza verificano che ogni scrittura sia lecita.

**Navigazione:** `go_router` (`lib/app.dart`, `lib/routes.dart`). Un *redirect* centrale porta l'utente nel posto giusto in base allo stato della sessione:

```
non loggato               → Login
loggato, email non verif. → Verifica email
verificato, onboarding no → Onboarding
tutto ok                  → App (Mappa / Classifica / Profilo)
```

**Sessione:** `AppSession` (`lib/state/app_session.dart`) tiene utente corrente, username, flag di onboarding, ruolo admin e stato di blocco, e li aggiorna in tempo reale.

---

## 2. Account

### 2.1 Registrazione
**Schermata:** `register_screen.dart`

- **Campi:** username (facoltativo), email, password, conferma password e la casella obbligatoria "Ho almeno 14 anni, ho letto e accetto i Termini d'uso e l'Informativa privacy", con i link alle due pagine. Versione accettata e data vengono salvate su `users/{uid}` (`termsVersion`, `termsAcceptedAt`).
- **Validazioni** (`core/form_validators.dart`):
  - email in formato valido;
  - password di almeno 6 caratteri;
  - conferma uguale alla password.

  Gli errori compaiono sotto i campi mentre si scrive.
- **Al salvataggio:**
  1. crea l'account in Firebase Auth;
  2. crea il profilo `users/{uid}` con lo `username`, **senza email** (l'email resta solo in Firebase Auth);
  3. imposta `onboardingComplete: false`, così il nuovo utente passa dall'onboarding;
  4. invia l'email di verifica e porta alla schermata di verifica.
- **Errori Firebase** (email già usata, rete assente…) tradotti in italiano da `core/error_mapper.dart`.

### 2.2 Verifica email
**Schermata:** `email_verification_screen.dart`

- Mostra l'indirizzo a cui è stato inviato il link.
- **Controllo automatico ogni 4 secondi:** quando l'utente clicca il link nella mail, l'app se ne accorge da sola e prosegue.
- **Pulsanti:**
  - "Ho verificato la mia email" forza il controllo;
  - "Reinvia email";
  - "Torna al login".
- Dopo la verifica rinnova il token di Firebase, perché le regole di sicurezza leggono `email_verified` dal token, e rilegge flag di onboarding e username.

### 2.3 Login e recupero password
**Schermata:** `login_screen.dart`

- Email e password, con messaggi chiari per credenziali errate ("Email o password non corretti").
- **"Password dimenticata?":** chiede l'email e invia il link di reimpostazione di Firebase.
- Dopo il login rilegge il flag di onboarding prima di decidere la destinazione.

### 2.4 Onboarding
**Schermata:** `onboarding_screen.dart`, mostrato **una sola volta** agli account nuovi. Usa sempre il tema chiaro, perché le illustrazioni flat vector (`assets/onboarding/`) sono disegnate su fondo chiaro.

1. **Segnala:** "Hai visto dei rifiuti? Segnalali in 10 secondi".
2. **Pulisci:** "Ripuliamo insieme".
3. **Classifica:** "Ogni gesto conta (e fa punti)".
4. **Posizione:** "Ci serve la tua posizione". Spiega perché serve il GPS **prima** del popup di Android, che parte solo premendo "Consenti la posizione". Una richiesta senza spiegazione viene rifiutata molto più spesso.
5. **Profilo:** "Come ti chiamiamo?", con foto (fotocamera o galleria) e username già compilato se inserito alla registrazione. Poi "Inizia" oppure "Salta per ora".

**Navigazione:** le prime tre pagine si scorrono anche con lo swipe. "Salta" porta alla pagina della posizione, non oltre. Puntini di avanzamento arancioni.

Il flag `onboardingComplete: true` impedisce che l'onboarding si ripresenti.

### 2.5 Logout ed eliminazione account
**Dal Profilo.**

- **Logout:** immediato.
- **Elimina account** (obbligatorio per Google Play):
  1. chiede la **password**: Firebase la esige per le operazioni sensibili, e averla subito evita di cancellare i dati e poi fallire;
  2. **anonimizza** le segnalazioni dell'utente: restano sulla mappa senza autore;
  3. cancella il profilo e la riga in classifica;
  4. cancella l'account da Firebase Auth.

---

## 3. Posizione obbligatoria

**Widget:** `widgets/location_gate.dart`

L'app non si usa senza posizione. Dopo login, verifica e onboarding, se il GPS è spento o il permesso manca compare una **schermata di blocco** sopra l'app:

| Situazione | Pulsante |
|---|---|
| GPS spento | **Attiva GPS**: apre le impostazioni di localizzazione |
| Permesso non ancora concesso | **Consenti accesso**: mostra la richiesta di Android |
| Permesso negato per sempre | **Apri impostazioni**: apre le impostazioni dell'app, con le istruzioni |

C'è sempre anche "Esci dall'account". Il blocco sparisce da solo appena GPS e permesso tornano attivi (l'app ricontrolla quando rientra in primo piano e quando cambia lo stato del GPS), e si riprende dalla schermata in cui si era.

---

## 4. Mappa

**Schermata:** `mappa_screen.dart`. È la scheda principale.

### 4.1 Ricerca per raggio
- La mappa mostra le segnalazioni **entro il raggio scelto** dalla posizione dell'utente, con un **cerchio** verde che lo delimita.
- **Raggi disponibili:** 1, 5, 10, 25, 50 km. Predefinito 10 km.
- **Come funziona:** Firestore non ha query geografiche native, quindi ogni segnalazione salva un **geohash** (codice che rappresenta la posizione, `core/geohash.dart`). La ricerca per cerchio diventa fino a 9 query su intervalli di geohash. I risultati vengono poi filtrati con la distanza reale (formula di Haversine) e ordinati dal più vicino.
- **Senza GPS** (caso limite): la mappa parte dall'Italia e mostra le segnalazioni più recenti.

### 4.2 Filtri per stato
- Un menu riassume la selezione ("Tutti gli stati", "Da pulire, In corso"…) e apre un pannello con tre gruppi, ciascuno con il suo colore:

  | Gruppo | Stati inclusi | Colore |
  |---|---|---|
  | **Da pulire** | segnalata, aperta | rosso |
  | **In corso** | in lavorazione, evento creato, pulizia in corso | arancione |
  | **Pulite** | ripulita, pulita, **solo se ripulite negli ultimi 30 giorni** | verde |

- **Predefinito:** "Da pulire, In corso". La scelta di raggio e stati viene ricordata tra una sessione e l'altra.
- **Filtro lato server:** la query chiede a Firestore solo gli stati selezionati, quindi gli stati esclusi non vengono letti (e non si pagano). Vedi [§17](#17-costi-e-ottimizzazioni).

### 4.3 Marker e raggruppamento
- **Marker:** ogni segnalazione ha un'icona e un colore in base allo stato:
  - avviso rosso: segnalata;
  - calendario blu: evento;
  - attrezzo: in corso;
  - spunta verde: pulita.
- **Gruppi:** i marker vicini sullo schermo si uniscono in un cerchio con il numero (`core/marker_clustering.dart`). Toccandolo la mappa si centra e si avvicina di due livelli di zoom.
- **Pulsante "posizione":** riporta la mappa sulla posizione GPS attuale.

### 4.4 Pannello "Vicino a te"
- Lista delle segnalazioni sotto la mappa, con miniatura, titolo, stato, distanza, data e tipo.
- Mostra il conteggio, per esempio "6 segnalazioni entro 10 km".
- **"Vedi tutte"** apre la lista a schermo intero.
- **Messaggi di lista vuota:** sono specifici, per esempio "prova ad allargare il raggio o a includere altri stati".

---

## 5. Segnalare un rifiuto

**Schermata:** `segnala_screen.dart` (pulsante centrale della barra in basso)

1. **Foto** (facoltativa): fotocamera o galleria. Prima del caricamento viene ridimensionata a massimo 1600 px, compressa in JPEG qualità 78 (circa 140 KB in media) e **ripulita da tutti i metadati EXIF**: coordinate GPS, modello del telefono, data (`services/image_processing_service.dart`). Una foto illeggibile viene rifiutata, mai caricata così com'è. Un avviso ricorda di non inquadrare volti e targhe.
2. **Posizione:** acquisita automaticamente dal GPS, con indirizzo ricavato dal geocoder di Android e precisione in metri.
3. **Tipo di rifiuto:** Discarica abusiva, Rifiuti abbandonati, Rifiuti pericolosi.
4. **Descrizione:** almeno 10 caratteri.
5. **Controllo doppioni:** se entro 30 m c'è già una segnalazione ancora da pulire o in corso, l'app chiede "Forse è già stato segnalato" e propone di aprire quella esistente ("Apri quella") o di inviare comunque ("È un altro, invia").
6. **Limite giornaliero:** massimo **10 segnalazioni al giorno** per utente. Il limite è garantito dalle regole di Firestore: ogni segnalazione incrementa, nella stessa transazione, il contatore `users/{uid}.reportQuota`, che non si può azzerare.
7. **Invio:**
   - la foto va su Storage in `report_photos/{uid}/`;
   - la segnalazione va su `reports` con stato `segnalata`, coordinate, geohash e indirizzo;
   - l'autore riceve **1 punto**.

Gli errori, per esempio una descrizione troppo corta o il GPS non disponibile, sono mostrati con messaggi comprensibili.

---

## 6. Dettaglio segnalazione

**Schermata:** `report_detail_screen.dart`

- **In alto:** foto a tutta larghezza (toccandola si apre a schermo intero), stato, tipo e distanza.
- **Informazioni:** titolo, indirizzo, data, **autore** (username, oppure niente se l'account è stato eliminato).
- **Timeline** dello stato: Segnalata → Aperta → In lavorazione → Pulita.
- **Contenuti:** descrizione, "foto dopo la pulizia", riquadro dell'evento (se c'è), mini-mappa con il punto.
- **Azioni in alto:**
  - **Condividi:** testo con stato, titolo, indirizzo e link a Google Maps.
  - **Menu ⋮:** "Segnala contenuto" e, per gli admin, le azioni di moderazione ([§14](#14-moderazione)).
- **Azioni in basso:** cambiano con lo stato e con chi guarda (vedi §7). C'è sempre anche "Apri su mappa".

---

## 6bis. "È ancora lì?" (conferma della community)

Nel dettaglio di una segnalazione *segnalata* o *aperta* di un altro utente compare la card **"È ancora lì?"**, con i pulsanti **"C'è ancora"** e **"Non c'è più"**.

- **Distanza:** si risponde solo **entro 200 m** dal punto. L'app controlla la distanza esatta, le regole un riquadro di circa 200 m.
- **Un voto per persona:** salvato in `reports/{id}/votes/{uid}`. Non si vota mai sulle proprie segnalazioni.
- **Punti:** ogni voto vale **+1 punto**.
- **"C'è ancora":** la segnalazione diventa **Aperta** e mostra "Confermata da N persone".
- **"Non c'è più" (2 voti):** la segnalazione diventa **Sparita** ed esce dalla mappa. L'autore non perde punti.
- **Moderazione → Sparite:** gli admin possono **ripristinarla** (torna *aperta* o *segnalata*) o **rimuoverla**.

Contatori sul report: `confirmations`, `goneVotes`. Voto, contatori, stato e punti vengono scritti in un'unica transazione, e le regole verificano che vadano insieme.

---

## 7. Pulizia ed eventi

Il ciclo di vita di una segnalazione:

```
segnalata ──► "Voglio pulire questa zona" ──► pulizia in corso ──► foto finale ──► ripulita
    │
    └──► "Schedula un evento" ──► evento creato ──► (il creatore) "Passa a pulizia in corso" ──► …
                                      │
                                      └──► altri utenti: "Partecipa all'evento"
```

### 7.1 Pulizia individuale
- **"Voglio pulire questa zona":** l'utente prende in carico la segnalazione, che passa a *pulizia in corso*.
- **"Segna come ripulito":** solo chi l'ha presa in carico. Chiede la **foto finale** (Storage `cleanup_photos/{reportId}/{uid}/`), poi la segnalazione diventa *ripulita* e l'utente riceve **2 punti**.

### 7.2 Eventi di pulizia di gruppo
- **"Schedula un evento":** data e ora con calendario e orologio in italiano. Gli orari passati non sono accettati. L'evento mostra creatore, data e partecipanti.
- **"Partecipa all'evento":** gli altri utenti si aggiungono alla lista dei partecipanti.
- **"Passa a pulizia in corso":** solo il **creatore dell'evento**, quando l'evento inizia. Poi si completa come una pulizia normale.

Le regole di sicurezza garantiscono che nessuno possa prendere in carico a nome di altri, completare la pulizia di un altro o modificare data e creatore di un evento.

---

## 8. Classifica e punti

**Schermata:** `classifica_screen.dart`

| Azione | Punti |
|---|---|
| Segnalazione inviata | 1 |
| Pulizia completata (con foto finale) | 2 |

- **Podio** con i primi 3 (medaglie oro, argento e bronzo), poi la lista fino al 20° posto, con punti e numero di segnalazioni.
- **"Tu":** la riga dell'utente corrente è evidenziata.
- **Classifiche incomplete:** con meno di 3 utenti compare un invito ("C'è ancora posto sul podio!").
- **Dati:** `leaderboard/{uid}` con `username` e `points`. Lo username viene aggiornato anche quando l'utente lo cambia.

---

## 9. Profilo

**Schermata:** `profilo_screen.dart`

- Foto profilo (o iniziali), username, email, badge "Email verificata".
- Contatori: segnalazioni inviate e punti.
- **Menu:**
  - Le mie segnalazioni;
  - **Moderazione** (solo admin);
  - Impostazioni;
  - Aiuto e feedback;
  - Logout;
  - Elimina account.

---

## 10. Le mie segnalazioni

**Schermata:** `mie_segnalazioni_screen.dart`

Elenco delle segnalazioni dell'utente, dalla più recente, con stato e miniatura. Toccandone una si apre il dettaglio. Usa l'indice composto `uid + createdAt`.

---

## 11. Notifiche

### 11.1 Notifiche push
Inviate dalle **Cloud Functions** (`functions/index.js`, regione `europe-west1`). Ognuna viene salvata anche in `users/{uid}/notifications` e compare nella schermata Notifiche (campanella).

| Notifica | A chi | Quando |
|---|---|---|
| "🎉 Zona ripulita!" | autore della segnalazione | quando qualcun altro la segna come ripulita (`onReportCleaned`) |
| "📅 Domani si pulisce!" | partecipanti all'evento | ogni giorno alle 18:00 (ora di Roma), per gli eventi del giorno dopo (`eventReminders`) |
| "📍 Nuova segnalazione vicino a te" | utenti entro 5 km, escluso l'autore | alla creazione di una segnalazione, **al massimo una al giorno** per persona (`onReportCreated`) |

- **Tocco sulla notifica:** apre il dettaglio della segnalazione.
- **App aperta:** la notifica compare come messaggio in basso.
- **Permesso:** quello di Android 13 viene chiesto dopo l'onboarding, non sopra.
- **Logout:** il dispositivo smette di ricevere le notifiche dell'account.
- **Dati** (privati, letti solo dal proprietario e dal server):
  - `users/{uid}/devices/{token}`: token FCM del dispositivo;
  - `users/{uid}/notifyPrefs/settings`: `nearby` (on/off), posizione **arrotondata a circa 1 km** (aggiornata dalla mappa solo se ci si sposta di almeno 1 km), `lastNearbyAt` (scritto solo dal server).
- **Impostazioni → Notifiche:** interruttore "Nuove segnalazioni vicino a me". Le altre notifiche si disattivano dalle impostazioni di Android.
- **Android:** icona monocromatica `ic_notification` (il logo), colore del brand, canale "Notifiche Trashpotting".
- **Pubblicazione:** `firebase deploy --only functions`.
---

## 12. Impostazioni e tema

**Schermata:** `impostazioni_screen.dart`

- **Tema:** Chiaro, Scuro, Automatico (di sistema). Si applica subito ed è ricordato (`state/theme_controller.dart`).
- **Modalità scura:** testi, card e superfici usano una palette che cambia con il tema (`theme/app_palette.dart`), così tutto resta leggibile.

---

## 13. Aiuto e feedback

**Schermata:** `aiuto_feedback_screen.dart`

- **FAQ** espandibili: verifica di una segnalazione, significato degli stati, come si guadagnano punti, eliminazione delle proprie segnalazioni.
- **Link** all'Informativa privacy e ai Termini d'uso.
- **"Scrivici":** apre l'app di posta con destinatario `dario.berettini.eco@gmail.com`, oggetto "Feedback Trashpotting" e, in fondo, versione dell'app e ID utente.

---

## 14. Moderazione

### 14.1 Segnalare un contenuto (tutti gli utenti)
- Nel dettaglio di una segnalazione altrui: **⋮ → Segnala contenuto**.
- **Motivi:** foto o testo inappropriati, spam o segnalazione falsa, dati personali visibili, altro. Si possono aggiungere dettagli facoltativi.
- **Un solo invio per utente e contenuto:** l'id del documento è `{reportId}_{uid}`, e se si riprova l'app risponde "Hai già segnalato questo contenuto".
- **Dati:** `flags/{reportId}_{uid}`, con stato `open`.

### 14.2 Admin
- **Ruolo:** custom claim `admin: true` sul token di Firebase Auth. Non è salvato nel database, quindi l'utente non può modificarlo.
- **Gestione:** `node tool/set_admin.js add|remove|list <email>`. L'admin attuale è `polivastro123@gmail.com` (Dario).
- **Quando compare:** i poteri si vedono al successivo avvio dell'app, che rinnova il token.

### 14.3 Schermata Moderazione (solo admin)
**Schermata:** `moderazione_screen.dart`, voce "Moderazione" nel Profilo.

- **Scheda "Contenuti segnalati":** una card per ogni segnalazione ricevuta, ordinate dalla più segnalata, con autore, numero di segnalazioni e motivi. Le azioni:
  - **Apri:** porta al dettaglio;
  - **Ignora:** chiude le segnalazioni del contenuto;
  - **Rimuovi:** la segnalazione viene **archiviata** in `removedReports` (con chi l'ha rimossa e quando), poi eliminata insieme alle sue foto;
  - **Blocca autore.**
- **Scheda "Utenti bloccati":** elenco con data del blocco e pulsante **Sblocca**.
- **Dal dettaglio di qualsiasi segnalazione**, menu ⋮: "Rimuovi segnalazione" e "Blocca autore".

### 14.4 Utente bloccato
- **Come si blocca:** l'admin imposta `blocked: true` su `users/{uid}`.
- **Cosa vede l'utente:** l'app ascolta il proprio profilo in tempo reale e mostra subito **"Account sospeso"**, con l'indirizzo per contestare.
- **Cosa non può fare:** le regole gli impediscono di creare segnalazioni, partecipare o pulire e guadagnare punti. Può ancora fare login e leggere.

---

## 15. Sicurezza: regole Firestore e Storage

Le regole (`firestore.rules`, `storage.rules`) sono valutate **dai server di Google a ogni richiesta**: rispondono sì o no, e non si possono aggirare modificando l'app. Si pubblicano con `firebase deploy --only firestore:rules,storage`.

**Firestore:**

| Collezione | Lettura | Scrittura |
|---|---|---|
| `users/{uid}` | utenti loggati | il proprietario modifica solo `username`, `onboardingComplete` e le date, mai `email` né `blocked`. L'admin modifica solo `blocked`, `blockedAt`, `blockedBy` |
| `users/{uid}/notifications` | solo il proprietario | solo il campo `read` |
| `reports/{id}` | utenti loggati | creazione solo a proprio nome e con stato `segnalata`. Modifiche limitate a 4 operazioni (presa in carico, pulizia completata, evento, partecipazione) più l'anonimizzazione. Eliminazione solo admin |
| `leaderboard/{uid}` | utenti loggati | solo la propria riga, +0, +1 o +2 punti per volta |
| `flags/{id}` | admin; l'utente solo la propria | creazione una per contenuto; gestione solo admin |
| `removedReports/{id}` | solo admin | solo admin |

**Condizioni comuni:** per contribuire servono **email verificata** e **account non bloccato**. Ogni operazione accetta solo i campi previsti.

**Storage:** ognuno carica solo nella propria cartella, solo immagini, al massimo 5 MB. Proprietario e admin possono cancellare.

**Test:** `cd tool/rules_test && npm test` avvia l'emulatore di Firestore e Storage ed esegue 21 scenari, sia permessi sia vietati.

---

## 16. Dati su Firestore

| Collezione | Campi principali |
|---|---|
| `users/{uid}` | `username`, `onboardingComplete`, `blocked`, `blockedAt`, `blockedBy`, `reportQuota {day, count}`, `termsVersion`, `termsAcceptedAt`, `createdAt`, `updatedAt` |
| `reports/{id}` | `note`, `photoUrl`, `latitude`, `longitude`, `geohash`, `address`, `type`, `uid` (autore), `status`, `createdAt`, `cleaningOwner`, `cleaningStartedAt`, `cleanupPhotoUrl`, `cleanedAt`, `event {creator, scheduledAt, participants[]}` |
| `leaderboard/{uid}` | `username`, `points` |
| `flags/{reportId_uid}` | `reportId`, `reporterUid`, `reportAuthorUid`, `reason`, `status` (`open` / `dismissed` / `removed`), `createdAt` |
| `removedReports/{id}` | copia della segnalazione + `removedBy`, `removedAt` |

I profili incorporati nei report (`cleaningOwner`, `event.creator`, `event.participants`) contengono solo `uid` e `username`, **mai l'email**.

**Indici composti** (`firestore.indexes.json`): `uid + createdAt` (Le mie segnalazioni), `status + geohash` (mappa), `status + cleanedAt` (ripulite recenti). Si pubblicano con `firebase deploy --only firestore:indexes`.

---

## 17. Costi e ottimizzazioni

Stima con 100 utenti e 2-4 segnalazioni a settimana ciascuno: **0-1 € al mese**. Quasi tutto rientra nelle quote gratuite: Auth, Maps SDK Android, App Check, Crashlytics e geocoder di Android sono gratuiti, e Storage resta sotto i 5 GB per più di un anno.

**Ottimizzazioni attive:**
- **Filtro di stato sul server:** la mappa legge da Firestore solo gli stati selezionati.
- **Ripulite solo per 30 giorni**, al massimo 100: le segnalazioni pulite da tempo non costano più letture.
- **Foto compresse** a circa 140 KB.
- **Cache su disco delle foto** (`cached_network_image`): una foto già vista non viene riscaricata.

**Consiglio:** il piano Blaze non ha un tetto di spesa. Imposta un avviso di budget in Google Cloud (Fatturazione → Budget e avvisi).

---

## 18. Strumenti di sviluppo

| Strumento | Uso |
|---|---|
| `flutter test` | 21 test unitari e di widget (view model, error mapper, geohash, avvio app, notifiche) |
| `tool/rules_test/` | test delle regole di sicurezza sull'emulatore (`npm test`) |
| `tool/set_admin.js` | gestione degli admin (`add`, `remove`, `list`) |
| `firebase deploy --only firestore:rules,firestore:indexes,storage` | pubblicazione di regole e indici |
| `android/key.properties` + keystore di upload | firma delle build di release (file esclusi da git) |
| Branch `develop` | sviluppo; `main` per i rilasci |

---

## 18bis. Pagine legali

In `hosting/` (Firebase Hosting, `https://trashpotting-app.web.app`): `privacy`, `termini`, `eliminazione-account`. Sono i link da inserire nella scheda di Google Play. Pubblicazione: `firebase deploy --only hosting`. Gli URL usati dall'app sono in `lib/core/legal.dart`; aumentare `LegalLinks.version` quando i testi cambiano in modo rilevante.

---

## 19. Limiti noti

- **Punti:** le regole limitano ogni incremento a +1 o +2, ma non impediscono incrementi ripetuti fatti chiamando Firestore direttamente. Per chiuderlo servirebbe una Cloud Function.
- **Utente bloccato:** può ancora fare login e leggere. Per disabilitare l'accesso servirebbe sospendere l'account in Firebase Auth.
- **Ripulite recenti:** la query prende le 100 più recenti in tutto il database e filtra per distanza. Con molti utenti in città diverse andrà fatta per zona.
- **Parità in classifica:** a parità di punti l'ordine non è definito.
- **Tipo di rifiuto facoltativo:** una segnalazione può essere inviata senza tipo.
- **Pubblicazione su Play Store:** mancano ancora l'account sviluppatore, il caricamento nel test interno e la configurazione di App Check con Play Integrity.
