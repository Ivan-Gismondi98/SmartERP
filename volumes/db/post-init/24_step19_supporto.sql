-- ============================================================
--  SMARTERP · 24_step19_supporto.sql
--  Canale "Supporto": DM dedicato, sempre presente e NON cancellabile.
--   - kind 'user_admin'  : dipendente/utente  <-> amministratori dell'azienda
--   - kind 'admin_dev'   : amministratore     <-> sviluppatore (super_admin)
--
--  Eseguire DOPO 23_step18_chat_delete.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/24_step19_supporto.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

create table if not exists public.direct_threads (
  id          uuid primary key default uuid_generate_v4(),
  company_id  uuid references public.companies(id) on delete cascade,
  kind        text not null check (kind in ('user_admin','admin_dev')),
  owner_id    uuid not null,                 -- la parte "che apre" il canale
  created_at  timestamptz not null default now(),
  unique (kind, owner_id)
);
create index if not exists idx_direct_threads_company on public.direct_threads(company_id);

create table if not exists public.direct_messages (
  id              uuid primary key default uuid_generate_v4(),
  thread_id       uuid not null references public.direct_threads(id) on delete cascade,
  sender_id       uuid not null,
  content         text,
  attachment_url  text,
  attachment_name text,
  created_at      timestamptz not null default now()
);
create index if not exists idx_direct_messages_thread on public.direct_messages(thread_id, created_at);

-- ----- RLS direct_threads -----
alter table public.direct_threads enable row level security;
alter table public.direct_threads force row level security;

-- Chi può vedere un thread: il proprietario; gli admin dell'azienda per i
-- thread 'user_admin'; il super_admin per tutto (inclusi gli 'admin_dev').
drop policy if exists direct_threads_select on public.direct_threads;
create policy direct_threads_select on public.direct_threads
  for select to authenticated
  using (
        public.auth_role() = 'super_admin'
     or owner_id = auth.uid()
     or (kind = 'user_admin' and public.auth_role() = 'admin'
         and company_id = public.auth_company_id())
  );

drop policy if exists direct_threads_insert on public.direct_threads;
create policy direct_threads_insert on public.direct_threads
  for insert to authenticated
  with check (owner_id = auth.uid());
-- Nessuna policy di DELETE/UPDATE: i canali NON sono cancellabili.

-- ----- RLS direct_messages -----
alter table public.direct_messages enable row level security;
alter table public.direct_messages force row level security;

drop policy if exists direct_messages_select on public.direct_messages;
create policy direct_messages_select on public.direct_messages
  for select to authenticated
  using (
    exists (
      select 1 from public.direct_threads t
      where t.id = direct_messages.thread_id
        and (public.auth_role() = 'super_admin'
             or t.owner_id = auth.uid()
             or (t.kind = 'user_admin' and public.auth_role() = 'admin'
                 and t.company_id = public.auth_company_id()))
    )
  );

drop policy if exists direct_messages_insert on public.direct_messages;
create policy direct_messages_insert on public.direct_messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.direct_threads t
      where t.id = direct_messages.thread_id
        and (public.auth_role() = 'super_admin'
             or t.owner_id = auth.uid()
             or (t.kind = 'user_admin' and public.auth_role() = 'admin'
                 and t.company_id = public.auth_company_id()))
    )
  );

-- Realtime (se/quando il WebSocket è disponibile).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin alter publication supabase_realtime add table public.direct_messages;
    exception when duplicate_object then null; end;
  end if;
end $$;
