-- ============================================================
--  SMARTERP · 18_step14d_isolamento_org.sql
--  STEP 14d — Isolamento organizzazioni: l'admin vede SOLO la propria
--  azienda; il super_admin vede tutte; l'anon può leggere (diagnostica
--  pre-login / health check).
--
--  Eseguire DOPO 17_step14c_delega_permessi.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/18_step14d_isolamento_org.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- Sostituisce la lettura "pubblica" con uno scoping per ruolo.
drop policy if exists companies_select on public.companies;

-- Pre-login (anon): consentito solo per la pagina diagnostica.
create policy companies_select_anon on public.companies
  for select to anon using (true);

-- Autenticato: super_admin tutte, gli altri SOLO la propria.
create policy companies_select_auth on public.companies
  for select to authenticated
  using (
        public.auth_role() = 'super_admin'
     or id = public.auth_company_id()
  );
