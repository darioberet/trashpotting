# Trashpotting — AI Design Prompt

Prompt dettagliato per tool AI di design UI (Galileo AI, Uizard, Figma AI, Canva AI).  
Basato sul codice sorgente reale dell'app: palette, tipografia e componenti estratti da `app_colors.dart` e `app_theme.dart`.

---

## Overview e contesto

Crea un redesign completo di **Trashpotting**, un'app mobile Android per la segnalazione civica di rifiuti abbandonati. Gli utenti fotografano discariche abusive, le geolocalizzano su una mappa, guadagnano punti e si sfidano in una classifica. L'app attuale usa Material 3 con Inter font, ma risulta troppo generica e "flat". Obiettivo: elevare il design a qualcosa di espressivo, moderno e distintivo — mantenendo la leggibilità e la semplicità d'uso, ma aggiungendo carattere, profondità visiva e personalità.

**Tono del brand:** Civic-tech con anima ecologista. Non "corporate verde". Non "ONG spartana". Punta a: Citymapper + Duolingo + Linear — funzionale ma con carattere, orgoglioso di essere bello.

---

## Sistema colori (palette esatta, non alterare gli hex)

```
-- Brand verde --
Primario:    #1D9E75   (verde smeraldo — CTA, icone attive, accenti)
Scuro:       #085041   (testi su sfondi verdi, hover states)
Chiaro:      #E1F5EE   (surface tinte verdi, selected states)

-- Superfici --
Bianco puro:   #FFFFFF
Beige caldo:   #F1EFE8   (input fields, card backgrounds secondari)
Divisori:      #D3D1C7

-- Testi --
Primario:     #2C2C2A   (quasi nero con calore)
Secondario:   #5F5E5A
Disabilitato: #888780

-- Stato Segnalata (rosso) --
Bg chip: #FCEBEB  |  Testo: #791F1F  |  Dot/accent: #E24B4A

-- Stato Aperta / In lavorazione (ambra) --
Bg chip: #FAEEДА  |  Testo: #633806  |  Dot: #EF9F27

-- Stato Pulita / Ripulita (verde brand) --
Bg chip: #E1F5EE  |  Testo: #085041

-- Evento creato (blu) --
Bg chip: #E6F0FF  |  Testo: #174EA6

-- Errori: #E24B4A
```

**Aggiungi al sistema** queste sfumature per dare profondità (derivate dai brand colors):

| Token | Hex | Uso |
|---|---|---|
| Hover primario | `#0D7A5A` | pressed/hover stato verde |
| Tint saturato | `#C8EDE2` | accenti secondari |
| BG alternativo | `#F7F6F2` | sfondo pagine lista |
| Gradiente hero | `linear-gradient(135deg, #1D9E75 0%, #085041 100%)` | header sezioni |
| Overlay foto | `linear-gradient(to top, rgba(8,80,65,0.85) 0%, transparent 60%)` | su immagini |

---

## Tipografia

Font: **Inter** (Google Fonts). Weight usati: 400 / 500 / 600 / 700 / 800.

| Nome | Weight | Size | Tracking | Uso |
|---|---|---|---|---|
| Display XL | 800 | 32px | -0.5px | Hero screens, onboarding |
| Heading L | 700 | 24px | -0.3px | Titoli schermata |
| Heading M | 700 | 18px | -0.2px | Sezioni, card title |
| Heading S | 600 | 15px | 0 | Sub-sezioni |
| Body L | 400 | 15px, lh 1.6 | — | Testo descrittivo |
| Body M | 400 | 13px, lh 1.5 | — | Testo secondario |
| Body S | 400 | 11px, lh 1.4 | — | Meta, date |
| Label | 500 | 12px | +0.3px | Chip, badge, label |
| Mono GPS | 500 | 11px | +0.5px | Coordinate GPS (verde) |

Regola: usare **Inter 800** sparingly per creare punti focali forti. Numeri grandi (statistiche, punteggi) in 800 con colore `#1D9E75`. Il titolo "Trashpotting" sempre in 700 con verde brand.

---

## Griglia e spazio

- Margini laterali pagina: **20px**
- Gap standard tra sezioni: **24px**
- Gap interno card: **16px**
- Raggio bordi: Cards **16px** · Bottoni **10px** · Chip **20px** · Input **10px** · Immagini **12px**
- Touch target minimo: **48×48dp**
- Bottom navigation height: **64px**

---

## Linguaggio visivo — cosa cambiare rispetto al basic

