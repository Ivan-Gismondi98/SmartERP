-- ============================================================
--  SMARTERP · 13_step12_error_logs.sql
--  STEP 12 — Logging errori applicativi in DB + area "Bug del giorno".
--  Ogni errore mostrato all'utente viene registrato qui, così lo
--  sviluppatore (super_admin) li legge dall'app senza accedere ai log
--  del server. L'admin vede gli errori della propria azienda.
--
--  Eseguire DOPO 12_step10_studio.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/13_step12_error_logs.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

create table if not exists public.error_logs (
  id          uuid primary key default uuid_generate_v4(),
  company_id  uuid references public.companies(id) on delete set null,
  reported_by uuid,                         -- auth.users.id (no FK: sopravvive alla cancellazione utente)
  severity    text not null default 'error',-- info | warning | error | fatal
  module      text,                          -- area/app dove è avvenuto
  message     text not null,
  details     text,                          -- stack trace / contesto
  route       text,                          -- rotta/schermata
  created_at  timestamptz not null default now()
);
create index if not exists idx_error_logs_created on public.error_logs(created_at desc);
create index if not exists idx_error_logs_company on public.error_logs(company_id, created_at desc);
create index if not exists idx_error_logs_severity on public.error_logs(severity);

-- Trigger: completa company_id e reported_by dal profilo dell'utente.
create or replace function public.error_logs_fill()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.reported_by is null then
    new.reported_by := auth.uid();
  end if;
  if new.company_id is null and new.reported_by is not null then
    select company_id into new.company_id from public.profiles where id = new.reported_by;
  end if;
  return new;
end $$;

drop trigger if exists trg_error_logs_fill on public.error_logs;
create trigger trg_error_logs_fill before insert on public.error_logs
  for each row execute function public.error_logs_fill();

-- RLS.
alter table public.error_logs enable row level security;
alter table public.error_logs force row level security;

-- Insert: ogni autenticato può loggare i propri errori.
drop policy if exists error_logs_insert on public.error_logs;
create policy error_logs_insert on public.error_logs
  for insert to authenticated
  with check (reported_by is null or reported_by = auth.uid());

-- Select: super_admin tutto; admin la propria azienda; ognuno i propri.
drop policy if exists error_logs_select on public.error_logs;
create policy error_logs_select on public.error_logs
  for select to authenticated
  using (
        public.auth_role() = 'super_admin'
     or (public.auth_role() = 'admin' and company_id = public.auth_company_id())
     or reported_by = auth.uid()
  );

-- Delete: super_admin (pulizia).
drop policy if exists error_logs_delete on public.error_logs;
create policy error_logs_delete on public.error_logs
  for delete to authenticated
  using (public.auth_role() = 'super_admin');

-- Permesso per vedere l'area "Bug del giorno".
insert into public.permissions (code, module, description, kind) values
  ('errors.view', 'errors', 'Vedere il registro errori (Bug del giorno)', 'feature')
on conflict (code) do update
  set description = excluded.description, kind = excluded.kind;

insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, 'errors.view',
  case when r.role in ('admin') then true else false end
from (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;

-- Seed: qualche errore d'esempio per l'azienda demo.
insert into public.error_logs (company_id, severity, module, message, details, route)
values
  ('00000000-0000-0000-0000-000000000001','warning','invoices','Timeout caricamento lista fatture','SocketException: timeout after 30s','/invoices'),
  ('00000000-0000-0000-0000-000000000001','error','products','Null check operator used on a null value','#0 _ProductFormPageState.build','/products'),
  ('00000000-0000-0000-0000-000000000001','fatal','app','PostgrestException: JWT expired','code 401','/');
