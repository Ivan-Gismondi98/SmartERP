-- ============================================================
--  SMARTERP · 23_step18_chat_delete.sql
--  La cancellazione delle stanze chat è riservata ad admin/super_admin.
--  Dipendenti e utenti: possono leggere/scrivere ma NON eliminare.
--
--  Eseguire DOPO 22_step17_fornitori.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/23_step18_chat_delete.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- Sostituisce la policy "for all" con regole per-comando.
drop policy if exists chat_rooms_access on public.chat_rooms;

drop policy if exists chat_rooms_read on public.chat_rooms;
create policy chat_rooms_read on public.chat_rooms
  for select to authenticated
  using (
        public.auth_role() = 'super_admin'
     or (public.auth_role() in ('admin','employee')
         and company_id = public.auth_company_id())
  );

drop policy if exists chat_rooms_insert on public.chat_rooms;
create policy chat_rooms_insert on public.chat_rooms
  for insert to authenticated
  with check (
        public.auth_role() = 'super_admin'
     or (public.auth_role() in ('admin','employee')
         and company_id = public.auth_company_id())
  );

drop policy if exists chat_rooms_update on public.chat_rooms;
create policy chat_rooms_update on public.chat_rooms
  for update to authenticated
  using (
        public.auth_role() = 'super_admin'
     or (public.auth_role() in ('admin','employee')
         and company_id = public.auth_company_id())
  );

-- Eliminazione: solo super_admin o admin della propria azienda.
drop policy if exists chat_rooms_delete on public.chat_rooms;
create policy chat_rooms_delete on public.chat_rooms
  for delete to authenticated
  using (
        public.auth_role() = 'super_admin'
     or (public.auth_role() = 'admin' and company_id = public.auth_company_id())
  );
