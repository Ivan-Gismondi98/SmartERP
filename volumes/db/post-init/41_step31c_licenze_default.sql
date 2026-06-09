-- ============================================================
--  SMARTERP · 41_step31c_licenze_default.sql
--  Licenze PREDEFINITE (seedate dal sistema): flag is_default. Nella UI
--  vengono contrassegnate con una stella e NON sono selezionabili per
--  l'eliminazione in blocco.
--
--  Eseguire DOPO 40_step31b_pacchetti_default_lock.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/41_step31c_licenze_default.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

alter table public.licenses
  add column if not exists is_default boolean not null default false;

-- Marca come predefinite le licenze già seedate per l'azienda demo
-- (quelle create dalle migrazioni di esempio).
update public.licenses set is_default = true
where company_id = '00000000-0000-0000-0000-000000000001';
