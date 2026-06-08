-- ============================================================
--  SMARTERP · 20_step15a_ticket_notifiche.sql
--  STEP 15a — Segnalazioni/ticket:
--   - dipendente → notifica al proprio AMMINISTRATORE;
--   - admin → notifica allo SVILUPPATORE.
--  Ticket con stato di avanzamento; realtime per le notifiche.
--
--  Eseguire DOPO 19_step14e_licenze_app_utenti.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/20_step15a_ticket_notifiche.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- Destinatario della segnalazione: 'admin' (interno azienda) | 'developer'.
alter table public.tickets add column if not exists target text not null default 'developer';

-- ----- RLS ticket: emp vede i propri; admin la propria azienda; super tutto.
drop policy if exists tickets_super on public.tickets;
drop policy if exists tickets_admin on public.tickets;
drop policy if exists tickets_select on public.tickets;
drop policy if exists tickets_insert on public.tickets;
drop policy if exists tickets_update on public.tickets;
drop policy if exists tickets_delete on public.tickets;

create policy tickets_select on public.tickets
  for select to authenticated
  using (
        public.auth_role() = 'super_admin'
     or (public.auth_role() = 'admin' and company_id = public.auth_company_id())
     or created_by = auth.uid()
  );

create policy tickets_insert on public.tickets
  for insert to authenticated
  with check (
        created_by = auth.uid()
    and (public.auth_role() = 'super_admin'
         or company_id = public.auth_company_id())
  );

-- Aggiornamento stato: super (qualsiasi) o admin della propria azienda.
create policy tickets_update on public.tickets
  for update to authenticated
  using (
        public.auth_role() = 'super_admin'
     or (public.auth_role() = 'admin' and company_id = public.auth_company_id())
  )
  with check (
        public.auth_role() = 'super_admin'
     or (public.auth_role() = 'admin' and company_id = public.auth_company_id())
  );

create policy tickets_delete on public.tickets
  for delete to authenticated
  using (public.auth_role() = 'super_admin');

-- Realtime sui ticket (notifiche in tempo reale).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.tickets;
    exception when duplicate_object then null; end;
  end if;
end $$;

-- ----- Permessi: vedere i ticket; gli impiegati vedono i propri errori.
insert into public.permissions (code, module, description, kind, admin_manageable) values
  ('tickets.view', 'support', 'Vedere le segnalazioni/ticket', 'generic', true)
on conflict (code) do update set description = excluded.description;

insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, 'tickets.view',
  case when r.role in ('admin','employee') then true else false end
from (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;

-- L'impiegato può vedere i PROPRI errori (per segnalarli all'admin).
update public.role_permissions set allowed = true
where company_id is null and role = 'employee' and permission_code = 'errors.view';
insert into public.role_permissions (company_id, role, permission_code, allowed)
values (null, 'employee', 'errors.view', true)
on conflict do nothing;
