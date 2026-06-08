-- ============================================================
--  SMARTERP · 17_step14c_delega_permessi.sql
--  STEP 14c — Lo SVILUPPATORE (super_admin) decide quali permessi
--  l'admin può gestire/delegare ad altri utenti, tramite il flag
--  permissions.admin_manageable.
--
--  Eseguire DOPO 16_step14b_permessi_limitati.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/17_step14c_delega_permessi.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- Flag: questo permesso è delegabile/gestibile da un admin?
alter table public.permissions
  add column if not exists admin_manageable boolean not null default false;

-- Default ragionevole: i moduli operativi sì, developer/settings no.
update public.permissions
   set admin_manageable = (module in ('invoices','customers','products','chat','studio','errors'));

-- Solo il super_admin può modificare il catalogo permessi (il flag).
drop policy if exists permissions_write on public.permissions;
create policy permissions_write on public.permissions
  for update to authenticated
  using (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');

-- L'admin può gestire i role_permissions della propria azienda SOLO per i
-- permessi marcati admin_manageable; il super_admin gestisce tutto.
drop policy if exists role_perm_write on public.role_permissions;
create policy role_perm_write on public.role_permissions
  for all to authenticated
  using (
        public.auth_role() = 'super_admin'
     or (public.auth_role() = 'admin'
         and company_id = public.auth_company_id()
         and exists (select 1 from public.permissions p
                     where p.code = role_permissions.permission_code
                       and p.admin_manageable))
  )
  with check (
        public.auth_role() = 'super_admin'
     or (public.auth_role() = 'admin'
         and company_id = public.auth_company_id()
         and exists (select 1 from public.permissions p
                     where p.code = role_permissions.permission_code
                       and p.admin_manageable))
  );
