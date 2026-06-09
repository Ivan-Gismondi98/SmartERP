-- ============================================================
--  SMARTERP · 31_step24_crm.sql
--  Modulo CRM: pipeline commerciale. Un'unica entità "opportunità" che
--  attraversa gli stadi: lead (nuovo) -> qualificato -> proposta ->
--  vinta/persa. Tracciamento lead e chiusura opportunità.
--
--  È un APPLICATIVO licenziabile (app_code 'crm'): visibile solo alle
--  organizzazioni con licenza CRM attiva (o suite). Gestione vendita
--  licenze: super_admin.
--
--  Eseguire DOPO 30_step23_vendite.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/31_step24_crm.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- ============================================================
--  TABELLA — opportunità (pipeline)
-- ============================================================
create table if not exists public.crm_opportunities (
  id              uuid primary key default uuid_generate_v4(),
  company_id      uuid not null references public.companies(id) on delete cascade,
  title           text not null,
  customer_id     uuid references public.customers(id) on delete set null,
  contact_name    text,
  contact_email   text,
  contact_phone   text,
  contact_company text,
  stage           text not null default 'new',  -- new|qualified|proposal|won|lost
  expected_value  numeric(12,2) not null default 0,
  probability     int not null default 10,      -- 0..100
  expected_close  date,
  source          text,                          -- sito, passaparola, fiera, ...
  owner_id        uuid references public.profiles(id) on delete set null,
  notes           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists idx_crm_opps_company on public.crm_opportunities(company_id);
create index if not exists idx_crm_opps_stage on public.crm_opportunities(stage);

drop trigger if exists trg_crm_opps_updated on public.crm_opportunities;
create trigger trg_crm_opps_updated before update on public.crm_opportunities
  for each row execute function public.set_updated_at();

-- ============================================================
--  RLS company-isolation (stesso pattern degli altri moduli)
-- ============================================================
alter table public.crm_opportunities enable row level security;
alter table public.crm_opportunities force row level security;

drop policy if exists crm_opps_super on public.crm_opportunities;
create policy crm_opps_super on public.crm_opportunities
  for all to authenticated
  using      (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');

drop policy if exists crm_opps_company on public.crm_opportunities;
create policy crm_opps_company on public.crm_opportunities
  for all to authenticated
  using (
        public.auth_role() in ('admin','employee')
    and company_id = public.auth_company_id()
  )
  with check (
        public.auth_role() in ('admin','employee')
    and company_id = public.auth_company_id()
  );

-- ============================================================
--  PERMESSI
-- ============================================================
insert into public.permissions (code, module, description, kind, admin_manageable) values
  ('crm.view',   'crm', 'Visualizzare lead e opportunità', 'generic', true),
  ('crm.create', 'crm', 'Creare lead e opportunità', 'generic', true),
  ('crm.edit',   'crm', 'Modificare lead e opportunità', 'generic', true),
  ('crm.delete', 'crm', 'Eliminare lead e opportunità', 'generic', true)
on conflict (code) do update
  set description = excluded.description, kind = excluded.kind, admin_manageable = excluded.admin_manageable;

insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, p.code,
  case
    when r.role = 'admin' then true
    when r.role = 'employee' then p.code <> 'crm.delete'
    else false
  end
from (select code from public.permissions where module = 'crm') p
cross join (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;

-- ============================================================
--  Licenza CRM demo (per l'azienda demo) + qualche opportunità di esempio.
-- ============================================================
insert into public.licenses (company_id, name, status, price, period, start_date, app_code, app_codes)
select '00000000-0000-0000-0000-000000000001', 'CRM - mensile', 'active', 19.00, 'monthly',
       current_date, 'crm', array['crm']
where not exists (
  select 1 from public.licenses
  where company_id = '00000000-0000-0000-0000-000000000001'
    and app_codes @> array['crm']
);

insert into public.crm_opportunities
  (company_id, title, contact_name, contact_company, stage, expected_value, probability, source, expected_close)
select '00000000-0000-0000-0000-000000000001', 'Fornitura arredi ufficio', 'Mario Bianchi',
       'Bianchi & Figli S.r.l.', 'qualified', 8500.00, 40, 'Passaparola', current_date + 20
where not exists (
  select 1 from public.crm_opportunities
  where company_id = '00000000-0000-0000-0000-000000000001' and title = 'Fornitura arredi ufficio'
);

insert into public.crm_opportunities
  (company_id, title, contact_name, contact_company, stage, expected_value, probability, source, expected_close)
select '00000000-0000-0000-0000-000000000001', 'Manutenzione annuale impianti', 'Laura Verdi',
       'Verdi Spa', 'proposal', 3200.00, 70, 'Sito web', current_date + 10
where not exists (
  select 1 from public.crm_opportunities
  where company_id = '00000000-0000-0000-0000-000000000001' and title = 'Manutenzione annuale impianti'
);
