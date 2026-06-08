# SmartERP

ERP multi-tenant in stile Odoo (ridotto), ottimizzato per **Android, iOS e Web**.
Backend interamente **self-hosted su Supabase** (PostgreSQL, GoTrue, PostgREST,
Storage, Realtime) dockerizzato; frontend in **Flutter**.

---

## Stack tecnologico

| Livello        | Tecnologia                                              |
|----------------|---------------------------------------------------------|
| Database       | PostgreSQL 15 (`supabase/postgres`)                     |
| Auth           | GoTrue                                                  |
| API REST       | PostgREST                                               |
| File storage   | Supabase Storage                                        |
| Realtime       | Supabase Realtime (WebSocket)                           |
| API Gateway    | Kong (espone tutto su `:8000`)                          |
| Admin DB       | Adminer (`:8080`)                                       |
| Frontend       | Flutter (`supabase_flutter`)                            |

---

## Architettura e DevOps

### Persistenza dei dati (polizza anti-perdita)
Tutti i dati critici (magazzino, fatture, chat, file) sono salvati su
**named volumes Docker con driver locale**, dichiarati in fondo a
`docker-compose.yml`:

- `smarterp_db_data` -> `/var/lib/postgresql/data` (intero database)
- `smarterp_storage_data` -> `/var/lib/storage` (file/allegati)

I named volumes risiedono fisicamente sull'hard disk dell'host e
**sopravvivono** a `docker compose down`, ai riavvii e agli aggiornamenti
delle immagini. I dati si cancellano **solo** con il comando esplicito
`docker compose down -v`. Questo elimina alla radice il rischio di perdere
lo storico al riavvio o al blackout del server.

### Ordine di boot e resilienza
- Ogni servizio core ha `restart: always`: dopo un crash, un riavvio del
  server o un blackout, Docker rimette in piedi i container automaticamente.
- Il container PostgreSQL espone un **healthcheck** basato su `pg_isready`:
  e' considerato *healthy* solo quando accetta connessioni reali.
- Auth, REST, Realtime e Storage usano
  `depends_on: { condition: service_healthy }`: **non partono finche' il DB
  non e' davvero pronto**, evitando i classici crash a catena al boot.
- Kong (gateway) si avvia dopo i micro-servizi e instrada la porta `:8000`.

### Endpoint unificato
L'SDK Flutter richiede un singolo URL. Kong unifica i servizi sotto `:8000`:
`/auth/v1`, `/rest/v1`, `/realtime/v1`, `/storage/v1`.

---

## Stato attuale di debug / todo

Controlli già eseguiti:
- Verificato Flutter SDK e PATH (3.44.1).
- Eseguito `flutter pub get` e risolte le dipendenze.
- Verificato `docker compose up -d` e stack locale attivo.
- Verificato `flutter devices` con Edge/web disponibile.
- Eseguito il test widget smoke e passato.
- Avviato il debug web su Edge/porta 8090 per la verifica browser.

Causa individuata (08/06/2026):
- **L'app non mostrava nulla perche' veniva avviata con `-d chrome`, ma su
  questa macchina Chrome non e' installato** (solo Edge + Windows desktop).
  Flutter usciva con *"No supported devices found"* senza aprire nulla.
  Soluzione: usare `-d edge` (o `-d web-server`) / la config VS Code dedicata.
- Backend verificato OK: `GET /rest/v1/companies` risponde `200` con la company
  demo e il preflight CORS ritorna `Access-Control-Allow-Origin: *`.
- `main.dart` reso difensivo: `Supabase.initialize` e' in try/catch e l'app si
  avvia comunque mostrando l'errore in pagina (niente piu' schermo bianco muto).

Rimanenti da riprendere:
- Se serve, implementare un login demo locale reale per test funzionali.

## Avvio rapido

### 1. Prerequisiti
- Docker Desktop / Docker Engine + Compose v2
- Flutter SDK >= 3.3

