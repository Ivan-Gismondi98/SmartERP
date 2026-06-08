-- ============================================================
--  SMARTERP · 02_step1_fatture_permessi.sql
--  STEP 1 — Core fiscale fatture (standard italiani) + sistema
--  permessi configurabile (stile Odoo).
--
--  Eseguire DOPO 99_smarterp_post_auth.sql, una sola volta:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/02_step1_fatture_permessi.sql
--
--  Idempotente: usa IF NOT EXISTS / ON CONFLICT dove possibile.
-- ============================================================
\set ON_ERROR_STOP on

-- ============================================================
--  SEZIONE A — ANAGRAFICA CLIENTI (cessionario/committente)
--  Dati fiscali necessari per una fattura italiana valida.
-- ============================================================
create table if not exists public.customers (
  id          uuid primary key default uuid_generate_v4(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  is_company  boolean not null default true,   -- true=persona giuridica
  name        text not null,                   -- denominazione o nome+cognome
  vat_number  text,                            -- Partita IVA (11 cifre)
  tax_code    text,                            -- Codice Fiscale
  address     text,
  zip         text,                            -- CAP
  city        text,
  province    text,                            -- sigla provincia (es. RM)
  country     text not null default 'IT',      -- ISO 3166-1 alpha-2
  sdi_code    text not null default '0000000', -- Codice Destinatario SdI (7)
  pec         text,                            -- PEC destinatario
  email       text,
  phone       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists idx_customers_company on public.customers(company_id);

drop trigger if exists trg_customers_updated on public.customers;
create trigger trg_customers_updated before update on public.customers
  for each row execute function public.set_updated_at();

-- ============================================================
--  SEZIONE B — CAMPI FISCALI SU invoices e invoice_items
-- ============================================================

-- invoices.customer_id puntava a profiles: lo ripuntiamo a customers.
do $$
begin
  if exists (
    select 1 from information_schema.table_constraints
    where table_schema='public' and table_name='invoices'
      and constraint_name='invoices_customer_id_fkey'
  ) then
    alter table public.invoices drop constraint invoices_customer_id_fkey;
  end if;
end $$;

alter table public.invoices
  add constraint invoices_customer_id_fkey
  foreign key (customer_id) references public.customers(id) on delete set null
  not valid;

-- Le bozze non hanno ancora numero: il numero progressivo viene assegnato
-- solo all'emissione. Quindi invoice_number deve poter essere NULL.
alter table public.invoices alter column invoice_number drop not null;
-- Tipo documento (tracciato SdI): TD01 fattura, TD04 nota credito, ecc.
alter table public.invoices add column if not exists document_type text not null default 'TD01';
-- Anno di numerazione (la numerazione progressiva e' per anno).
alter table public.invoices add column if not exists numbering_year int;
-- Numero progressivo nella serie (intero, per ordinamento e calcolo gaps).
alter table public.invoices add column if not exists numbering_seq int;
-- Bollo (imposta di bollo, di norma 2,00 EUR su importi esenti > 77,47).
alter table public.invoices add column if not exists stamp_duty numeric(12,2) not null default 0;
-- Arrotondamento documento.
alter table public.invoices add column if not exists rounding numeric(12,2) not null default 0;
-- Metodo e condizioni di pagamento.
alter table public.invoices add column if not exists payment_method text;
alter table public.invoices add column if not exists payment_terms text;
-- Istante di emissione (numero assegnato in modo definitivo qui).
alter table public.invoices add column if not exists issued_at timestamptz;
-- Snapshot dati cliente al momento dell'emissione (immutabilita' fiscale).
alter table public.invoices add column if not exists bill_to_name text;
alter table public.invoices add column if not exists bill_to_vat text;
alter table public.invoices add column if not exists bill_to_tax_code text;
alter table public.invoices add column if not exists bill_to_address text;
alter table public.invoices add column if not exists bill_to_sdi text;
alter table public.invoices add column if not exists bill_to_pec text;

-- Righe: natura IVA per le aliquote 0 (esente/non imponibile/reverse charge)
-- e sconto riga + ordinamento.
alter table public.invoice_items add column if not exists vat_nature text;       -- N1..N7
alter table public.invoice_items add column if not exists discount_percent numeric(5,2) not null default 0;
alter table public.invoice_items add column if not exists position int not null default 0;

-- ============================================================
--  SEZIONE C — NUMERAZIONE PROGRESSIVA ATOMICA
--  Assegna il prossimo numero per (company, anno) bloccando le righe,
--  cosi' la serie e' progressiva e senza duplicati. Da chiamare
--  all'emissione della fattura.
-- ============================================================
create or replace function public.assign_invoice_number(
  p_invoice_id uuid
) returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_company uuid;
  v_year    int;
  v_seq     int;
  v_number  text;
begin
  select company_id, coalesce(numbering_year, extract(year from issue_date)::int)
    into v_company, v_year
  from public.invoices
  where id = p_invoice_id
  for update;

  if v_company is null then
    raise exception 'Fattura % inesistente', p_invoice_id;
  end if;

  -- Serializza l'assegnazione per (azienda, anno) con un advisory lock
  -- di transazione: due emissioni concorrenti non possono ottenere lo
  -- stesso numero. Si rilascia automaticamente a fine transazione.
  perform pg_advisory_xact_lock(
    hashtextextended(v_company::text || ':' || v_year::text, 42));

  select coalesce(max(numbering_seq), 0) + 1
    into v_seq
  from public.invoices
  where company_id = v_company
    and numbering_year = v_year
    and numbering_seq is not null;

  v_number := v_seq::text || '/' || v_year::text;

  update public.invoices
     set numbering_year = v_year,
         numbering_seq  = v_seq,
         invoice_number = v_number,
         status         = case when status = 'draft' then 'sent' else status end,
         issued_at      = coalesce(issued_at, now())
   where id = p_invoice_id;

  return v_number;
end;
$$;

grant execute on function public.assign_invoice_number(uuid)
  to authenticated, service_role;

-- ============================================================
--  SEZIONE D — RLS company-isolation su customers e invoice_items
--  (stesso pattern gia' usato su invoices)
-- ============================================================
alter table public.customers enable row level security;
alter table public.customers force row level security;

drop policy if exists customers_super_admin_all on public.customers;
create policy customers_super_admin_all on public.customers
  for all to authenticated
  using      (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');

drop policy if exists customers_company_isolation on public.customers;
create policy customers_company_isolation on public.customers
  for all to authenticated
  using (
        public.auth_role() in ('admin','employee')
    and company_id = public.auth_company_id()
  )
  with check (
        public.auth_role() in ('admin','employee')
    and company_id = public.auth_company_id()
  );

-- invoice_items: l'accesso segue la fattura collegata (stessa azienda).
alter table public.invoice_items enable row level security;
alter table public.invoice_items force row level security;

drop policy if exists invoice_items_super_admin_all on public.invoice_items;
create policy invoice_items_super_admin_all on public.invoice_items
  for all to authenticated
  using      (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');

drop policy if exists invoice_items_company_isolation on public.invoice_items;
create policy invoice_items_company_isolation on public.invoice_items
  for all to authenticated
  using (
    exists (
      select 1 from public.invoices i
      where i.id = invoice_items.invoice_id
        and public.auth_role() in ('admin','employee')
        and i.company_id = public.auth_company_id()
    )
  )
  with check (
    exists (
      select 1 from public.invoices i
      where i.id = invoice_items.invoice_id
        and public.auth_role() in ('admin','employee')
        and i.company_id = public.auth_company_id()
    )
  );

-- ============================================================
--  SEZIONE E — SISTEMA PERMESSI CONFIGURABILE (stile Odoo)
--  permissions: catalogo statico dei permessi.
--  role_permissions: assegnazione per ruolo, con default globale
--    (company_id = NULL) ed eventuale override per azienda.
-- ============================================================
create table if not exists public.permissions (
  code        text primary key,   -- es. 'invoices.create'
  module      text not null,      -- es. 'invoices'
  description text not null
);

create table if not exists public.role_permissions (
  id              uuid primary key default uuid_generate_v4(),
  company_id      uuid references public.companies(id) on delete cascade, -- NULL = default globale
  role            public.user_role not null,
  permission_code text not null references public.permissions(code) on delete cascade,
  allowed         boolean not null default true,
  updated_at      timestamptz not null default now()
);
-- Unicita': un solo record per (azienda|globale, ruolo, permesso).
create unique index if not exists uq_role_perm_company
  on public.role_permissions(company_id, role, permission_code)
  where company_id is not null;
create unique index if not exists uq_role_perm_global
  on public.role_permissions(role, permission_code)
  where company_id is null;

drop trigger if exists trg_role_permissions_updated on public.role_permissions;
create trigger trg_role_permissions_updated before update on public.role_permissions
  for each row execute function public.set_updated_at();

-- RLS: catalogo leggibile da tutti gli autenticati.
alter table public.permissions enable row level security;
drop policy if exists permissions_read on public.permissions;
create policy permissions_read on public.permissions
  for select to authenticated using (true);

-- role_permissions: lettura per autenticati (default globali + propria azienda);
-- scrittura solo admin/super_admin (la UI verifica anche il permesso dedicato).
alter table public.role_permissions enable row level security;

drop policy if exists role_perm_read on public.role_permissions;
create policy role_perm_read on public.role_permissions
  for select to authenticated
  using (company_id is null or company_id = public.auth_company_id()
         or public.auth_role() = 'super_admin');

drop policy if exists role_perm_write on public.role_permissions;
create policy role_perm_write on public.role_permissions
  for all to authenticated
  using (
        public.auth_role() = 'super_admin'
     or (public.auth_role() = 'admin' and company_id = public.auth_company_id())
  )
  with check (
        public.auth_role() = 'super_admin'
     or (public.auth_role() = 'admin' and company_id = public.auth_company_id())
  );

-- --- Catalogo permessi (modulo fatture + clienti + impostazioni) ---
insert into public.permissions (code, module, description) values
  ('invoices.view',   'invoices', 'Visualizzare le fatture'),
  ('invoices.create', 'invoices', 'Creare fatture'),
  ('invoices.edit',   'invoices', 'Modificare fatture in bozza'),
  ('invoices.delete', 'invoices', 'Eliminare fatture in bozza'),
  ('invoices.issue',  'invoices', 'Emettere fatture (assegna numero)'),
  ('customers.view',   'customers', 'Visualizzare i clienti'),
  ('customers.create', 'customers', 'Creare clienti'),
  ('customers.edit',   'customers', 'Modificare clienti'),
  ('customers.delete', 'customers', 'Eliminare clienti'),
  ('settings.permissions.manage', 'settings', 'Gestire i permessi dei ruoli')
on conflict (code) do update
  set module = excluded.module, description = excluded.description;

-- --- Default globali per ruolo (company_id = NULL) ---
-- admin: tutto. employee: operativita' senza delete/gestione permessi.
-- customer: nessun accesso gestionale.
insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, p.code,
  case
    when r.role = 'admin' then true
    when r.role = 'employee' then p.code not in ('invoices.delete','customers.delete','settings.permissions.manage')
    else false
  end
from public.permissions p
cross join (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;
