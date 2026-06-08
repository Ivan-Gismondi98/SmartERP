# PRIMI PASSI — Guida operativa SmartERP

Guida passo-passo, in ordine, per:
1. inizializzare Git e pubblicare il progetto su **GitHub**;
2. avviare il **backend Docker** (Supabase self-hosted);
3. verificare lo **stato di salute** dei container;
4. avviare l'**app Flutter** e ottenere un **test locale riuscito**;
5. risolvere i problemi piu' comuni.

> Tutti i comandi sono pensati per **Windows / PowerShell**.
> La cartella di lavoro del progetto e':
> `C:\Users\IvanGismondi\Documents\mio\smarterp`
>
> Apri un terminale PowerShell e posizionati qui PRIMA di iniziare:
> ```powershell
> cd C:\Users\IvanGismondi\Documents\mio\smarterp
> ```

---

## FASE 0 — Prerequisiti (verifica una sola volta)

Controlla di avere gli strumenti installati. Lancia:

```powershell
git --version
docker --version
docker compose version
flutter --version
```

Se manca qualcosa:
- **Git**: https://git-scm.com/download/win
- **Docker Desktop** (include Compose v2): https://www.docker.com/products/docker-desktop/
  -> dopo l'installazione AVVIA Docker Desktop e attendi che l'icona diventi verde ("Engine running").
- **Flutter**: https://docs.flutter.dev/get-started/install/windows
- (Opzionale ma consigliato) **GitHub CLI** `gh`: https://cli.github.com/
  -> serve a creare il repo su GitHub da terminale senza passare dal sito.

---

## FASE 1 — Inizializzazione Git e PRIMO COMMIT

> Il file `.gitignore` e' gia' presente e proteggera' automaticamente il file
> `.env` (segreti) dal finire su GitHub. Verra' invece tracciato `.env.example`.

```powershell
# 1.1 Inizializza il repository e imposta 'main' come branch di default
git init
git branch -M main

# 1.2 Configura la tua identita' (se non l'hai gia' fatto a livello globale)
git config user.name  "Ivan Gismondi"
git config user.email "ivan.gismondi@talete.net"

# 1.3 Aggiungi tutti i file (il .gitignore esclude .env e i segreti)
git add .

# 1.4 CONTROLLO DI SICUREZZA: verifica che il file .env NON sia tra i file in stage.
#     Nell'elenco devi vedere .env.example MA NON .env
git status
```

Se in `git status` NON compare `.env` (ma solo `.env.example`), procedi:

```powershell
# 1.5 Primo commit strutturato (Conventional Commits)
git commit -m "feat: initial project structure and robust docker setup"
```

---

## FASE 2 — Pubblicazione su GitHub

Hai due strade. **La A e' la piu' veloce.**

### STRADA A — con GitHub CLI (consigliata)

```powershell
# 2.A.1 Autenticati su GitHub (apre il browser; segui le istruzioni)
gh auth login

# 2.A.2 Crea il repository su GitHub e collega il remote in un colpo solo.
#       --private = repo privato (consigliato finche' contiene config).
#       --source=.  usa la cartella corrente; --push carica subito il commit.
gh repo create smarterp --private --source=. --remote=origin --push
```

Fatto: il repo e' online. Salta alla **Fase 3**.

### STRADA B — manuale (dal sito GitHub)

