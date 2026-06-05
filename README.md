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
flutter run -d chrome --dart-define-from-file=config/dev.json
```

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
- [ ] **Service chat realtime in streaming**: sottoscrizione
      `supabase.from('chat_messages').stream(primaryKey: ['id'])` filtrata per
      `room_id`, con invio messaggi e indicatore "sta scrivendo".
- [ ] **Motore di stampa client-side**: usare i pacchetti `pdf` + `printing`
      per i PDF e `docx_template` per i documenti Word, iniettando i colori e
      il logo presi da `companies.theme_settings` (branding per-tenant).
- [ ] **Scarico magazzino alla vendita**: alla conferma di una fattura,
      decrementare `inventory.quantity` per ogni `invoice_item`
      (idealmente in una transazione/funzione RPC PostgreSQL per atomicita') e
      gestire l'alert sotto `reorder_level`.
- [ ] **Gestione sessione/auth**: schermate login/registrazione, refresh token,
      routing protetto per ruolo.
- [ ] **State management** (Riverpod/Bloc) e repository layer.

### DevOps
- [ ] Reverse proxy HTTPS (Caddy/Traefik) + certificati per la produzione.
- [ ] Backup automatici schedulati di `smarterp_db_data` (`pg_dump`).
- [ ] Monitoraggio/health dashboard e log centralizzati.
- [ ] CI/CD (build APK/IPA/Web + deploy stack).