1. **Ombre sottili colorate** — `box-shadow: 0 4px 20px rgba(29,158,117,0.12)` sulle card primarie invece di bordi flat
2. **Superfici layered** — sfondo pagina `#F7F6F2`, card bianche sopra; crea gerarchia Z senza essere skeuomorfico
3. **Gradient accent bar** — linea verticale gradiente verde (3px) a sinistra delle card importanti, invece del bordo uniforme
4. **Glassmorphism controllato** — overlay su foto con `backdrop-filter: blur(12px)` + `rgba(8,80,65,0.6)`; usare solo dove c'è una foto sotto
5. **Stato vuoto illustrato** — non solo testo + icona, ma una piccola composizione geometrica (cerchi, trattini, un pin stilizzato) in verde chiaro
6. **Numerals grandi** — nelle statistiche e classifica, i numeri in Display XL creano impatto invece di body text
7. **Micro-texture** — il background `#F7F6F2` può avere un pattern noise leggero (5% opacity) per calore
8. **Marker mappa personalizzati** — cerchi colorati con bordo bianco e ombra invece dei pin generici

---

## Bottom Navigation

4 tab: **Mappa · Segnala · Classifica · Profilo**

- Sfondo bianco, bordo top `0.5px #D3D1C7`
- Tab attivo: icona `#1D9E75` + label Inter 500 10px verde scuro + pill indicator (`#E1F5EE`, raggio 20px, 56×28px centrata sull'icona)
- Tab inattivo: icona + label `#888780`
- Tab **Segnala**: FAB centrale rialzato di 8px, background `#1D9E75`, icona `add_location_alt` bianca, raggio 16px, ombra `0 4px 16px rgba(29,158,117,0.35)` — rompe il bottom bar per richiamare l'attenzione

---

## Schermata 1 — Mappa (principale)

**Layout:** Full-screen Google Map all'80% dell'altezza. Bottom sheet scorrevole dal basso.

**Mappa:**
- Stile custom "Natural" (verde attenuato, strade beige, acqua grigio-blu leggero)
- Marker personalizzati: cerchio 36px con bordo bianco 2px e ombra
  - Segnalata → `#E24B4A` + icona `warning` bianca
  - Aperta → `#EF9F27` + icona `schedule` bianca
  - In lavorazione → `#5F5E5A` + icona `build` bianca
  - Pulita → `#1D9E75` + icona `check` bianca
  - Cluster: pill `#085041` con count bianco Inter 600 11px
- Header sovrapposto (top): "Trashpotting" Inter 700 16px verde brand + contatore "23 segnalazioni" pill verde chiaro + icona notifica con badge rosso

**Bottom sheet (pannello lista):**
- Handle grigio 32×4px centrato in top, raggio 2px
- Collassato: 240px — mostra le prime 2 card
- Espanso: 75% schermo, scrollabile
- Header panel: "Nelle vicinanze" Inter 600 15px + "Vedi mappa" link verde destra
- **Card report:**
  - Thumbnail foto 72×72px, raggio 10px; se assente → placeholder geometrico verde chiaro con icona `terrain`
  - Tipo rifiuto chip + distanza "· 340 m" Inter 400 11px grigio
  - Address Inter 500 13px `#2C2C2A`, max 1 riga, ellipsis
  - Data Inter 400 11px `#5F5E5A` + status badge (dot colorato + testo)
  - Chevron `#D3D1C7` destra
  - Accent bar sinistra 3px: verde se pulita · rosso se segnalata · ambra se aperta
  - Separatore tra card `0.5px #D3D1C7` con indent 88px

---

## Schermata 2 — Segnala rifiuti

**Zona foto (top, full-width):**
- Vuoto: container 200px, `#F1EFE8` bg, bordo `2px dashed #D3D1C7`, raggio 16px. Centro: icona `camera_alt` 40px verde + "Scatta o scegli una foto" Inter 600 15px + "La foto aiuta la verifica" Inter 400 12px grigio
- Con foto: immagine 220px full-width, raggio 16px. Overlay bottom glassmorphism `rgba(8,80,65,0.7)` 32px con "Tocca per cambiare foto" Inter 500 11px bianco + icona `edit`

**Chip GPS:**
- Card `#E1F5EE`, raggio 10px, padding 12×10px
- Dot pulsante animato `#1D9E75` (spinner se acquiring)
- "Via Roma 12, Milano" Inter 600 13px `#085041` + "GPS · precisione ±4m" Inter 400 11px `#5F5E5A`
- Icona `refresh` verde destra
- Se non acquisito: card `#F1EFE8`, skeleton animation

**Selettore tipo rifiuto:**
- Label: "TIPO DI RIFIUTO" Inter 500 12px `#5F5E5A` uppercase ls 0.5px
- 3 chip con icona:
  - "Rifiuti abbandonati" + icona `delete_sweep`
  - "Discarica abusiva" + icona `warning_amber`
  - "Rifiuti pericolosi" + icona `dangerous`
- Non selezionato: `#F1EFE8` bg, bordo `0.5px #D3D1C7`, testo `#5F5E5A`, raggio 10px
- Selezionato: `#1D9E75` bg, bianco, ombra `0 2px 8px rgba(29,158,117,0.3)`

**Campo descrizione:**
- Label Inter 500 12px + TextArea 4 righe `#F1EFE8` bg, raggio 10px
- Focus: bordo `1.5px #1D9E75`
- Counter "0 / 300" Inter 400 11px `#888780` bottom-right

**Notice moderazione:**
- Card `#FAEEДА`, raggio 10px, padding 12px. Dot `#EF9F27` + "La tua segnalazione sarà visibile dopo la verifica." Inter 400 12px `#633806`

**Sticky bottom bar:**
- Sfondo bianco, bordo top `0.5px #D3D1C7`, ombra `0 -4px 20px rgba(0,0,0,0.06)`
- Bottone "Invia segnalazione" full-width, h 52px, raggio 10px, Inter 600 15px, icona `send` 18px sinistra
- Invio in corso: bg `#0D7A5A`, "Invio in corso..." + spinner bianco 16px

---

## Schermata 3 — Dettaglio segnalazione

**Hero fotografico:**
- Foto full-bleed 300px (16:9 crop)
- Overlay: `linear-gradient(to top, rgba(8,80,65,0.9) 0%, rgba(8,80,65,0.3) 40%, transparent 70%)`
- Sovrapposto sull'overlay: badge status + tipo rifiuto chip + distanza
- Back button: cerchio 40px `rgba(0,0,0,0.3)` backdrop-blur, icona `arrow_back` bianca, top-left
- Share button: stesso stile, icona `ios_share`, top-right

**Body (sotto foto):**
- Card bianca, raggio top 20px, overlap sulla foto di 16px
- Indirizzo: Inter 700 22px `#2C2C2A`, max 2 righe
- Meta-row: dot colorato + stato Inter 500 13px + · + data Inter 400 13px + · + autore
- Divider `0.5px #D3D1C7`

**Timeline stati (elemento chiave):**
- Stepper orizzontale: Segnalata → Aperta → In lavorazione → Pulita
- Step completato: cerchio 24px verde pieno + label Inter 500 10px sotto
- Step futuro: cerchio 24px outline grigio + label grigio
- Step attuale: cerchio 28px verde pieno + bordo 3px bianco + ombra verde
- Connettore: linea 2px verde se passato, grigio se futuro

**Mappa snippet:**
- Card 160px altezza, raggio 12px, overflow hidden
- Google Maps centrato sul pin, zoom fisso, non interattivo
- Pin custom verde con shadow

**Bottom actions:**
- "Confermo presente" — outline verde, icona `thumb_up_outlined`, Inter 500 14px verde, flex 1
- "Non più presente" — outline grigio, icona `check_circle_outline`, testo grigio, flex 1

---

## Schermata 4 — Classifica

**Header:**
- Gradiente `#1D9E75 → #085041`, altezza 200px
- "Classifica" Inter 800 28px bianco, ls -0.5px
- "Top contributor del territorio" Inter 400 14px `rgba(255,255,255,0.75)`
- Selector "Questo mese | Sempre": pill attivo `rgba(255,255,255,0.25)`, inattivo trasparente

**Podio top 3 (dentro l'header):**
- 2° sinistra | 1° centro rialzato 16px | 3° destra
- Avatar cerchio 52px (1°) / 44px (2°,3°), bordo 3px oro `#F5C518` / argento `#C0C0C0` / bronzo `#CD7F32`
- Medaglia badge 20px in basso-destra dell'avatar
- Nome Inter 600 12px bianco, centrato
- Punti Inter 700 15px bianco + icona `emoji_events` 12px

**Lista dal 4° posto:**
- Sfondo `#F7F6F2`, card bianche raggio 16px
- Ogni riga h 64px, padding 16px:
  - Rank Inter 700 18px `#D3D1C7` (width 32px fisso)
  - Avatar cerchio 40px
  - Nome Inter 600 14px + "X segnalazioni" Inter 400 12px `#5F5E5A`
  - Punti Inter 700 16px `#1D9E75` + "pt" Inter 500 11px `#085041` destra
  - Riga utente corrente: bg `#E1F5EE`, bordo left 3px `#1D9E75`
- Separatore `0.5px #D3D1C7` indent 60px

---

## Schermata 5 — Profilo

**Hero:**
- Sfondo `#F7F6F2`
- Avatar cerchio 80px, bordo 3px bianco, ombra `0 4px 16px rgba(0,0,0,0.12)`
- Con foto Firebase: NetworkImage. Senza: gradiente `#1D9E75 → #085041` + iniziali Inter 700 28px bianco
- Nome Inter 700 22px `#2C2C2A`, centrato
- Email Inter 400 13px `#5F5E5A`, selezionabile
- Badge "Email verificata": pill `#E1F5EE` + dot verde + Inter 500 11px `#085041`

**Card statistiche:**
- Card bianca, raggio 16px, padding 20px, ombra `0 2px 12px rgba(0,0,0,0.06)`
- 2 colonne separate da `1px #D3D1C7` verticale
- Icona 22px `#1D9E75` → valore Inter 800 32px `#1D9E75` → label Inter 500 12px `#5F5E5A`
- Sinistra: `add_location_alt` + segnalazioni
- Destra: `emoji_events` + punti
- Loading: skeleton animation pulse

**Lista azioni:**
- Card bianca raggio 16px
- Ogni ListTile h 56px: icona outlined `#5F5E5A` + Inter 500 14px `#2C2C2A` + chevron `#D3D1C7`
- "Elimina account": icona `delete_forever` + testo `#E24B4A`

---

## Schermate Auth (Login / Register)

**Login:**
- Sfondo bianco puro
- Top 200px: gradiente `#1D9E75 → #085041` con wave SVG bottom edge verso il bianco
- Sull'onda: logo pin 32px bianco + "Trashpotting" Inter 800 26px bianco, centrati
- Sotto il wave: "Bentornato" Inter 700 22px + "Accedi per continuare a fare la differenza" Inter 400 14px `#5F5E5A`
- Input `#F1EFE8` bg, raggio 10px, label floating Inter 500 12px
- "Password dimenticata?" align right, Inter 500 13px `#1D9E75`
- CTA "Accedi" full-width h 52px, raggio 10px, verde pieno, Inter 600 15px
- Footer "Non hai un account? Registrati" centrato, link verde

---

## Stati vuoti e loading

**Empty state:**
- Composizione geometrica: 3 cerchi sovrapposti `#E1F5EE` + pin icon `#1D9E75` al centro
- "Nessuna segnalazione nelle vicinanze" Inter 600 16px
- "Sei il primo a tenere d'occhio questa zona." Inter 400 13px `#5F5E5A`
- Bottone outlined verde "Aggiungi la prima"

**Skeleton loading:**
- Pulse animation `#F1EFE8 → #D3D1C7 → #F1EFE8` loop 1.2s
- Card: rettangolo 72px thumbnail + 3 barre testo

**Error state:**
- Icona `wifi_off` o `error_outline` `#E24B4A` 40px + testo + bottone "Riprova" outlined

---

## Dark mode

| Token | Light | Dark |
|---|---|---|
| Background | `#FFFFFF` | `#141412` |
| Surface card | `#FFFFFF` | `#1E1E1C` |
| Surface secondaria | `#F1EFE8` | `#262624` |
| Testo primario | `#2C2C2A` | `#EEEDEB` |
| Testo secondario | `#5F5E5A` | `#AAAA9E` |
| Divider | `#D3D1C7` | `#3A3A32` |
| Input bg | `#F1EFE8` | `#242422` |
| Verde brand | `#1D9E75` | `#1D9E75` (invariato) |
| Verde chiaro | `#E1F5EE` | `#1D9E75` a 15% opacity |

---

## Cosa evitare

- Ombre nere pesanti
- Colori saturi fuori palette
- Cards con bordi troppo evidenti (preferire ombra + separatore sottile)
- Bottoni secondari con testo piccolo
- Placeholder generici — ogni empty state deve essere contestuale
- Bottom navigation troppo alta o icone sovradimensionate
- Chip pill ovali uniformi — raggio 10px per i selettori di tipo
- Hero gradiente su ogni schermata — solo Mappa e Classifica

---

## Output richiesto

7 schermate su device frame **Pixel 8** (393×851pt), dark + light variant, esportate come PDF e PNG @2x:

1. Mappa (con bottom sheet espanso)
2. Segnala (form compilato con foto e GPS)
3. Dettaglio segnalazione (con timeline stati)
4. Classifica (con podio)
5. Profilo (con statistiche caricate)
6. Login
7. Empty state mappa

---

*Prompt generato da Claude Code — basato sul sorgente reale di Trashpotting v3.*
