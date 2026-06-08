-- ============================================================
--  SMARTERP · 99_smarterp_post_auth.sql
--  DA ESEGUIRE MANUALMENTE UNA SOLA VOLTA, dopo il primo avvio
--  riuscito di GoTrue (smarterp-auth in stato "Up", non Restarting).
--
--  Cosa fa:
--   1) aggancia public.profiles.id come FK verso auth.users(id);
--   2) installa il trigger che auto-crea un profilo all'iscrizione.
--
--  Comando per lanciarlo (dalla cartella del progetto):
--   docker exec -i smarterp-db psql -U postgres -d postgres \
--     < volumes/db/post-init/99_smarterp_post_auth.sql
-- ============================================================
\set ON_ERROR_STOP on

-- 1) FK profiles.id -> auth.users(id)
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where  table_schema = 'public'
      and  table_name   = 'profiles'
      and  constraint_name = 'profiles_id_fkey'
  ) then
    alter table public.profiles
      add constraint profiles_id_fkey
      foreign key (id) references auth.users(id) on delete cascade;
  end if;
end $$;

-- 2) Funzione che crea automaticamente un profilo a ogni nuovo utente auth
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public, auth
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.email),
    'customer'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- 3) Trigger sulla insert in auth.users
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 4) Pubblica chat/invoices su Realtime (se la publication esiste gia')
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.chat_messages;
    exception when duplicate_object then null; end;
    begin
      alter publication supabase_realtime add table public.invoices;
    exception when duplicate_object then null; end;
  end if;
end $$;
