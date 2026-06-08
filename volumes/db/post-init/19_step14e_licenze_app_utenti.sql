-- ============================================================
--  SMARTERP · 19_step14e_licenze_app_utenti.sql
--  STEP 14e —
--   1) Una licenza abilita una specifica APP per l'organizzazione
--      (licenses.app_code). Lo decide il super_admin.
--   2) L'admin gestisce di default gli UTENTI della propria org (CRUD),
--      con ruoli limitati e senza uscire dalla propria azienda.
--
--  Eseguire DOPO 18_step14d_isolamento_org.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/19_step14e_licenze_app_utenti.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- App associata alla licenza: invoices|customers|products|chat|studio|suite.
alter table public.licenses
  add column if not exists app_code text not null default 'suite';

update public.licenses set app_code = 'suite'
where name ilike '%suite%';

-- Permesso: l'admin gestisce gli utenti della propria organizzazione.
insert into public.permissions (code, module, description, kind, admin_manageable) values
  ('org.users.manage', 'organization', 'Gestire gli utenti della propria organizzazione', 'generic', false)
on conflict (code) do update
  set description = excluded.description, kind = excluded.kind;

insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, 'org.users.manage',
  case when r.role = 'admin' then true else false end
from (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;

-- ============================================================
--  RPC utenti: super_admin globale; admin SOLO la propria org e con
--  ruoli limitati (mai super_admin).
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
  v_role  text := public.auth_role();
begin
  if v_role = 'super_admin' then
    null; -- ok tutto
  elsif v_role = 'admin' then
    if p_company_id is distinct from public.auth_company_id() then
      raise exception 'L''admin può creare utenti solo nella propria organizzazione';
    end if;
    if p_role not in ('admin','employee','customer') then
      raise exception 'Ruolo non consentito';
    end if;
  else
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
    now(), now(), false, false, false, '', '', '', ''
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
  update public.profiles
     set full_name = p_full_name, role = p_role::public.user_role, company_id = p_company_id
   where id = v_uid;
  return v_uid;
end $$;
grant execute on function public.admin_create_user(text,text,text,text,uuid) to authenticated;

create or replace function public.admin_delete_user(p_uid uuid)
returns void
language plpgsql security definer set search_path = auth, public as $$
declare
  v_role text := public.auth_role();
  v_target_company uuid;
  v_target_role text;
begin
  if p_uid = auth.uid() then
    raise exception 'Non puoi eliminare te stesso';
  end if;
  select company_id, role::text into v_target_company, v_target_role
    from public.profiles where id = p_uid;
  if v_role = 'super_admin' then
    null;
  elsif v_role = 'admin' then
    if v_target_company is distinct from public.auth_company_id()
       or v_target_role = 'super_admin' then
      raise exception 'Non autorizzato su questo utente';
    end if;
  else
    raise exception 'Non autorizzato';
  end if;
  delete from auth.users where id = p_uid;
end $$;
grant execute on function public.admin_delete_user(uuid) to authenticated;

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
     or (public.auth_role() = 'admin' and p.company_id = public.auth_company_id())
  order by c.name nulls first, p.full_name;
$$;
grant execute on function public.admin_list_users() to authenticated;
