-- ============================================================
--  SMARTERP · 15_step14_gestione_utenti.sql
--  STEP 14 — Gestione utenti/ruoli/aziende (super_admin).
--   - RLS su profiles e companies (chiude l'escalation di ruolo).
--   - RPC sicure per creare/eliminare/elencare utenti (schema auth).
--
--  Eseguire DOPO 14_step13_licenze_dashboard.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/15_step14_gestione_utenti.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- ============================================================
--  RLS su profiles
-- ============================================================
alter table public.profiles enable row level security;
alter table public.profiles force row level security;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated
  using (
        public.auth_role() = 'super_admin'
     or id = auth.uid()
     or company_id = public.auth_company_id()
  );

drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles
  for update to authenticated
  using (
        public.auth_role() = 'super_admin'
     or (public.auth_role() = 'admin' and company_id = public.auth_company_id())
  )
  with check (
        public.auth_role() = 'super_admin'
     or (public.auth_role() = 'admin'
         and company_id = public.auth_company_id()
         and role <> 'super_admin')   -- l'admin non può creare super_admin
  );

drop policy if exists profiles_delete on public.profiles;
create policy profiles_delete on public.profiles
  for delete to authenticated
  using (public.auth_role() = 'super_admin');

-- ============================================================
--  RLS su companies (lettura pubblica per join/diagnostica;
--  scrittura solo super_admin, update propria azienda per admin)
-- ============================================================
alter table public.companies enable row level security;

drop policy if exists companies_select on public.companies;
create policy companies_select on public.companies
  for select to anon, authenticated using (true);

drop policy if exists companies_insert on public.companies;
create policy companies_insert on public.companies
  for insert to authenticated
  with check (public.auth_role() = 'super_admin');

drop policy if exists companies_update on public.companies;
create policy companies_update on public.companies
  for update to authenticated
  using (
        public.auth_role() = 'super_admin'
     or (public.auth_role() = 'admin' and id = public.auth_company_id())
  )
  with check (
        public.auth_role() = 'super_admin'
     or (public.auth_role() = 'admin' and id = public.auth_company_id())
  );

drop policy if exists companies_delete on public.companies;
create policy companies_delete on public.companies
  for delete to authenticated
  using (public.auth_role() = 'super_admin');

-- ============================================================
--  RPC: creazione utente (insert in auth.users + identities).
--  Solo super_admin. La password è cifrata bcrypt; email auto-confermata.
-- ============================================================
create or replace function public.admin_create_user(
  p_email      text,
  p_password   text,
  p_full_name  text,
  p_role       text,
  p_company_id uuid
) returns uuid
language plpgsql security definer set search_path = auth, public, extensions as $$
declare
  v_uid   uuid := gen_random_uuid();
  v_email text := lower(trim(p_email));
begin
  if public.auth_role() <> 'super_admin' then
    raise exception 'Non autorizzato';
  end if;
  if exists (select 1 from auth.users where email = v_email) then
    raise exception 'Email già registrata';
  end if;

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at, is_super_admin, is_sso_user, is_anonymous,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values (
    '00000000-0000-0000-0000-000000000000', v_uid, 'authenticated', 'authenticated',
    v_email, crypt(p_password, gen_salt('bf')),
    now(), '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('full_name', p_full_name, 'email', v_email),
    now(), now(), false, false, false,
    '', '', '', ''
  );

  insert into auth.identities (
    provider_id, user_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at
  ) values (
    v_uid::text, v_uid,
    jsonb_build_object('sub', v_uid::text, 'email', v_email,
                       'email_verified', true, 'phone_verified', false),
    'email', now(), now(), now()
  );

  -- Il trigger on_auth_user_created ha creato il profilo: lo aggiorniamo.
  update public.profiles
     set full_name = p_full_name,
         role = p_role::public.user_role,
         company_id = p_company_id
   where id = v_uid;

  return v_uid;
end $$;

grant execute on function public.admin_create_user(text,text,text,text,uuid)
  to authenticated;

-- ============================================================
--  RPC: eliminazione utente (cascade sul profilo).
-- ============================================================
create or replace function public.admin_delete_user(p_uid uuid)
returns void
language plpgsql security definer set search_path = auth, public as $$
begin
  if public.auth_role() <> 'super_admin' then
    raise exception 'Non autorizzato';
  end if;
  if p_uid = auth.uid() then
    raise exception 'Non puoi eliminare te stesso';
  end if;
  delete from auth.users where id = p_uid;
end $$;

grant execute on function public.admin_delete_user(uuid) to authenticated;

-- ============================================================
--  RPC: elenco utenti con email (join auth.users).
-- ============================================================
create or replace function public.admin_list_users()
returns table (
  id uuid, email text, full_name text, role text,
  company_id uuid, company_name text, is_active boolean
)
language sql security definer set search_path = auth, public as $$
  select p.id, u.email::text, p.full_name, p.role::text,
         p.company_id, c.name, p.is_active
  from public.profiles p
  join auth.users u on u.id = p.id
  left join public.companies c on c.id = p.company_id
  where public.auth_role() = 'super_admin'
  order by c.name nulls first, p.full_name;
$$;

grant execute on function public.admin_list_users() to authenticated;

-- ============================================================
--  Permessi (feature, solo super_admin per default).
-- ============================================================
insert into public.permissions (code, module, description, kind) values
  ('users.manage',     'developer', 'Gestire utenti, ruoli e aziende', 'feature'),
  ('companies.manage', 'developer', 'Gestire le organizzazioni', 'feature')
on conflict (code) do update
  set description = excluded.description, kind = excluded.kind;

insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, p.code, false
from (select code from public.permissions where code in ('users.manage','companies.manage')) p
cross join (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;
