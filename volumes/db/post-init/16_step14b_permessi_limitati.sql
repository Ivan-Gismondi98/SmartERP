-- ============================================================
--  SMARTERP · 16_step14b_permessi_limitati.sql
--  STEP 14b — La gestione dei permessi è limitata:
--   - super_admin: gestisce TUTTO (tutte le aziende, tutti i permessi).
--   - admin: solo la PROPRIA azienda e SOLO i permessi non sensibili
--     (esclusi i moduli 'developer' e 'settings').
--
--  Eseguire DOPO 15_step14_gestione_utenti.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/16_step14b_permessi_limitati.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

drop policy if exists role_perm_write on public.role_permissions;
create policy role_perm_write on public.role_permissions
  for all to authenticated
  using (
        public.auth_role() = 'super_admin'
     or (public.auth_role() = 'admin'
         and company_id = public.auth_company_id()
         and permission_code not in (
           select code from public.permissions
           where module in ('developer','settings')
         ))
  )
  with check (
        public.auth_role() = 'super_admin'
     or (public.auth_role() = 'admin'
         and company_id = public.auth_company_id()
         and permission_code not in (
           select code from public.permissions
           where module in ('developer','settings')
         ))
  );