### 2. Configura le variabili d'ambiente
```bash
cp .env.example .env
# Modifica POSTGRES_PASSWORD, JWT_SECRET e (in prod) rigenera ANON/SERVICE key
```

### 3. Avvia l'infrastruttura
```bash
docker compose up -d
```

### 4. Avvia l'app Flutter
```bash
cd app
flutter pub get
# Verifica prima quali device hai: flutter devices
# Usa il device disponibile (es. su questa macchina e' Edge, non Chrome):
flutter run -d edge --dart-define-from-file=config/dev.json
# In alternativa, senza browser specifico:
# flutter run -d web-server --dart-define-from-file=config/dev.json
```

> Nota: il comando `-d chrome` funziona solo se Chrome e' installato. Se
> `flutter run -d chrome` stampa *"No supported devices found"*, l'app non
> parte affatto (pagina vuota): scegli un device presente in `flutter devices`
> (es. `edge`). In VS Code usa la configurazione **SmartERP · Edge (dev)** del
> file `.vscode/launch.json`.

---

## Gestione e verifica dei container

| Azione                          | Comando                                            |
|---------------------------------|----------------------------------------------------|
| Avviare tutto in background     | `docker compose up -d`                             |
| Spegnere (DATI SALVI)           | `docker compose down`                              |
| Spegnere ED ELIMINARE i dati    | `docker compose down -v`                           |
| Stato + healthcheck             | `docker compose ps`                                |
| Log in tempo reale              | `docker compose logs -f`                           |
| Log di un servizio              | `docker compose logs -f supabase-db`               |
| Riavviare un servizio           | `docker compose restart supabase-rest`             |
| Aggiornare le immagini          | `docker compose pull && docker compose up -d`      |
| Salute del DB (manuale)         | `docker exec smarterp-db pg_isready -U postgres`   |

**Interfacce web:**
- API Gateway: http://localhost:8000
- Adminer (DB): http://localhost:8080 -> Server `supabase-db`, user `postgres`,
  password = `POSTGRES_PASSWORD` del `.env`, database `smarterp`.

---

## Sicurezza & Multi-tenant (RLS)
La tabella `invoices` ha la **Row Level Security** attiva:
- `super_admin` (sviluppatore): accesso globale completo.
- `admin` / `employee`: vedono e modificano **solo** le fatture del proprio
  `company_id`.
- Il ruolo tecnico `service_role` bypassa nativamente la RLS (uso server-side).

ATTENZIONE: le chiavi `ANON_KEY` / `SERVICE_ROLE_KEY` nel `.env.example` sono
le chiavi **demo pubbliche** di Supabase. **Rigenerale** per qualsiasi ambiente
reale (firmandole con il tuo `JWT_SECRET`) e aggiorna di conseguenza
`volumes/api/kong.yml`.

---

## Cosa manca da fare (roadmap)

### Backend / DB
- [ ] Estendere la RLS alle altre tabelle (`products`, `inventory`,
      `chat_*`, `suppliers`) con lo stesso pattern company-isolation.
- [ ] Trigger DB per il **calcolo automatico dei totali** fattura
      (`subtotal`, `tax_amount`, `total`) a partire da `invoice_items`.
- [ ] Creare i **bucket Storage** (`avatars`, `invoices-pdf`, `chat-files`)
      con le relative policy.
- [ ] Seeding utenti/ruoli demo via GoTrue Admin API.

### Logica applicativa Flutter
- [x] **Chat realtime (STEP 8)**: stanze chat per azienda con messaggi in
      **streaming** (`chat_messages.stream(primaryKey:['id']).eq('room_id')`),
      invio messaggi, bolle mittente, RLS company-isolation. **Videochiamate**
      via Jitsi Meet (link per-stanza), mostrate solo se attivate da
      *Impostazioni → Chat* e con permesso `chat.video`. Gated da `chat.*`.
