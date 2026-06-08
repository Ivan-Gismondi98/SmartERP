-- ============================================================
--  SMARTERP · 09_step7_branding.sql
--  STEP 7 — Branding per-tenant: permesso per gestire i dati e il
--  branding dell'azienda (colori/logo in companies.theme_settings).
--
--  Eseguire DOPO 08_step6_impostazioni_sdi.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/09_step7_branding.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

insert into public.permissions (code, module, description, kind) values
  ('settings.company.manage', 'settings', 'Gestire dati e branding dell''azienda', 'generic')
on conflict (code) do update
  set description = excluded.description, kind = excluded.kind;

insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, 'settings.company.manage',
  case when r.role = 'admin' then true else false end
from (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;
