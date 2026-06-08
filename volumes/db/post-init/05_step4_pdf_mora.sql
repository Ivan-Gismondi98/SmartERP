-- ============================================================
--  SMARTERP · 05_step4_pdf_mora.sql
--  STEP 4 — Termini di pagamento (giorni), interessi di mora su
--  fatture scadute, e permesso di stampa PDF.
--
--  Eseguire DOPO 04_step3_fatturapa.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/05_step4_pdf_mora.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- Termini di pagamento in giorni (per calcolare la scadenza dalla data doc).
alter table public.invoices add column if not exists payment_terms_days int;

-- Interessi di mora: abilitazione + tasso annuo percentuale.
alter table public.invoices add column if not exists interest_enabled boolean not null default false;
alter table public.invoices add column if not exists interest_rate numeric(6,2);

-- Permesso: stampare/esportare in PDF la fattura.
insert into public.permissions (code, module, description) values
  ('invoices.print', 'invoices', 'Stampare la fattura in PDF')
on conflict (code) do update set description = excluded.description;

insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, 'invoices.print',
  case when r.role in ('admin','employee') then true else false end
from (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;
