-- ============================================================
--  SMARTERP · 37_step30_progetti.sql
--  Modulo PROGETTI: organizzazione e pianificazione dei progetti con
--  attività (task) collegate. Avanzamento calcolato dai task completati.
--
--  Applicativo licenziabile (app_code 'projects').
--
--  Eseguire DOPO 36_step29_manutenzione.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/37_step30_progetti.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- ============================================================
--  TABELLE
-- ============================================================
create table if not exists public.projects (
  id           uuid primary key default uuid_generate_v4(),
  company_id   uuid not null references public.companies(id) on delete cascade,
  customer_id  uuid references public.customers(id) on delete set null,
  name         text not null,
  status       text not null default 'planning',  -- planning|active|on_hold|done|cancelled
  start_date   date,
  due_date     date,
  budget       numeric(12,2) not null default 0,
  manager      text,
  description  text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists idx_projects_company on public.projects(company_id);

drop trigger if exists trg_projects_updated on public.projects;
create trigger trg_projects_updated before update on public.projects
  for each row execute function public.set_updated_at();

create table if not exists public.project_tasks (
  id           uuid primary key default uuid_generate_v4(),
  project_id   uuid not null references public.projects(id) on delete cascade,
  position     int not null default 0,
  title        text not null,
  description  text,
  status       text not null default 'todo',   -- todo|in_progress|done
  priority     text not null default 'medium',  -- low|medium|high
  assigned_to  text,
  due_date     date,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists idx_project_tasks_project on public.project_tasks(project_id);

drop trigger if exists trg_project_tasks_updated on public.project_tasks;
create trigger trg_project_tasks_updated before update on public.project_tasks
  for each row execute function public.set_updated_at();

-- ============================================================
--  RLS company-isolation
-- ============================================================
alter table public.projects enable row level security;
alter table public.projects force row level security;

drop policy if exists projects_super on public.projects;
create policy projects_super on public.projects
  for all to authenticated
  using      (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');

drop policy if exists projects_company on public.projects;
create policy projects_company on public.projects
  for all to authenticated
  using (
        public.auth_role() in ('admin','employee')
    and company_id = public.auth_company_id()
  )
  with check (
        public.auth_role() in ('admin','employee')
    and company_id = public.auth_company_id()
  );

alter table public.project_tasks enable row level security;
alter table public.project_tasks force row level security;

drop policy if exists project_tasks_super on public.project_tasks;
create policy project_tasks_super on public.project_tasks
  for all to authenticated
  using      (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');

drop policy if exists project_tasks_company on public.project_tasks;
create policy project_tasks_company on public.project_tasks
  for all to authenticated
  using (
    exists (select 1 from public.projects p
            where p.id = project_tasks.project_id
              and public.auth_role() in ('admin','employee')
              and p.company_id = public.auth_company_id())
  )
  with check (
    exists (select 1 from public.projects p
            where p.id = project_tasks.project_id
              and public.auth_role() in ('admin','employee')
              and p.company_id = public.auth_company_id())
  );

-- ============================================================
--  PERMESSI
-- ============================================================
insert into public.permissions (code, module, description, kind, admin_manageable) values
  ('projects.view',   'projects', 'Visualizzare i progetti', 'generic', true),
  ('projects.create', 'projects', 'Creare progetti', 'generic', true),
  ('projects.edit',   'projects', 'Modificare progetti e attività', 'generic', true),
  ('projects.delete', 'projects', 'Eliminare progetti', 'generic', true)
on conflict (code) do update
  set description = excluded.description, kind = excluded.kind, admin_manageable = excluded.admin_manageable;

insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, p.code,
  case
    when r.role = 'admin' then true
    when r.role = 'employee' then p.code <> 'projects.delete'
    else false
  end
from (select code from public.permissions where module = 'projects') p
cross join (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;

-- ============================================================
--  Licenza demo + progetto di esempio con attività
-- ============================================================
insert into public.licenses (company_id, name, status, price, period, start_date, app_code, app_codes)
select '00000000-0000-0000-0000-000000000001', 'Progetti - mensile', 'active', 15.00, 'monthly',
       current_date, 'projects', array['projects']
where not exists (
  select 1 from public.licenses
  where company_id = '00000000-0000-0000-0000-000000000001'
    and app_codes @> array['projects']
);

do $$
declare
  v_company uuid := '00000000-0000-0000-0000-000000000001';
  v_proj uuid;
begin
  if not exists (select 1 from public.projects where company_id = v_company) then
    insert into public.projects (company_id, name, status, start_date, due_date, budget, manager, description)
    values (v_company, 'Apertura nuova sede', 'active', current_date, current_date + 90,
            25000.00, 'Direzione', 'Allestimento e avvio della nuova sede operativa')
    returning id into v_proj;

    insert into public.project_tasks (project_id, position, title, status, priority, due_date) values
      (v_proj, 0, 'Sopralluogo e planimetrie', 'done', 'high', current_date + 7),
      (v_proj, 1, 'Preventivi arredi e impianti', 'in_progress', 'high', current_date + 20),
      (v_proj, 2, 'Allacci utenze', 'todo', 'medium', current_date + 40),
      (v_proj, 3, 'Trasloco e collaudo', 'todo', 'medium', current_date + 80);
  end if;
end $$;
