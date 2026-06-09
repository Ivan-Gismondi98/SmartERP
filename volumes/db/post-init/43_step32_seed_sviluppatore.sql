-- ============================================================
--  SMARTERP · 43_step32_seed_sviluppatore.sql
--  Dati di DEFAULT importati a ogni prima installazione:
--   - l'utenza dello SVILUPPATORE (super_admin) sempre la stessa
--     (dev@smarterp.local / Dev12345);
--   - i pacchetti di licenza predefiniti sono già seedati (mig. 42).
--
--  Idempotente: crea l'utente solo se non esiste.
--
--  Eseguire DOPO 42_step31d_licenze_default_pacchetti.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/43_step32_seed_sviluppatore.sql
-- ============================================================
\set ON_ERROR_STOP on

do $$
declare
  v_id uuid := 'd0000000-0000-0000-0000-0000000000de';
begin
  if not exists (select 1 from auth.users where email = 'dev@smarterp.local') then
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data, is_super_admin
    ) values (
      '00000000-0000-0000-0000-000000000000', v_id,
      'authenticated', 'authenticated', 'dev@smarterp.local',
      extensions.crypt('Dev12345', extensions.gen_salt('bf')),
      now(), now(), now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object(
        'sub', v_id::text, 'email', 'dev@smarterp.local',
        'full_name', 'Sviluppatore',
        'email_verified', true, 'phone_verified', false),
      false
    );

    -- Identità email (richiesta da GoTrue per il login con password).
    insert into auth.identities (
      provider, provider_id, user_id, identity_data,
      last_sign_in_at, created_at, updated_at
    ) values (
      'email', v_id::text, v_id,
      jsonb_build_object('sub', v_id::text, 'email', 'dev@smarterp.local',
        'email_verified', true),
      now(), now(), now()
    );
  end if;

  -- Profilo sviluppatore (super_admin) senza azienda. Inserito esplicitamente
  -- per non dipendere dal trigger handle_new_user (potrebbe non essere ancora
  -- installato al primo avvio); copre anche il caso di profilo già creato.
  insert into public.profiles (id, full_name, role)
  select u.id, 'Sviluppatore', 'super_admin'
    from auth.users u where u.email = 'dev@smarterp.local'
  on conflict (id) do update
     set role = 'super_admin', full_name = 'Sviluppatore';
end $$;
