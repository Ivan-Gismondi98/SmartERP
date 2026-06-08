-- ============================================================
--  SMARTERP · 00_init_smarterp.sql
--  Bootstrap COMPLETO self-contained per supabase/postgres standalone.
--
--  Ordine OBBLIGATORIO:
--    1) ruoli (PRIMA di tutto, perche' l'image ha un event trigger su
--       CREATE EXTENSION che cerca supabase_admin)
--    2) extensions
--    3) schemi + permessi
--    4) funzioni auth.* (uid/role/email per RLS)
--    5) tabelle smarterp
--    6) RLS + grants + seed
--
--  Le FK verso auth.users e il trigger handle_new_user vengono
--  applicati DOPO che GoTrue ha creato auth.users, tramite il file
--  volumes/db/post-init/99_smarterp_post_auth.sql (esecuzione manuale).
--
--  ATTENZIONE: la password 'qui8Tiv' qui sotto DEVE combaciare con
--  POSTGRES_PASSWORD del file .env. Se cambi una, cambia l'altra.
-- ============================================================
\set ON_ERROR_STOP on

-- ============================================================
--  SEZIONE 1 — RUOLI SUPABASE  (devono esistere PRIMA delle extension)
--  Pattern CREATE-or-ALTER: forziamo SEMPRE la password definita qui,
--  anche se i ruoli sono gia' stati creati dall'image (con un'altra pwd).
-- ============================================================

do $$
declare
  pwd text := 'qui8Tiv';
begin
  -- supabase_admin (superuser per migrazioni di sistema)
  if not exists (select 1 from pg_roles where rolname = 'supabase_admin') then
    execute format(
      'create role supabase_admin with login superuser createdb createrole replication bypassrls password %L',
      pwd
    );
  else
    execute format('alter role supabase_admin with password %L', pwd);
  end if;

  -- authenticator (usato da PostgREST)
  if not exists (select 1 from pg_roles where rolname = 'authenticator') then
    execute format(
      'create role authenticator with login noinherit password %L',
      pwd
    );
  else
    execute format('alter role authenticator with password %L', pwd);
  end if;

  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;

  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;

  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;

  -- supabase_auth_admin (usato da GoTrue)
  if not exists (select 1 from pg_roles where rolname = 'supabase_auth_admin') then
    execute format(
      'create role supabase_auth_admin with login createrole noinherit password %L',
      pwd
    );
  else
    execute format('alter role supabase_auth_admin with password %L', pwd);
  end if;

  -- supabase_storage_admin (usato da Storage)
  if not exists (select 1 from pg_roles where rolname = 'supabase_storage_admin') then
    execute format(
      'create role supabase_storage_admin with login createrole noinherit password %L',
      pwd
    );
  else
    execute format('alter role supabase_storage_admin with password %L', pwd);
  end if;

  -- supabase_realtime_admin (usato da Realtime)
  if not exists (select 1 from pg_roles where rolname = 'supabase_realtime_admin') then
    execute format(
      'create role supabase_realtime_admin with login replication noinherit password %L',
      pwd
    );
  else
    execute format('alter role supabase_realtime_admin with password %L', pwd);
  end if;
end
$$;

grant anon, authenticated, service_role to authenticator;
grant anon, authenticated, service_role to postgres;
grant anon, authenticated, service_role to supabase_admin;

-- ============================================================
--  SEZIONE 2 — EXTENSIONS  (ora supabase_admin esiste, event trigger ok)
-- ============================================================

create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ============================================================
--  SEZIONE 3 — SCHEMI E PERMESSI
-- ============================================================

create schema if not exists auth       authorization supabase_auth_admin;
create schema if not exists storage    authorization supabase_storage_admin;
create schema if not exists _realtime  authorization supabase_realtime_admin;
create schema if not exists extensions authorization postgres;

grant usage on schema public to anon, authenticated, service_role;
grant all   on schema public to postgres, supabase_admin;

grant usage, create on schema auth      to supabase_auth_admin;
grant usage, create on schema storage   to supabase_storage_admin;
grant usage, create on schema _realtime to supabase_realtime_admin;

alter user supabase_auth_admin     set search_path = 'auth';
alter user supabase_storage_admin  set search_path = 'storage';
alter user supabase_realtime_admin set search_path = '_realtime';

-- supabase_auth_admin deve poter creare tabelle nel DB postgres
grant create on database postgres to supabase_auth_admin;
grant create on database postgres to supabase_storage_admin;

-- ============================================================
--  SEZIONE 4 — FUNZIONI AUTH.* (usate dalla RLS, sempre disponibili)
-- ============================================================

create or replace function auth.uid()
returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

create or replace function auth.role()
returns text language sql stable as $$
  select nullif(current_setting('request.jwt.claim.role', true), '');
$$;

create or replace function auth.email()
returns text language sql stable as $$
  select nullif(current_setting('request.jwt.claim.email', true), '');
$$;

-- L'OWNER deve essere supabase_auth_admin: altrimenti GoTrue al primo
-- avvio fallirebbe il CREATE OR REPLACE di queste stesse funzioni con
-- "ERROR: must be owner of function uid (SQLSTATE 42501)".
alter function auth.uid()   owner to supabase_auth_admin;
alter function auth.role()  owner to supabase_auth_admin;
alter function auth.email() owner to supabase_auth_admin;

grant execute on function auth.uid()   to anon, authenticated, service_role;
grant execute on function auth.role()  to anon, authenticated, service_role;
grant execute on function auth.email() to anon, authenticated, service_role;

-- ============================================================
--  SEZIONE 5 — TIPI ENUM APPLICATIVI
-- ============================================================

do $$ begin
  create type public.user_role as enum ('super_admin', 'admin', 'employee', 'customer');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.invoice_status as enum ('draft', 'sent', 'paid', 'overdue', 'cancelled');
exception when duplicate_object then null; end $$;

-- ============================================================
--  SEZIONE 6 — TABELLE APPLICATIVE SMARTERP
--  Nota: profiles.id NON ha FK verso auth.users qui.
--  La FK + il trigger handle_new_user sono nel post-init script.
-- ============================================================

create table if not exists public.companies (
  id             uuid primary key default uuid_generate_v4(),
  name           text not null,
  vat_number     text unique,
  email          text,
  phone          text,
  address        text,
  theme_settings jsonb not null default
                 '{"primary":"#1565C0","secondary":"#FFA000","accent":"#43A047","logo_url":null,"font":"Roboto"}'::jsonb,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table if not exists public.profiles (
  id          uuid primary key,
  company_id  uuid references public.companies(id) on delete set null,
  full_name   text,
  role        public.user_role not null default 'customer',
  avatar_url  text,
  phone       text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists idx_profiles_company on public.profiles(company_id);

create table if not exists public.suppliers (
  id          uuid primary key default uuid_generate_v4(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  name        text not null,
  vat_number  text,
  email       text,
  phone       text,
  address     text,
  created_at  timestamptz not null default now()
);
create index if not exists idx_suppliers_company on public.suppliers(company_id);

create table if not exists public.products (
  id           uuid primary key default uuid_generate_v4(),
  company_id   uuid not null references public.companies(id) on delete cascade,
  supplier_id  uuid references public.suppliers(id) on delete set null,
  sku          text,
  name         text not null,
  description  text,
  unit_price   numeric(12,2) not null default 0,
  vat_rate     numeric(5,2)  not null default 22,
  unit         text default 'pz',
  created_at   timestamptz not null default now(),
  unique (company_id, sku)
);
create index if not exists idx_products_company on public.products(company_id);

create table if not exists public.inventory (
  id                 uuid primary key default uuid_generate_v4(),
  company_id         uuid not null references public.companies(id) on delete cascade,
  product_id         uuid not null references public.products(id) on delete cascade,
  quantity           integer not null default 0,
  reorder_level      integer not null default 0,
  warehouse_location text,
  updated_at         timestamptz not null default now(),
  unique (product_id)
);
create index if not exists idx_inventory_company on public.inventory(company_id);

create table if not exists public.invoices (
  id             uuid primary key default uuid_generate_v4(),
  company_id     uuid not null references public.companies(id) on delete cascade,
  customer_id    uuid references public.profiles(id) on delete set null,
  invoice_number text not null,
  status         public.invoice_status not null default 'draft',
  issue_date     date not null default current_date,
  due_date       date,
  subtotal       numeric(12,2) not null default 0,
  tax_amount     numeric(12,2) not null default 0,
  total          numeric(12,2) not null default 0,
  notes          text,
  created_by     uuid references public.profiles(id),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (company_id, invoice_number)
);
create index if not exists idx_invoices_company on public.invoices(company_id);
create index if not exists idx_invoices_status  on public.invoices(status);

create table if not exists public.invoice_items (
  id          uuid primary key default uuid_generate_v4(),
  invoice_id  uuid not null references public.invoices(id) on delete cascade,
  product_id  uuid references public.products(id) on delete set null,
  description text not null,
  quantity    numeric(12,2) not null default 1,
  unit_price  numeric(12,2) not null default 0,
  vat_rate    numeric(5,2)  not null default 22,
  line_total  numeric(12,2) not null default 0
);
create index if not exists idx_invoice_items_invoice on public.invoice_items(invoice_id);

create table if not exists public.chat_rooms (
  id          uuid primary key default uuid_generate_v4(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  name        text,
  is_group    boolean not null default false,
  created_by  uuid references public.profiles(id),
  created_at  timestamptz not null default now()
);
create index if not exists idx_chat_rooms_company on public.chat_rooms(company_id);

create table if not exists public.chat_participants (
  id          uuid primary key default uuid_generate_v4(),
  room_id     uuid not null references public.chat_rooms(id) on delete cascade,
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  joined_at   timestamptz not null default now(),
  unique (room_id, profile_id)
);

create table if not exists public.chat_messages (
  id             uuid primary key default uuid_generate_v4(),
  room_id        uuid not null references public.chat_rooms(id) on delete cascade,
  sender_id      uuid not null references public.profiles(id) on delete cascade,
  content        text not null,
  attachment_url text,
  created_at     timestamptz not null default now()
);
create index if not exists idx_chat_messages_room on public.chat_messages(room_id, created_at);

-- ============================================================
--  SEZIONE 7 — FUNZIONI HELPER E TRIGGER updated_at
-- ============================================================

create or replace function public.auth_company_id()
returns uuid
language sql stable security definer set search_path = public
as $$
  select company_id from public.profiles where id = auth.uid();
$$;

create or replace function public.auth_role()
returns public.user_role
language sql stable security definer set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end; $$;

drop trigger if exists trg_companies_updated on public.companies;
create trigger trg_companies_updated before update on public.companies
  for each row execute function public.set_updated_at();

drop trigger if exists trg_profiles_updated on public.profiles;
create trigger trg_profiles_updated before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists trg_invoices_updated on public.invoices;
create trigger trg_invoices_updated before update on public.invoices
  for each row execute function public.set_updated_at();

drop trigger if exists trg_inventory_updated on public.inventory;
create trigger trg_inventory_updated before update on public.inventory
  for each row execute function public.set_updated_at();

-- ============================================================
--  SEZIONE 8 — RLS su invoices
-- ============================================================

alter table public.invoices enable row level security;
alter table public.invoices force row level security;

drop policy if exists invoices_super_admin_all on public.invoices;
create policy invoices_super_admin_all
  on public.invoices
  for all
  to authenticated
  using      (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');

drop policy if exists invoices_company_isolation on public.invoices;
create policy invoices_company_isolation
  on public.invoices
  for all
  to authenticated
  using (
        public.auth_role() in ('admin', 'employee')
    and company_id = public.auth_company_id()
  )
  with check (
        public.auth_role() in ('admin', 'employee')
    and company_id = public.auth_company_id()
  );

-- ============================================================
--  SEZIONE 9 — GRANTS su tabelle e default privileges
-- ============================================================

grant usage on schema public to anon, authenticated, service_role;
grant all on all tables    in schema public to anon, authenticated, service_role;
grant all on all sequences in schema public to anon, authenticated, service_role;
grant all on all functions in schema public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables    to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;

-- ============================================================
--  SEZIONE 10 — SEED azienda demo
-- ============================================================

insert into public.companies (id, name, vat_number, email, theme_settings)
values (
  '00000000-0000-0000-0000-000000000001',
  'Talete Demo S.r.l.',
  'IT01234567890',
  'demo@smarterp.local',
  '{"primary":"#0D47A1","secondary":"#FB8C00","accent":"#2E7D32","logo_url":null,"font":"Roboto"}'::jsonb
)
on conflict (id) do nothing;