1. Vai su https://github.com/new
2. **Repository name**: `smarterp`
3. Visibilita': **Private** (consigliato).
4. **NON** spuntare "Add a README" / "Add .gitignore" (li abbiamo gia' noi),
   altrimenti dovrai fare un merge.
5. Clicca **Create repository**.
6. Copia l'URL del repo (es. `https://github.com/TUO-UTENTE/smarterp.git`) e lancia:

```powershell
# Sostituisci l'URL con quello del TUO repo
git remote add origin https://github.com/TUO-UTENTE/smarterp.git
git push -u origin main
```

> Se Git ti chiede le credenziali: usa il tuo username GitHub e, come password,
> un **Personal Access Token** (Settings -> Developer settings -> Tokens),
> NON la password dell'account.

### Verifica
```powershell
git remote -v        # deve mostrare 'origin' con l'URL del tuo repo
git log --oneline    # deve mostrare il commit 'feat: initial project...'
```

---

## FASE 3 — Avvio del backend Docker

> Assicurati che **Docker Desktop sia avviato** (icona verde).
> Al primo avvio Docker scarichera' diverse immagini: puo' richiedere alcuni
> minuti, e' normale.

```powershell
# 3.1 (Se non l'hai gia') crea il file .env attivo dal template.
#     NOTA: in questo progetto il .env e' gia' incluso e pronto per il locale,
#     quindi questo passo serve solo se lo avessi cancellato.
if (-not (Test-Path .env)) { Copy-Item .env.example .env }

# 3.2 Avvia l'intero stack in background
docker compose up -d
```

Output atteso: una serie di righe con `Created` / `Started` per ogni servizio
(`smarterp-db`, `smarterp-auth`, `smarterp-rest`, `smarterp-storage`,
`smarterp-realtime`, `smarterp-kong`, `smarterp-adminer`).

---

## FASE 4 — Verifica dello STATO DI SALUTE

```powershell
# 4.1 Stato di tutti i container. Cerca la colonna STATUS.
docker compose ps
```

Cosa devi vedere:
- `smarterp-db` -> **Up (healthy)** <- questo e' il piu' importante.
- gli altri servizi -> **Up** / **running**.

```powershell
# 4.2 Verifica diretta della salute del database
docker exec smarterp-db pg_isready -U postgres
# Output atteso:  /var/run/postgresql:5432 - accepting connections

# 4.3 Verifica che lo schema sia stato creato (deve elencare le tabelle)
docker exec smarterp-db psql -U postgres -d smarterp -c "\dt public.*"
# Output atteso: companies, profiles, products, invoices, chat_messages, ecc.

# 4.4 Verifica che il gateway risponda (deve tornare un JSON, non un errore di connessione)
curl http://localhost:8000/rest/v1/ -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlLWRlbW8iLCJpYXQiOjE2NDE3NjkyMDAsImV4cCI6MTc5OTUzNTYwMH0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE"
```

### Verifica via interfaccia web (Adminer)
1. Apri il browser su **http://localhost:8080**
2. Compila:
   - **Sistema**: PostgreSQL
   - **Server**: `supabase-db`
   - **Utente**: `postgres`
   - **Password**: `super-secret-db-password-change-me` (valore di `POSTGRES_PASSWORD` nel `.env`)
   - **Database**: `smarterp`
3. Login -> dovresti vedere tutte le tabelle e, dentro `companies`, la riga demo
   "Talete Demo S.r.l.".

Se tutto questo funziona, **il backend e' OK**. Procedi all'app.

---

## FASE 5 — Avvio dell'app Flutter e TEST LOCALE

> Il progetto Flutter in `app/` contiene gia' `lib/`, `config/` e `pubspec.yaml`,
> ma NON le cartelle di piattaforma (android/ios/web). Le generiamo ora con
> `flutter create` (NON sovrascrive i file gia' presenti).

```powershell
# 5.1 Entra nella cartella dell'app
cd app

# 5.2 Genera gli scaffold di piattaforma mancanti (android, ios, web, ecc.)
#     Il '.' indica "in questa cartella". I tuoi lib/ e pubspec.yaml restano intatti.
flutter create . --platforms=android,ios,web --project-name smarterp

# 5.3 Scarica le dipendenze (supabase_flutter, pdf, ecc.)
flutter pub get

# 5.4 Controlla quali device sono disponibili
flutter devices
```

### Test su Web (la via piu' rapida per verificare la connessione)

```powershell
# 5.5 Controlla i device disponibili e usa quello presente.
#     ATTENZIONE: su questa macchina e' installato EDGE, non Chrome.
#     `-d chrome` darebbe "No supported devices found" e non aprirebbe nulla.
flutter run -d edge --dart-define-from-file=config/dev.json
# In alternativa senza browser specifico: flutter run -d web-server ...
```

**App avviata** = si apre la **schermata di login** SmartERP. Accedi con
l'utente demo:
- email: `admin@smarterp.local`
- password: `Demo1234`

Dopo il login vedi la **dashboard** con nome utente, azienda
("Talete Demo S.r.l."), ruolo (Amministratore) e i moduli del gestionale.

> Per la sola diagnostica di connessione backend (Flutter -> Kong -> PostgREST
> -> PostgreSQL) e' disponibile la rotta `/diagnostics`.

### (Solo la prima volta) Creare l'utente demo

Se il DB e' appena stato creato non esiste alcun utente. Crea il demo cosi':

```powershell
# 1) Registra l'utente via API GoTrue (autoconferma attiva -> subito usabile)
$KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlLXNtYXJ0ZXJwIiwiaWF0IjoxNzAwMDAwMDAwLCJleHAiOjIxMDAwMDAwMDB9.OFH7TLJFdZgU_DggeH_XpiL34U4Q11xArnnXFccyaCk"
curl.exe -s -X POST "http://localhost:8000/auth/v1/signup" -H "apikey: $KEY" -H "Content-Type: application/json" -d '{\"email\":\"admin@smarterp.local\",\"password\":\"Demo1234\",\"data\":{\"full_name\":\"Admin Demo\"}}'

# 2) Promuovi il profilo ad admin e collegalo all'azienda demo
docker exec smarterp-db psql -U postgres -d postgres -c "update public.profiles set role='admin', company_id='00000000-0000-0000-0000-000000000001' where id=(select id from auth.users where email='admin@smarterp.local');"
```

### (Solo la prima volta) Migrazione STEP 1 — fatture e permessi

Crea anagrafica clienti, campi fiscali fattura, numerazione progressiva e il
sistema permessi. Da eseguire DOPO `99_smarterp_post_auth.sql`:

```powershell
docker exec -i smarterp-db psql -U postgres -d postgres < volumes/db/post-init/02_step1_fatture_permessi.sql
docker exec -i smarterp-db psql -U postgres -d postgres < volumes/db/post-init/03_step2_gestione.sql
docker exec -i smarterp-db psql -U postgres -d postgres < volumes/db/post-init/04_step3_fatturapa.sql
docker exec -i smarterp-db psql -U postgres -d postgres < volumes/db/post-init/05_step4_pdf_mora.sql
docker exec -i smarterp-db psql -U postgres -d postgres < volumes/db/post-init/06_step5_magazzino.sql
docker exec -i smarterp-db psql -U postgres -d postgres < volumes/db/post-init/07_step5b_distinta_base.sql
docker exec -i smarterp-db psql -U postgres -d postgres < volumes/db/post-init/08_step6_impostazioni_sdi.sql
docker exec -i smarterp-db psql -U postgres -d postgres < volumes/db/post-init/09_step7_branding.sql
docker exec -i smarterp-db psql -U postgres -d postgres < volumes/db/post-init/10_step8_chat.sql
docker exec -i smarterp-db psql -U postgres -d postgres < volumes/db/post-init/11_step9_prodotti_media.sql
# PostgREST deve ricaricare lo schema per vedere le nuove funzioni/colonne:
docker exec smarterp-db psql -U postgres -d postgres -c "NOTIFY pgrst, 'reload schema';"
```

### Test su Emulatore Android (opzionale)

```powershell
# Avvia prima un emulatore da Android Studio, poi:
flutter run -d emulator-5554 --dart-define-from-file=config/dev.json
```

Su emulatore Android `AppConfig` usa automaticamente `http://10.0.2.2:8000`
(non `localhost`, che dentro l'emulatore punterebbe all'emulatore stesso).

---

## FASE 6 — Salvare i progressi su GitHub (dopo i primi test)

Dopo aver generato gli scaffold Flutter, committa l'avanzamento:

```powershell
# Torna nella root del progetto
cd ..

git add .
git commit -m "chore: scaffold flutter platforms and install dependencies"
git push
```

---

## CICLO DI LAVORO QUOTIDIANO (riassunto)

```powershell
cd C:\Users\IvanGismondi\Documents\mio\smarterp

docker compose up -d                 # accendi il backend
cd app
flutter run -d chrome --dart-define-from-file=config/dev.json   # lavora

# a fine giornata:
# Ctrl+C per fermare Flutter, poi:
cd ..
docker compose down                  # spegni i container (i DATI restano salvi!)
```

---

## SPEGNIMENTO E DATI

| Comando                    | Effetto                                                       |
|----------------------------|---------------------------------------------------------------|
| `docker compose down`      | Spegne i container. **I dati nel DB e i file restano salvi.** |
| `docker compose down -v`   | Spegne ED ELIMINA i volumi -> **CANCELLA tutti i dati.** Usalo solo per ripartire da zero. |
| `docker compose restart`   | Riavvia tutti i servizi senza perdere dati.                   |

Lo script SQL `00_init_smarterp.sql` viene eseguito **solo al primo avvio**
(quando il volume del DB e' vuoto). Se modifichi lo schema e vuoi riapplicarlo
da zero, devi fare `docker compose down -v` e poi `docker compose up -d`
(ATTENZIONE: cancella i dati).

---

## RISOLUZIONE PROBLEMI (Troubleshooting)

**`docker compose up` dice "Cannot connect to the Docker daemon"**
-> Docker Desktop non e' avviato. Aprilo e attendi l'icona verde.

**Porta gia' in uso (es. "port 5432 is already allocated")**
-> Hai un altro PostgreSQL/servizio sulla stessa porta. Fermalo, oppure cambia
   la porta nel `docker-compose.yml` (es. `"5433:5432"`).

**`smarterp-db` resta "health: starting" o "unhealthy"**
-> Guarda i log: `docker compose logs supabase-db`. Spesso e' solo lentezza al
   primo boot: attendi ~30s e ricontrolla con `docker compose ps`.

**L'app Flutter mostra "Errore: ..." invece di "DB raggiungibile"**
-> 1) Il backend e' acceso? `docker compose ps`.
   2) Kong risponde? Riprova il `curl` della Fase 4.4.
   3) Su Web/Chrome puo' essere un problema CORS: i log di Kong li mostrano
      (`docker compose logs supabase-kong`).

**Le tabelle non esistono in Adminer**
-> Lo script init gira solo a volume vuoto. Se avevi gia' avviato il DB prima di
   avere lo script, azzera: `docker compose down -v` e poi `docker compose up -d`.

**I WebSocket Realtime non si connettono**
-> E' il servizio piu' delicato in self-hosted. Controlla
   `docker compose logs -f supabase-realtime`. Di norma basta attendere che il
   DB sia completamente migrato; la chat live e' comunque tra le funzionalita'
   ancora da implementare (vedi README -> "Cosa manca da fare").

**Git: `.env` e' finito per sbaglio in stage**
-> `git rm --cached .env` poi committa di nuovo. Il `.gitignore` impedira'
   che ricapiti.
