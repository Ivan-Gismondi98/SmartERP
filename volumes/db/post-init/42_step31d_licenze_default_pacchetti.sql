-- ============================================================
--  SMARTERP · 42_step31d_licenze_default_pacchetti.sql
--  Ridefinisce le licenze "predefinite":
--   - company_id diventa NULLABLE (i pacchetti predefiniti NON puntano ad
--     alcuna organizzazione);
--   - si azzerano TUTTE le licenze esistenti (reset una tantum) e si creano
--     SOLO i pacchetti predefiniti (is_default = true, company_id = NULL,
--     sempre multi-applicazione);
--   - i pacchetti predefiniti si DUPLICANO per assegnarli a un cliente
--     scegliendo organizzazione, validità e stato.
--
--  Eseguire DOPO 41_step31c_licenze_default.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/42_step31d_licenze_default_pacchetti.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- company_id nullable (licenze predefinite non assegnate).
alter table public.licenses alter column company_id drop not null;

-- Reset una tantum: se non esistono ancora pacchetti predefiniti NON
-- assegnati, azzera tutte le licenze e i pagamenti collegati.
do $$
begin
  if not exists (
    select 1 from public.licenses where is_default and company_id is null
  ) then
    delete from public.licenses;  -- cascade su license_payments
  end if;
end $$;

-- Pacchetti predefiniti (multi-app), non assegnati ad alcuna organizzazione.
insert into public.licenses
  (company_id, name, status, price, period, app_code, app_codes, is_default)
select null, v.name, 'active', v.price, 'monthly', v.code1, v.codes, true
from (values
  ('Fatturazione',            39.00, 'invoices',  array['invoices','customers']),
  ('Vendite & CRM',           59.00, 'crm',       array['crm','invoices','customers']),
  ('Amministrazione',         79.00, 'invoices',  array['invoices','customers','accounting','documents']),
  ('Magazzino & Produzione',  59.00, 'products',  array['products','production']),
  ('Acquisti & Magazzino',    45.00, 'purchases', array['purchases','products']),
  ('Operations',              99.00, 'products',  array['products','production','purchases','maintenance']),
  ('Documenti & Progetti',    29.00, 'documents', array['documents','projects']),
  ('Collaborazione',          29.00, 'chat',      array['chat','studio','assistant']),
  ('Suite completa',         149.00, 'suite',     array['suite'])
) as v(name, price, code1, codes)
where not exists (
  select 1 from public.licenses l
  where l.is_default and l.company_id is null and l.name = v.name
);
