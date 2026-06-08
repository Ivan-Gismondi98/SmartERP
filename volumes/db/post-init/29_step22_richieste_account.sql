-- ============================================================
--  SMARTERP · 29_step22_richieste_account.sql
--  La registrazione è riservata al super_admin. Gli utenti non registrati
--  possono però inviare una RICHIESTA di account allo sviluppatore
--  (indicando l'organizzazione e un messaggio). Lo sviluppatore le vede e
--  crea l'utenza.
--
--  Eseguire DOPO 28_step21_bundle_licenze.sql + NOTIFY reload.
-- ============================================================
\set ON_ERROR_STOP on

create table if not exists public.account_requests (
  id              uuid primary key default uuid_generate_v4(),
  requester_name  text,
  requester_email text not null,
  organization    text,
  message         text,
  status          text not null default 'new',  -- new | handled | rejected
  created_at      timestamptz not null default now()
);
create index if not exists idx_account_requests_created
  on public.account_requests(created_at desc);

alter table public.account_requests enable row level security;
alter table public.account_requests force row level security;

-- Chiunque (anche non autenticato) può INVIARE una richiesta.
drop policy if exists account_requests_insert on public.account_requests;
create policy account_requests_insert on public.account_requests
  for insert to anon, authenticated
  with check (true);

-- Solo lo sviluppatore (super_admin) le vede e le gestisce.
drop policy if exists account_requests_super on public.account_requests;
create policy account_requests_super on public.account_requests
  for all to authenticated
  using (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');
