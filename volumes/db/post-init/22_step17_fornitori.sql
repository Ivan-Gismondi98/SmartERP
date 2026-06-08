-- ============================================================
--  SMARTERP · 22_step17_fornitori.sql
--  Fornitori (suppliers): RLS company-isolation + permessi.
--
--  Eseguire DOPO 21_step15b_ticket_thread.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/22_step17_fornitori.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

alter table public.suppliers enable row level security;
alter table public.suppliers force row level security;

drop policy if exists suppliers_super on public.suppliers;
create policy suppliers_super on public.suppliers
  for all to authenticated
  using      (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');

drop policy if exists suppliers_company on public.suppliers;
create policy suppliers_company on public.suppliers
  for all to authenticated
  using (
        public.auth_role() in ('admin','employee')
    and company_id = public.auth_company_id()
  )
  with check (
        public.auth_role() in ('admin','employee')
    and company_id = public.auth_company_id()
  );

insert into public.permissions (code, module, description, kind, admin_manageable) values
  ('suppliers.view',   'suppliers', 'Visualizzare i fornitori', 'generic', true),
  ('suppliers.create', 'suppliers', 'Creare fornitori', 'generic', true),
  ('suppliers.edit',   'suppliers', 'Modificare fornitori', 'generic', true),
  ('suppliers.delete', 'suppliers', 'Eliminare fornitori', 'generic', true)
on conflict (code) do update
  set description = excluded.description, kind = excluded.kind, admin_manageable = excluded.admin_manageable;

insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, p.code,
  case
    when r.role = 'admin' then true
    when r.role = 'employee' then p.code <> 'suppliers.delete'
    else false
  end
from (select code from public.permissions where module = 'suppliers') p
cross join (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;

-- Seed: un fornitore demo.
insert into public.suppliers (company_id, name, vat_number, email, phone, address)
select '00000000-0000-0000-0000-000000000001', 'Legnami Rossi S.r.l.', 'IT02233445566',
       'ordini@legnamirossi.it', '011 1234567', 'Via dei Boschi 5, Torino'
where not exists (
  select 1 from public.suppliers
  where company_id = '00000000-0000-0000-0000-000000000001' and name = 'Legnami Rossi S.r.l.'
);
