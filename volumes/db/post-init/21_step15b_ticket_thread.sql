-- ============================================================
--  SMARTERP · 21_step15b_ticket_thread.sql
--  STEP 15b — Thread di messaggi sul ticket (chat admin↔sviluppatore)
--  con allegati (immagini/file) su Supabase Storage.
--
--  Eseguire DOPO 20_step15a_ticket_notifiche.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/21_step15b_ticket_thread.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

create table if not exists public.ticket_messages (
  id              uuid primary key default uuid_generate_v4(),
  ticket_id       uuid not null references public.tickets(id) on delete cascade,
  sender_id       uuid not null,
  content         text,
  attachment_url  text,
  attachment_name text,
  created_at      timestamptz not null default now()
);
create index if not exists idx_ticket_messages_ticket
  on public.ticket_messages(ticket_id, created_at);

alter table public.ticket_messages enable row level security;
alter table public.ticket_messages force row level security;

-- Visibile a chi può vedere il ticket collegato.
drop policy if exists ticket_msg_select on public.ticket_messages;
create policy ticket_msg_select on public.ticket_messages
  for select to authenticated
  using (
    exists (
      select 1 from public.tickets t
      where t.id = ticket_messages.ticket_id
        and (public.auth_role() = 'super_admin'
             or (public.auth_role() = 'admin' and t.company_id = public.auth_company_id())
             or t.created_by = auth.uid())
    )
  );

drop policy if exists ticket_msg_insert on public.ticket_messages;
create policy ticket_msg_insert on public.ticket_messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.tickets t
      where t.id = ticket_messages.ticket_id
        and (public.auth_role() = 'super_admin'
             or (public.auth_role() = 'admin' and t.company_id = public.auth_company_id())
             or t.created_by = auth.uid())
    )
  );

-- Realtime sui messaggi.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.ticket_messages;
    exception when duplicate_object then null; end;
  end if;
end $$;

-- ============================================================
--  Storage: il servizio (supabase_storage_admin) deve poter assumere i
--  ruoli RLS, altrimenti ogni upload fallisce con "permission denied to
--  set role authenticated".
-- ============================================================
grant anon, authenticated, service_role to supabase_storage_admin;

-- I ruoli RLS devono poter "vedere" lo schema storage (altrimenti viene
-- ignorato nel search_path e le tabelle risultano "inesistenti").
grant usage on schema storage to anon, authenticated, service_role;
grant all on all tables in schema storage to anon, authenticated, service_role;
grant all on all sequences in schema storage to anon, authenticated, service_role;
alter default privileges in schema storage
  grant all on tables to anon, authenticated, service_role;

-- ============================================================
--  Storage: bucket pubblico per gli allegati dei ticket.
-- ============================================================
insert into storage.buckets (id, name, public)
values ('ticket-attachments', 'ticket-attachments', true)
on conflict (id) do update set public = true;

-- Policy su storage.objects: gli autenticati possono caricare/leggere nel bucket.
drop policy if exists ticket_attach_objects on storage.objects;
create policy ticket_attach_objects on storage.objects
  for all to authenticated
  using (bucket_id = 'ticket-attachments')
  with check (bucket_id = 'ticket-attachments');

-- Idem su storage.prefixes (richiesto dalle versioni recenti di storage-api).
do $$
begin
  if to_regclass('storage.prefixes') is not null then
    execute 'alter table storage.prefixes enable row level security';
    execute 'drop policy if exists ticket_attach_prefixes on storage.prefixes';
    execute $p$create policy ticket_attach_prefixes on storage.prefixes
      for all to authenticated
      using (bucket_id = 'ticket-attachments')
      with check (bucket_id = 'ticket-attachments')$p$;
  end if;
end $$;