- [~] **Fatturazione (STEP 1 — core fiscale)**: anagrafica clienti con dati
      fiscali (P.IVA con checksum, CF, Codice Destinatario SdI, PEC), fatture
      con righe, **IVA calcolata per aliquota** (riepilogo SdI) + codici
      **Natura** (N1–N7) per le righe a 0%, **bollo** €2 automatico oltre
      €77,47 di esente, arrotondamenti a 2 decimali, formattazione € it_IT,
      **numerazione progressiva per anno** assegnata all'emissione (RPC atomica
      con advisory lock). Tutte le azioni sono **gated da permessi** (vedi sotto).
- [~] **Fatturazione (STEP 2 — gestione interna)**: ricerca e filtri per stato
      sulla lista, **KPI di riepilogo** (documenti, emesso netto, incassato,
      scadute), evidenza fatture **scadute** (oltre la data di scadenza),
      **note di credito (TD04)** collegate alla fattura d'origine, **duplica
      documento**, ricerca clienti.
- [x] **Fatturazione (STEP 3 — export XML FatturaPA)**: generazione dell'XML
      Fattura Elettronica (tracciato SdI `FatturaElettronica v1.2.2`) —
      `DatiTrasmissione`, `CedentePrestatore` (dati fiscali azienda),
      `CessionarioCommittente`, `DatiGeneraliDocumento` (con `DatiBollo`),
      `DettaglioLinee` (con `ScontoMaggiorazione`/`Natura`) e `DatiRiepilogo`
      per aliquota. Anteprima in-app + **copia** e **download `.xml`**
      (nome file `IT<piva>_<progressivo>.xml`). Azione gated da
      `invoices.export`.
      > L'XML **non** è firmato digitalmente (`.p7m`): firma qualificata e
      > invio allo SdI restano passaggi esterni (accreditamento).
- [x] **Permessi configurabili (stile Odoo)**: tabelle `permissions` /
      `role_permissions` (default globali + override per azienda), schermata
      *Impostazioni → Permessi* per attivare/disattivare i permessi per ruolo.
- [x] **Impostazioni & SdI (STEP 6)**: sistema impostazioni gerarchico —
      **generali** + **per-applicativo** (`app_settings` chiave/valore per
      azienda con RLS); permessi divisi tra **generici** (CRUD) e **di feature**
      (`permissions.kind`). **Feature toggle** per mostrare/nascondere il blocco
      **firma/invio SdI** nel dettaglio fattura (gated anche da
      `invoices.sdi_send`); stato trasmissione locale (`sdi_status`).
      > La firma qualificata e l'invio reale allo SdI sono esterni
      > (accreditamento); l'app registra lo stato localmente.
- [~] **Fatturazione (STEP 4 — stampa & scadenze)**: **stampa PDF** della
      fattura (`pdf`+`printing`, anteprima con stampa/download anche su web),
      **termini di pagamento in giorni** che calcolano la scadenza, e
      **interessi di mora** configurabili (tasso annuo) calcolati sul ritardo
      per le fatture scadute (mostrati in dettaglio e in PDF). Stampa gated da
      `invoices.print`.
- [~] **Catalogo / media prodotto (STEP 9)**: ogni prodotto può avere
      **immagine** (URL) e **descrizione** + toggle *"mostra nei documenti"*.
      Nel PDF le righe con flag usano un **layout catalogo** (titolo → immagine
      a sx, descrizione a dx + qtà/prezzo/totale); la descrizione è editabile
      dalla riga fattura.
- [~] **App "Studio" (STEP 10)**: modelli grafici salvabili (`document_templates`)
      per i documenti — testo header/footer, logo on/off, colore override,
      stile righe (auto/catalogo/compatto), riepilogo IVA on/off, modello
      predefinito. Si sceglie il modello (Standard o salvato) dentro la fattura
      (`invoices.template_id`) e viene applicato al PDF. Gated da `studio.*`.
