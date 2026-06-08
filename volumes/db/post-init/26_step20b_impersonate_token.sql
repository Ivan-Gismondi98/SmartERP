-- ============================================================
--  SMARTERP · 26_step20b_impersonate_token.sql
--  Impersonate REALE: il super_admin ottiene un JWT firmato per l'utente
--  target, così le query (PostgREST/Storage) girano con la RLS di quell'utente
--  e mostrano i dati della SUA organizzazione.
--
--  NB: il segreto deve combaciare con GOTRUE_JWT_SECRET / PGRST_JWT_SECRET.
--  Qui è il valore demo del .env; in produzione allinealo al tuo segreto.
--
--  Eseguire DOPO 25_step20_impersonate.sql + NOTIFY reload.
-- ============================================================
\set ON_ERROR_STOP on

-- pgjwt (schema extensions) richiede hmac/digest nello stesso schema:
-- spostiamo pgcrypto in 'extensions' se ancora in 'public'.
do $$
begin
  if exists (
    select 1 from pg_extension e join pg_namespace n on n.oid = e.extnamespace
    where e.extname = 'pgcrypto' and n.nspname = 'public'
  ) then
    execute 'alter extension pgcrypto set schema extensions';
  end if;
end $$;

create or replace function public.dev_impersonate(p_target uuid)
returns text
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_secret text := 'your-super-secret-jwt-token-with-at-least-32-characters-long';
  v_email  text;
  v_now    int := floor(extract(epoch from now()))::int;
  v_token  text;
begin
  if public.auth_role() <> 'super_admin' then
    raise exception 'Non autorizzato';
  end if;
  select email into v_email from auth.users where id = p_target;
  if v_email is null then
    raise exception 'Utente inesistente';
  end if;

  v_token := extensions.sign(
    json_build_object(
      'aud', 'authenticated',
      'role', 'authenticated',
      'sub', p_target::text,
      'email', v_email,
      'iss', 'supabase-smarterp',
      'iat', v_now,
      'exp', v_now + 3600
    ),
    v_secret,
    'HS256'
  );
  return v_token;
end $$;

grant execute on function public.dev_impersonate(uuid) to authenticated;
