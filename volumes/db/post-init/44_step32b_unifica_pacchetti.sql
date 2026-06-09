-- ============================================================
--  SMARTERP · 44_step32b_unifica_pacchetti.sql
--  Unificazione: il catalogo dei pacchetti è ora rappresentato dalle
--  LICENZE PREDEFINITE (is_default, company_id NULL). La vecchia tabella
--  app_bundles non serve più e viene rimossa.
--
--  Eseguire DOPO 43_step32_seed_sviluppatore.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/44_step32b_unifica_pacchetti.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

drop trigger if exists trg_app_bundles_no_delete_default on public.app_bundles;
drop trigger if exists trg_app_bundles_updated on public.app_bundles;
drop table if exists public.app_bundles cascade;
drop function if exists public.prevent_default_bundle_delete();