- [~] **Export Word .docx (STEP 11)**: generazione di un documento Word
      (pacchetto OOXML costruito e zippato con `archive`) della fattura,
      rispettando il modello Studio (header/footer/colore/stile righe/riepilogo).
      Pulsante **Word** nel dettaglio (gated `invoices.print`). Le immagini
      prodotto in Word sono una rifinitura successiva (nel PDF già incluse).
- [~] **Branding per-tenant nei PDF (STEP 7)**: colori e logo presi da
      `companies.theme_settings` applicati al PDF fattura (intestazione, linea,
      totali, logo). Pagina *Impostazioni → Branding aziendale* per impostarli
      (gated da `settings.company.manage`). Resta: template Word (`docx_template`)
      e branding del tema app.
- [x] **Magazzino/Prodotti (STEP 5)**: CRUD prodotti con **giacenze**
      (`inventory`), badge giacenza + evidenza **sotto scorta**, ricerca e
      filtro, RLS company-isolation. Riga fattura collegabile a un prodotto e
      **scarico automatico atomico** della giacenza all'emissione (le note di
      credito **reintegrano**), con guard anti-doppia emissione. Gated da
      `products.*`.
      Restano: alert/notifica push sotto `reorder_level` e ordini di riordino.
- [x] **Distinta base / Prodotti componibili (STEP 5b)**: un prodotto può
      essere **componibile** con una **distinta base** (`bom_components`:
      componente + quantità). Azione **Produci N** (RPC `produce_product`
      atomica): consuma i componenti dal magazzino e incrementa il finito,
      con verifica disponibilità (errore se un componente è insufficiente).
      Es.: 500 travi → produci 10 sedie (4 travi/cad) → travi 460, sedie 10.
      Gated da `products.produce`.
- [x] **Gestione sessione/auth**: login/registrazione (GoTrue), refresh token
      automatico, routing protetto con redirect (`go_router`). Utente demo:
      `admin@smarterp.local` / `Demo1234`.
- [x] **State management** (Riverpod) e repository layer
      (`features/<dominio>/{data,domain,application,presentation}`).
- [ ] Profilazione moduli per ruolo + schermate vere dei moduli (oggi
      placeholder nella dashboard).

### Area Sviluppatore / multi-tenant (in corso)
- [x] **Logging errori + "Bug del giorno" (STEP 12)**: ogni errore dell'app
      (handler globali `FlutterError`/`PlatformDispatcher` + `ErrorLogger`) viene
      registrato in `error_logs` e consultabile in-app. Pagina **Bug del giorno**
      con filtri **gravità/periodo/testo**. RLS: super_admin vede tutte le
      organizzazioni, admin solo la propria. Utente sviluppatore demo:
      `dev@smarterp.local` / `Dev12345` (ruolo super_admin). Gated `errors.view`.
- [x] **Licenze + Dashboard Sviluppatore (STEP 13)**: tabelle `licenses`,
      `license_payments`, `tickets` (RLS: super_admin tutto, admin propria org).
      **Dashboard** con KPI organizzazioni/licenze attive/incassato/licenze in
      ritardo, **bug per gravità** (30gg) e **ticket per stato**; gestione
      licenze (CRUD) e registrazione pagamenti. Gated `dev.dashboard`/`licenses.manage`.
- [ ] **CRUD utenti/ruoli/permessi/aziende** (superadmin) via RPC sicure.
- [ ] **Notifiche realtime** ("Notifica" dipendente→admin, admin→sviluppatore),
      **ticket** con stato di avanzamento, **chat diretta admin↔sviluppatore**
      con allegati, **export Excel** segnalazioni.

### DevOps
- [ ] Reverse proxy HTTPS (Caddy/Traefik) + certificati per la produzione.
- [ ] Backup automatici schedulati di `smarterp_db_data` (`pg_dump`).
- [ ] Monitoraggio/health dashboard e log centralizzati.
- [ ] CI/CD (build APK/IPA/Web + deploy stack).
