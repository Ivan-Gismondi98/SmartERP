-- ============================================================
--  SMARTERP · 36_step29_manutenzione.sql
--  Modulo MANUTENZIONE: registro attrezzature/impianti e gestione delle
--  richieste di intervento (correttiva/preventiva).
--
--  Applicativo licenziabile (app_code 'maintenance').
--
--  Eseguire DOPO 35_step28_acquisti.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/36_step29_manutenzione.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- ============================================================
--  TABELLE
-- ============================================================
create table if not exists public.maintenance_equipment (
  id               uuid primary key default uuid_generate_v4(),
  company_id       uuid not null references public.companies(id) on delete cascade,
  name             text not null,
  code             text,                              -- matricola / inventario
  category         text,
  location         text,
  status           text not null default 'operational', -- operational|maintenance|out_of_service
  purchase_date    date,
  last_service     date,
  next_service     date,
  notes            text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index if not exists idx_maint_equip_company on public.maintenance_equipment(company_id);

drop trigger if exists trg_maint_equip_updated on public.maintenance_equipment;
create trigger trg_maint_equip_updated before update on public.maintenance_equipment
  for each row execute function public.set_updated_at();

create table if not exists public.maintenance_requests (
  id             uuid primary key default uuid_generate_v4(),
  company_id     uuid not null references public.companies(id) on delete cascade,
  equipment_id   uuid references public.maintenance_equipment(id) on delete set null,
  title          text not null,
  description    text,
  request_type   text not null default 'corrective',  -- corrective|preventive
  priority       text not null default 'medium',       -- low|medium|high|urgent
  status         text not null default 'open',         -- open|in_progress|done|cancelled
  requested_by   uuid references public.profiles(id) on delete set null,
  assigned_to    text,                                 -- tecnico incaricato
  scheduled_date date,
  completed_at   timestamptz,
  cost           numeric(12,2) not null default 0,
  notes          text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index if not exists idx_maint_req_company on public.maintenance_requests(company_id);
create index if not exists idx_maint_req_status on public.maintenance_requests(status);

drop trigger if exists trg_maint_req_updated on public.maintenance_requests;
create trigger trg_maint_req_updated before update on public.maintenance_requests
  for each row execute function public.set_updated_at();

-- ============================================================
--  RLS company-isolation
-- ============================================================
do $$
declare t text;
begin
  foreach t in array array['maintenance_equipment','maintenance_requests'] loop
    execute format('alter table public.%I enable row level security;', t);
    execute format('alter table public.%I force row level security;', t);
    execute format('drop policy if exists %I_super on public.%I;', t, t);
    execute format($p$create policy %I_super on public.%I for all to authenticated
        using (public.auth_role() = 'super_admin')
        with check (public.auth_role() = 'super_admin');$p$, t, t);
    execute format('drop policy if exists %I_company on public.%I;', t, t);
    execute format($p$create policy %I_company on public.%I for all to authenticated
        using (public.auth_role() in ('admin','employee') and company_id = public.auth_company_id())
        with check (public.auth_role() in ('admin','employee') and company_id = public.auth_company_id());$p$, t, t);
  end loop;
end $$;

-- ============================================================
--  PERMESSI
-- ============================================================
insert into public.permissions (code, module, description, kind, admin_manageable) values
  ('maintenance.view',      'maintenance', 'Visualizzare manutenzioni e attrezzature', 'generic', true),
  ('maintenance.create',    'maintenance', 'Creare richieste di manutenzione', 'generic', true),
  ('maintenance.edit',      'maintenance', 'Modificare richieste di manutenzione', 'generic', true),
  ('maintenance.delete',    'maintenance', 'Eliminare richieste di manutenzione', 'generic', true),
  ('maintenance.equipment', 'maintenance', 'Gestire il registro attrezzature', 'generic', true)
on conflict (code) do update
  set description = excluded.description, kind = excluded.kind, admin_manageable = excluded.admin_manageable;

insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, p.code,
  case
    when r.role = 'admin' then true
    when r.role = 'employee' then p.code <> 'maintenance.delete'
    else false
  end
from (select code from public.permissions where module = 'maintenance') p
cross join (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;

-- ============================================================
--  Licenza demo + attrezzature e richiesta di esempio
-- ============================================================
insert into public.licenses (company_id, name, status, price, period, start_date, app_code, app_codes)
select '00000000-0000-0000-0000-000000000001', 'Manutenzione - mensile', 'active', 15.00, 'monthly',
       current_date, 'maintenance', array['maintenance']
where not exists (
  select 1 from public.licenses
  where company_id = '00000000-0000-0000-0000-000000000001'
    and app_codes @> array['maintenance']
);

insert into public.maintenance_equipment (company_id, name, code, category, location, status, next_service)
select '00000000-0000-0000-0000-000000000001', v.name, v.code, v.category, v.location, v.status, v.next_service
from (values
  ('Sega circolare industriale', 'MAC-001', 'Macchinari', 'Reparto taglio', 'operational', current_date + 30),
  ('Compressore aria', 'MAC-002', 'Impianti', 'Officina', 'maintenance', current_date + 7),
  ('Muletto elettrico', 'MEZ-010', 'Mezzi', 'Magazzino', 'operational', current_date + 60)
) as v(name, code, category, location, status, next_service)
where not exists (
  select 1 from public.maintenance_equipment e
  where e.company_id = '00000000-0000-0000-0000-000000000001' and e.code = v.code
);

do $$
declare
  v_company uuid := '00000000-0000-0000-0000-000000000001';
  v_equip uuid;
begin
  select id into v_equip from public.maintenance_equipment
    where company_id = v_company and code = 'MAC-002' limit 1;

  if v_equip is not null
     and not exists (select 1 from public.maintenance_requests where company_id = v_company) then
    insert into public.maintenance_requests
      (company_id, equipment_id, title, description, request_type, priority, status, assigned_to, scheduled_date)
    values (v_company, v_equip, 'Revisione compressore', 'Rumore anomalo e calo di pressione',
            'corrective', 'high', 'open', 'Officina interna', current_date + 3);
  end if;
end $$;
