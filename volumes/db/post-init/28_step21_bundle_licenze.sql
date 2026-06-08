-- ============================================================
--  SMARTERP · 28_step21_bundle_licenze.sql
--  Pacchetti di licenze (bundle): il super_admin definisce aggregati di
--  più app riutilizzabili. Una licenza assegnata a un'organizzazione può
--  abilitare più app (app_codes[]).
--
--  Eseguire DOPO 27_step20c_licenze_read.sql + NOTIFY reload.
-- ============================================================
\set ON_ERROR_STOP on

-- Catalogo bundle (gestito dal super_admin).
create table if not exists public.app_bundles (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null,
  description text,
  app_codes   text[] not null default '{}',
  price       numeric(12,2) not null default 0,
  period      text not null default 'monthly',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

drop trigger if exists trg_app_bundles_updated on public.app_bundles;
create trigger trg_app_bundles_updated before update on public.app_bundles
  for each row execute function public.set_updated_at();

alter table public.app_bundles enable row level security;
alter table public.app_bundles force row level security;
drop policy if exists app_bundles_super on public.app_bundles;
create policy app_bundles_super on public.app_bundles
  for all to authenticated
  using (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');

-- Una licenza può abilitare più app: app_codes[]. (app_code resta per compat.)
alter table public.licenses add column if not exists app_codes text[];
update public.licenses
   set app_codes = case when app_code = 'suite' then array['suite']
                        else array[app_code] end
 where app_codes is null;

-- Seed: un paio di pacchetti d'esempio.
insert into public.app_bundles (name, description, app_codes, price, period)
select 'Pacchetto Base', 'Fatture + Clienti', array['invoices','customers'], 29.00, 'monthly'
where not exists (select 1 from public.app_bundles where name = 'Pacchetto Base');

insert into public.app_bundles (name, description, app_codes, price, period)
select 'Pacchetto Pro', 'Fatture + Clienti + Magazzino + Chat + Studio',
       array['invoices','customers','products','chat','studio'], 79.00, 'monthly'
where not exists (select 1 from public.app_bundles where name = 'Pacchetto Pro');
