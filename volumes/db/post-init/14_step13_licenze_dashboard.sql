-- ============================================================
--  SMARTERP · 14_step13_licenze_dashboard.sql
--  STEP 13 — Licenze (un'app = una licenza), pagamenti e tabella ticket
--  (predisposta per lo step 15). Alimentano la Dashboard Sviluppatore.
--
--  Eseguire DOPO 13_step12_error_logs.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/14_step13_licenze_dashboard.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- ============================================================
--  LICENZE  (canone di un'applicazione per un'organizzazione)
-- ============================================================
create table if not exists public.licenses (
  id           uuid primary key default uuid_generate_v4(),
  company_id   uuid not null references public.companies(id) on delete cascade,
  name         text not null,                 -- nome app/licenza
  status       text not null default 'active', -- active | suspended | expired
  price        numeric(12,2) not null default 0,
  period       text not null default 'monthly',-- monthly | yearly | once
  start_date   date not null default current_date,
  renewal_date date,                          -- prossima scadenza pagamento
  notes        text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists idx_licenses_company on public.licenses(company_id);

drop trigger if exists trg_licenses_updated on public.licenses;
create trigger trg_licenses_updated before update on public.licenses
  for each row execute function public.set_updated_at();

create table if not exists public.license_payments (
  id          uuid primary key default uuid_generate_v4(),
  license_id  uuid not null references public.licenses(id) on delete cascade,
  company_id  uuid not null references public.companies(id) on delete cascade,
  amount      numeric(12,2) not null default 0,
  paid_at     date not null default current_date,
  note        text,
  created_at  timestamptz not null default now()
);
create index if not exists idx_license_payments_company on public.license_payments(company_id);

-- ============================================================
--  TICKET  (gestione avanzamento bug; workflow completo nello step 15)
-- ============================================================
create table if not exists public.tickets (
  id           uuid primary key default uuid_generate_v4(),
  company_id   uuid references public.companies(id) on delete set null,
  title        text not null,
  description  text,
  status       text not null default 'open',   -- open | in_progress | resolved | closed
  priority     text not null default 'medium',  -- low | medium | high
  error_log_id uuid references public.error_logs(id) on delete set null,
  created_by   uuid,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists idx_tickets_company on public.tickets(company_id);
create index if not exists idx_tickets_status on public.tickets(status);

drop trigger if exists trg_tickets_updated on public.tickets;
create trigger trg_tickets_updated before update on public.tickets
  for each row execute function public.set_updated_at();

-- ============================================================
--  RLS: super_admin tutto; admin la propria azienda (lettura).
--  La gestione licenze è prerogativa dello sviluppatore (super_admin).
-- ============================================================
do $$
declare t text;
begin
  foreach t in array array['licenses','license_payments','tickets'] loop
    execute format('alter table public.%I enable row level security;', t);
    execute format('alter table public.%I force row level security;', t);
  end loop;
end $$;

-- licenses
drop policy if exists licenses_super on public.licenses;
create policy licenses_super on public.licenses
  for all to authenticated
  using (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');
drop policy if exists licenses_admin_read on public.licenses;
create policy licenses_admin_read on public.licenses
  for select to authenticated
  using (public.auth_role() = 'admin' and company_id = public.auth_company_id());

-- license_payments
drop policy if exists lic_pay_super on public.license_payments;
create policy lic_pay_super on public.license_payments
  for all to authenticated
  using (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');
drop policy if exists lic_pay_admin_read on public.license_payments;
create policy lic_pay_admin_read on public.license_payments
  for select to authenticated
  using (public.auth_role() = 'admin' and company_id = public.auth_company_id());

-- tickets
drop policy if exists tickets_super on public.tickets;
create policy tickets_super on public.tickets
  for all to authenticated
  using (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');
drop policy if exists tickets_admin on public.tickets;
create policy tickets_admin on public.tickets
  for all to authenticated
  using (public.auth_role() = 'admin' and company_id = public.auth_company_id())
  with check (public.auth_role() = 'admin' and company_id = public.auth_company_id());

-- ============================================================
--  Permessi (feature). super_admin li ha tutti per definizione.
-- ============================================================
insert into public.permissions (code, module, description, kind) values
  ('dev.dashboard',   'developer', 'Dashboard Sviluppatore (clienti/licenze/bug/ticket)', 'feature'),
  ('licenses.manage', 'developer', 'Gestire licenze e pagamenti', 'feature')
on conflict (code) do update
  set description = excluded.description, kind = excluded.kind;

-- Default: nessun ruolo standard li ha (solo lo sviluppatore super_admin).
insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, p.code, false
from (select code from public.permissions where module = 'developer') p
cross join (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;

-- ============================================================
--  Seed: una licenza demo + pagamento per l'azienda demo.
-- ============================================================
do $$
declare v_lic uuid;
begin
  if not exists (select 1 from public.licenses
                 where company_id = '00000000-0000-0000-0000-000000000001') then
    insert into public.licenses (company_id, name, status, price, period, start_date, renewal_date)
    values ('00000000-0000-0000-0000-000000000001', 'SmartERP - Suite completa',
            'active', 49.00, 'monthly', current_date - 60, current_date - 5)
    returning id into v_lic;  -- renewal nel passato => in ritardo (demo)

    insert into public.license_payments (license_id, company_id, amount, paid_at, note)
    values
      (v_lic, '00000000-0000-0000-0000-000000000001', 49.00, current_date - 60, 'Mese 1'),
      (v_lic, '00000000-0000-0000-0000-000000000001', 49.00, current_date - 30, 'Mese 2');
  end if;
end $$;
