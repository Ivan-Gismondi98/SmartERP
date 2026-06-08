-- ============================================================
--  SMARTERP · 08_step6_impostazioni_sdi.sql
--  STEP 6 — Sistema Impostazioni configurabile + firma/invio SdI.
--   - permissions.kind: distingue permessi 'generic' (CRUD) da 'feature'.
--   - app_settings: impostazioni chiave/valore per azienda, con scope
--     'general' oppure per-applicativo ('invoices', 'products', ...).
--   - feature toggle SdI (mostra/nascondi blocco firma/invio).
--
--  Eseguire DOPO 07_step5b_distinta_base.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/08_step6_impostazioni_sdi.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- ============================================================
--  A) Classificazione permessi: generic (CRUD) vs feature (capacita').
-- ============================================================
alter table public.permissions
  add column if not exists kind text not null default 'generic';

update public.permissions set kind = 'feature'
where code in (
  'invoices.issue', 'invoices.export', 'invoices.print',
  'products.produce'
);

-- ============================================================
--  B) Impostazioni applicazione (chiave/valore per azienda + scope).
--     scope: 'general' oppure nome modulo ('invoices', 'products', ...).
-- ============================================================
create table if not exists public.app_settings (
  id          uuid primary key default uuid_generate_v4(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  scope       text not null,
  key         text not null,
  value       jsonb not null default 'null'::jsonb,
  updated_at  timestamptz not null default now(),
  unique (company_id, scope, key)
);
create index if not exists idx_app_settings_company on public.app_settings(company_id, scope);

drop trigger if exists trg_app_settings_updated on public.app_settings;
create trigger trg_app_settings_updated before update on public.app_settings
  for each row execute function public.set_updated_at();

alter table public.app_settings enable row level security;
alter table public.app_settings force row level security;

drop policy if exists app_settings_read on public.app_settings;
create policy app_settings_read on public.app_settings
  for select to authenticated
  using (company_id = public.auth_company_id() or public.auth_role() = 'super_admin');

drop policy if exists app_settings_write on public.app_settings;
create policy app_settings_write on public.app_settings
  for all to authenticated
  using (
        public.auth_role() = 'super_admin'
     or (public.auth_role() = 'admin' and company_id = public.auth_company_id())
  )
  with check (
        public.auth_role() = 'super_admin'
     or (public.auth_role() = 'admin' and company_id = public.auth_company_id())
  );

-- ============================================================
--  C) Permesso di feature: invio allo SdI.
-- ============================================================
insert into public.permissions (code, module, description, kind) values
  ('invoices.sdi_send', 'invoices', 'Firmare/inviare la fattura allo SdI', 'feature')
on conflict (code) do update
  set description = excluded.description, kind = excluded.kind;

insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, 'invoices.sdi_send',
  case when r.role = 'admin' then true else false end
from (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;

-- ============================================================
--  D) Stato trasmissione SdI sulla fattura.
--     Valori: not_sent | sent | delivered | rejected (placeholder locale,
--     l'integrazione reale con lo SdI richiede accreditamento + firma).
-- ============================================================
alter table public.invoices add column if not exists sdi_status text not null default 'not_sent';
alter table public.invoices add column if not exists sdi_sent_at timestamptz;

-- Default del feature toggle SdI per l'azienda demo: disattivato.
insert into public.app_settings (company_id, scope, key, value)
values ('00000000-0000-0000-0000-000000000001', 'invoices', 'sdi_enabled', 'false'::jsonb)
on conflict (company_id, scope, key) do nothing;
