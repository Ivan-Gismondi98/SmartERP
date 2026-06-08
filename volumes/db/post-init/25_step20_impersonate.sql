-- ============================================================
--  SMARTERP · 25_step20_impersonate.sql
--  Consente al super_admin di creare il canale di Supporto di un altro
--  utente, così da poter inviare il messaggio di sistema che notifica
--  l'impersonate.
--
--  Eseguire DOPO 24_step19_supporto.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/25_step20_impersonate.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

drop policy if exists direct_threads_insert on public.direct_threads;
create policy direct_threads_insert on public.direct_threads
  for insert to authenticated
  with check (owner_id = auth.uid() or public.auth_role() = 'super_admin');
