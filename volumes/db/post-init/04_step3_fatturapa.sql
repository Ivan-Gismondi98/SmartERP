-- ============================================================
--  SMARTERP · 04_step3_fatturapa.sql
--  STEP 3 — Dati fiscali del CEDENTE/PRESTATORE (azienda) richiesti
--  dal tracciato FatturaPA, + permesso di export.
--
--  Eseguire DOPO 03_step2_gestione.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/04_step3_fatturapa.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- Campi fiscali su companies (CedentePrestatore).
alter table public.companies add column if not exists tax_code text;          -- Codice Fiscale
alter table public.companies add column if not exists regime_fiscale text not null default 'RF01';
alter table public.companies add column if not exists zip text;                -- CAP
alter table public.companies add column if not exists city text;               -- Comune
alter table public.companies add column if not exists province text;           -- Provincia
alter table public.companies add column if not exists country text not null default 'IT';
-- Formato trasmissione SdI: FPR12 (privati) | FPA12 (PA).
alter table public.companies add column if not exists transmission_format text not null default 'FPR12';

-- Completa i dati fiscali dell'azienda demo per un XML valido.
update public.companies set
  tax_code       = coalesce(tax_code, '01234567890'),
  regime_fiscale = 'RF01',
  address        = coalesce(address, 'Via Garibaldi 10'),
  zip            = coalesce(zip, '20121'),
  city           = coalesce(city, 'Milano'),
  province       = coalesce(province, 'MI'),
  country        = 'IT'
where id = '00000000-0000-0000-0000-000000000001';

-- Nuovo permesso: esportare la fattura in XML FatturaPA.
insert into public.permissions (code, module, description) values
  ('invoices.export', 'invoices', 'Esportare la fattura in XML FatturaPA')
on conflict (code) do update set description = excluded.description;

-- Default per ruolo (admin/employee si', customer no).
insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, 'invoices.export',
  case when r.role in ('admin','employee') then true else false end
from (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;
