-- ============================================================
--  SMARTERP · 00_init_smarterp.sql
--  Inizializzazione schema multi-tenant + RLS
-- ============================================================
\set ON_ERROR_STOP on

-- ------------------------------------------------------------
-- 1) ESTENSIONI
-- ------------------------------------------------------------
create extension if not exists "uuid-ossp";

-- ------------------------------------------------------------
-- 2) TIPI ENUM CUSTOM
-- ------------------------------------------------------------
do $$ begin
  create type public.user_role as enum ('super_admin', 'admin', 'employee', 'customer');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.invoice_status as enum ('draft', 'sent', 'paid', 'overdue', 'cancelled');
exception when duplicate_object then null; end $$;

-- ------------------------------------------------------------
-- 3) TABELLE
-- ------------------------------------------------------------

-- 3.1 Aziende (tenant). theme_settings JSONB = brand/colori per le stampe.
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

-- 3.2 Profili (1:1 con auth.users di Supabase)
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
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

-- 3.3 Fornitori
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

-- 3.4 Prodotti (catalogo)
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

-- 3.5 Magazzino (giacenze)
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

-- 3.6 Fatture (testata)
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

-- 3.7 Righe fattura
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

-- 3.8 Chat: stanze
create table if not exists public.chat_rooms (
  id          uuid primary key default uuid_generate_v4(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  name        text,
  is_group    boolean not null default false,
  created_by  uuid references public.profiles(id),
  created_at  timestamptz not null default now()
);
create index if not exists idx_chat_rooms_company on public.chat_rooms(company_id);

-- 3.9 Chat: partecipanti
create table if not exists public.chat_participants (
  id          uuid primary key default uuid_generate_v4(),
  room_id     uuid not null references public.chat_rooms(id) on delete cascade,
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  joined_at   timestamptz not null default now(),
  unique (room_id, profile_id)
);

-- 3.10 Chat: messaggi
create table if not exists public.chat_messages (
  id             uuid primary key default uuid_generate_v4(),
  room_id        uuid not null references public.chat_rooms(id) on delete cascade,
  sender_id      uuid not null references public.profiles(id) on delete cascade,
  content        text not null,
  attachment_url text,
  created_at     timestamptz not null default now()
);
create index if not exists idx_chat_messages_room on public.chat_messages(room_id, created_at);

-- ------------------------------------------------------------
-- 4) FUNZIONI DI SUPPORTO (SECURITY DEFINER -> niente ricorsione RLS)
-- ------------------------------------------------------------
create or replace function public.auth_company_id()
returns uuid
language sql stable security definer set search_path = public, auth
as $$
  select company_id from public.profiles where id = auth.uid();
$$;

create or replace function public.auth_role()
returns public.user_role
language sql stable security definer set search_path = public, auth
as $$
  select role from public.profiles where id = auth.uid();
$$;

-- updated_at automatico
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end; $$;

-- Crea automaticamente un profilo all'iscrizione di un utente auth
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public, auth
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.email), 'customer')
  on conflict (id) do nothing;
  return new;
end; $$;

-- ------------------------------------------------------------
-- 5) TRIGGER
-- ------------------------------------------------------------
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

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ------------------------------------------------------------
-- 6) ROW LEVEL SECURITY sulla tabella INVOICES
--    - super_admin (sviluppatore): bypass totale globale
--    - admin / employee: SOLO righe del proprio company_id
--    Nota: il ruolo service_role bypassa nativamente la RLS.
-- ------------------------------------------------------------
alter table public.invoices enable row level security;
alter table public.invoices force row level security;

-- 6.1 super_admin -> controllo globale completo
drop policy if exists invoices_super_admin_all on public.invoices;
create policy invoices_super_admin_all
  on public.invoices
  for all
  to authenticated
  using      (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');

-- 6.2 admin / employee -> isolamento sul proprio company_id
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

-- ------------------------------------------------------------
-- 7) GRANT (PostgREST usa i ruoli anon/authenticated; la RLS resta il gate)
-- ------------------------------------------------------------
grant usage on schema public to anon, authenticated, service_role;
grant all on all tables    in schema public to anon, authenticated, service_role;
grant all on all sequences in schema public to anon, authenticated, service_role;
grant all on all functions in schema public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables    to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;

-- ------------------------------------------------------------
-- 8) REALTIME — pubblica chat e fatture sul canale WebSocket
-- ------------------------------------------------------------
do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.chat_messages;
    alter publication supabase_realtime add table public.invoices;
  end if;
exception when duplicate_object then null; end $$;

-- ------------------------------------------------------------
-- 9) SEED minimo (azienda demo con tema brand)
-- ------------------------------------------------------------
insert into public.companies (id, name, vat_number, email, theme_settings)
values (
  '00000000-0000-0000-0000-000000000001',
  'Talete Demo S.r.l.',
  'IT01234567890',
  'demo@smarterp.local',
  '{"primary":"#0D47A1","secondary":"#FB8C00","accent":"#2E7D32","logo_url":null,"font":"Roboto"}'::jsonb
)
on conflict (id) do nothing;
