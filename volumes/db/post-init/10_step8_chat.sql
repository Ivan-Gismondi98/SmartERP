-- ============================================================
--  SMARTERP · 10_step8_chat.sql
--  STEP 8 — Chat interna realtime: RLS company-isolation su chat_*,
--  permessi del modulo (incl. videochiamata), seed stanza demo.
--
--  Eseguire DOPO 09_step7_branding.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/10_step8_chat.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- ============================================================
--  RLS company-isolation (chat interna staff). Niente subquery
--  ricorsive: le policy di messaggi/partecipanti guardano la stanza.
-- ============================================================
alter table public.chat_rooms enable row level security;
alter table public.chat_rooms force row level security;

drop policy if exists chat_rooms_access on public.chat_rooms;
create policy chat_rooms_access on public.chat_rooms
  for all to authenticated
  using (
        public.auth_role() = 'super_admin'
     or (public.auth_role() in ('admin','employee')
         and company_id = public.auth_company_id())
  )
  with check (
        public.auth_role() = 'super_admin'
     or (public.auth_role() in ('admin','employee')
         and company_id = public.auth_company_id())
  );

alter table public.chat_participants enable row level security;
alter table public.chat_participants force row level security;

drop policy if exists chat_participants_access on public.chat_participants;
create policy chat_participants_access on public.chat_participants
  for all to authenticated
  using (
    exists (
      select 1 from public.chat_rooms r
      where r.id = chat_participants.room_id
        and (public.auth_role() = 'super_admin'
             or (public.auth_role() in ('admin','employee')
                 and r.company_id = public.auth_company_id()))
    )
  )
  with check (
    exists (
      select 1 from public.chat_rooms r
      where r.id = chat_participants.room_id
        and (public.auth_role() = 'super_admin'
             or (public.auth_role() in ('admin','employee')
                 and r.company_id = public.auth_company_id()))
    )
  );

alter table public.chat_messages enable row level security;
alter table public.chat_messages force row level security;

drop policy if exists chat_messages_access on public.chat_messages;
create policy chat_messages_access on public.chat_messages
  for all to authenticated
  using (
    exists (
      select 1 from public.chat_rooms r
      where r.id = chat_messages.room_id
        and (public.auth_role() = 'super_admin'
             or (public.auth_role() in ('admin','employee')
                 and r.company_id = public.auth_company_id()))
    )
  )
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.chat_rooms r
      where r.id = chat_messages.room_id
        and (public.auth_role() = 'super_admin'
             or (public.auth_role() in ('admin','employee')
                 and r.company_id = public.auth_company_id()))
    )
  );

-- ============================================================
--  Permessi modulo chat (chat.video = feature, gli altri generici).
-- ============================================================
insert into public.permissions (code, module, description, kind) values
  ('chat.view',   'chat', 'Accedere alla chat interna', 'generic'),
  ('chat.send',   'chat', 'Inviare messaggi in chat', 'generic'),
  ('chat.manage', 'chat', 'Creare/gestire le stanze chat', 'generic'),
  ('chat.video',  'chat', 'Avviare videochiamate', 'feature')
on conflict (code) do update
  set description = excluded.description, kind = excluded.kind;

insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, p.code,
  case
    when r.role in ('admin','employee') then true
    else false
  end
from (select code from public.permissions where module = 'chat') p
cross join (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;

-- ============================================================
--  Realtime: assicura che chat_messages sia nella publication.
-- ============================================================
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.chat_messages;
    exception when duplicate_object then null; end;
  end if;
end $$;

-- ============================================================
--  Seed: stanza "Generale" per l'azienda demo + admin partecipante.
-- ============================================================
do $$
declare
  v_admin uuid;
  v_room  uuid;
begin
  select id into v_admin from public.profiles
   where company_id = '00000000-0000-0000-0000-000000000001'
     and role = 'admin' limit 1;

  if v_admin is not null then
    select id into v_room from public.chat_rooms
     where company_id = '00000000-0000-0000-0000-000000000001'
       and name = 'Generale' limit 1;

    if v_room is null then
      insert into public.chat_rooms (company_id, name, is_group, created_by)
      values ('00000000-0000-0000-0000-000000000001', 'Generale', true, v_admin)
      returning id into v_room;
    end if;

    insert into public.chat_participants (room_id, profile_id)
    values (v_room, v_admin)
    on conflict (room_id, profile_id) do nothing;

    insert into public.chat_messages (room_id, sender_id, content)
    values (v_room, v_admin, 'Benvenuto nella chat interna di SmartERP!');
  end if;
end $$;
