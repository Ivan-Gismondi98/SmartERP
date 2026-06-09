-- ============================================================
--  SMARTERP · 32_step25_contabilita.sql
--  Modulo CONTABILITÀ (finanziaria e analitica), partita doppia.
--   - Piano dei conti (accounting_accounts)
--   - Centri di costo (accounting_cost_centers) → contabilità analitica
--   - Prima nota / registrazioni (accounting_entries + accounting_lines)
--     con vincolo dare = avere (partita doppia, art. 2214 c.c.).
--
--  Applicativo licenziabile (app_code 'accounting').
--
--  Eseguire DOPO 31_step24_crm.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/32_step25_contabilita.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- ============================================================
--  SEZIONE A — TABELLE
-- ============================================================

-- Piano dei conti. nature: attivo|passivo|patrimonio|costo|ricavo
create table if not exists public.accounting_accounts (
  id          uuid primary key default uuid_generate_v4(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  code        text not null,
  name        text not null,
  nature      text not null default 'costo',
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (company_id, code)
);
create index if not exists idx_acc_accounts_company on public.accounting_accounts(company_id);

drop trigger if exists trg_acc_accounts_updated on public.accounting_accounts;
create trigger trg_acc_accounts_updated before update on public.accounting_accounts
  for each row execute function public.set_updated_at();

-- Centri di costo (contabilità analitica).
create table if not exists public.accounting_cost_centers (
  id          uuid primary key default uuid_generate_v4(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  code        text not null,
  name        text not null,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (company_id, code)
);
create index if not exists idx_acc_cc_company on public.accounting_cost_centers(company_id);

drop trigger if exists trg_acc_cc_updated on public.accounting_cost_centers;
create trigger trg_acc_cc_updated before update on public.accounting_cost_centers
  for each row execute function public.set_updated_at();

-- Registrazioni (testata prima nota).
create table if not exists public.accounting_entries (
  id             uuid primary key default uuid_generate_v4(),
  company_id     uuid not null references public.companies(id) on delete cascade,
  entry_date     date not null default current_date,
  description    text not null default '',
  doc_ref        text,
  entry_number   text,
  numbering_year int,
  numbering_seq  int,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index if not exists idx_acc_entries_company on public.accounting_entries(company_id);
create index if not exists idx_acc_entries_date on public.accounting_entries(entry_date);

drop trigger if exists trg_acc_entries_updated on public.accounting_entries;
create trigger trg_acc_entries_updated before update on public.accounting_entries
  for each row execute function public.set_updated_at();

-- Righe (movimenti dare/avere).
create table if not exists public.accounting_lines (
  id             uuid primary key default uuid_generate_v4(),
  entry_id       uuid not null references public.accounting_entries(id) on delete cascade,
  position       int not null default 0,
  account_id     uuid not null references public.accounting_accounts(id) on delete restrict,
  description    text,
  debit          numeric(14,2) not null default 0,   -- dare
  credit         numeric(14,2) not null default 0,   -- avere
  cost_center_id uuid references public.accounting_cost_centers(id) on delete set null
);
create index if not exists idx_acc_lines_entry on public.accounting_lines(entry_id);
create index if not exists idx_acc_lines_account on public.accounting_lines(account_id);

-- ============================================================
--  SEZIONE B — NUMERAZIONE PROGRESSIVA (per azienda, anno)
-- ============================================================
create or replace function public.assign_journal_number(
  p_entry_id uuid
) returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_company uuid;
  v_year    int;
  v_seq     int;
  v_number  text;
begin
  select company_id, coalesce(numbering_year, extract(year from entry_date)::int)
    into v_company, v_year
  from public.accounting_entries
  where id = p_entry_id
  for update;

  if v_company is null then
    raise exception 'Registrazione % inesistente', p_entry_id;
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(v_company::text || ':journal:' || v_year::text, 44));

  select coalesce(max(numbering_seq), 0) + 1
    into v_seq
  from public.accounting_entries
  where company_id = v_company
    and numbering_year = v_year
    and numbering_seq is not null;

  v_number := v_seq::text || '/' || v_year::text;

  update public.accounting_entries
     set numbering_year = v_year,
         numbering_seq  = v_seq,
         entry_number   = v_number
   where id = p_entry_id;

  return v_number;
end;
$$;

grant execute on function public.assign_journal_number(uuid)
  to authenticated, service_role;

-- ============================================================
--  SEZIONE C — RLS company-isolation
-- ============================================================
do $$
declare t text;
begin
  foreach t in array array['accounting_accounts','accounting_cost_centers','accounting_entries'] loop
    execute format('alter table public.%I enable row level security;', t);
    execute format('alter table public.%I force row level security;', t);
    execute format('drop policy if exists %I_super on public.%I;', t, t);
    execute format($p$create policy %I_super on public.%I for all to authenticated
        using (public.auth_role() = 'super_admin')
        with check (public.auth_role() = 'super_admin');$p$, t, t);
    execute format('drop policy if exists %I_company on public.%I;', t, t);
    execute format($p$create policy %I_company on public.%I for all to authenticated
        using (public.auth_role() in ('admin','employee') and company_id = public.auth_company_id())
        with check (public.auth_role() in ('admin','employee') and company_id = public.auth_company_id());$p$, t, t);
  end loop;
end $$;

-- Righe: l'accesso segue la registrazione collegata.
alter table public.accounting_lines enable row level security;
alter table public.accounting_lines force row level security;

drop policy if exists accounting_lines_super on public.accounting_lines;
create policy accounting_lines_super on public.accounting_lines
  for all to authenticated
  using      (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');

drop policy if exists accounting_lines_company on public.accounting_lines;
create policy accounting_lines_company on public.accounting_lines
  for all to authenticated
  using (
    exists (select 1 from public.accounting_entries e
            where e.id = accounting_lines.entry_id
              and public.auth_role() in ('admin','employee')
              and e.company_id = public.auth_company_id())
  )
  with check (
    exists (select 1 from public.accounting_entries e
            where e.id = accounting_lines.entry_id
              and public.auth_role() in ('admin','employee')
              and e.company_id = public.auth_company_id())
  );

-- ============================================================
--  SEZIONE D — PERMESSI
-- ============================================================
insert into public.permissions (code, module, description, kind, admin_manageable) values
  ('accounting.view',   'accounting', 'Visualizzare la contabilità', 'generic', true),
  ('accounting.create', 'accounting', 'Creare registrazioni di prima nota', 'generic', true),
  ('accounting.edit',   'accounting', 'Modificare registrazioni', 'generic', true),
  ('accounting.delete', 'accounting', 'Eliminare registrazioni', 'generic', true),
  ('accounting.manage', 'accounting', 'Gestire piano dei conti e centri di costo', 'generic', true)
on conflict (code) do update
  set description = excluded.description, kind = excluded.kind, admin_manageable = excluded.admin_manageable;

insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, p.code,
  case
    when r.role = 'admin' then true
    when r.role = 'employee' then p.code in ('accounting.view','accounting.create','accounting.edit')
    else false
  end
from (select code from public.permissions where module = 'accounting') p
cross join (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;

-- ============================================================
--  SEZIONE E — Licenza demo + seed piano dei conti / centri di costo
-- ============================================================
insert into public.licenses (company_id, name, status, price, period, start_date, app_code, app_codes)
select '00000000-0000-0000-0000-000000000001', 'Contabilità - mensile', 'active', 25.00, 'monthly',
       current_date, 'accounting', array['accounting']
where not exists (
  select 1 from public.licenses
  where company_id = '00000000-0000-0000-0000-000000000001'
    and app_codes @> array['accounting']
);

-- Piano dei conti semplificato (azienda demo).
insert into public.accounting_accounts (company_id, code, name, nature)
select '00000000-0000-0000-0000-000000000001', v.code, v.name, v.nature
from (values
  ('10.01', 'Cassa', 'attivo'),
  ('10.05', 'Banca c/c', 'attivo'),
  ('15.01', 'Crediti verso clienti', 'attivo'),
  ('15.10', 'IVA a credito', 'attivo'),
  ('18.01', 'Immobilizzazioni materiali', 'attivo'),
  ('20.01', 'Debiti verso fornitori', 'passivo'),
  ('20.10', 'IVA a debito', 'passivo'),
  ('20.20', 'Debiti verso banche', 'passivo'),
  ('25.01', 'Capitale sociale', 'patrimonio'),
  ('25.10', 'Riserve', 'patrimonio'),
  ('25.20', 'Utile/perdita d''esercizio', 'patrimonio'),
  ('40.01', 'Merci c/acquisti', 'costo'),
  ('40.10', 'Costi per servizi', 'costo'),
  ('40.20', 'Salari e stipendi', 'costo'),
  ('40.30', 'Ammortamenti', 'costo'),
  ('40.40', 'Interessi passivi', 'costo'),
  ('50.01', 'Merci c/vendite (Ricavi)', 'ricavo'),
  ('50.10', 'Interessi attivi', 'ricavo')
) as v(code, name, nature)
where not exists (
  select 1 from public.accounting_accounts a
  where a.company_id = '00000000-0000-0000-0000-000000000001' and a.code = v.code
);

insert into public.accounting_cost_centers (company_id, code, name)
select '00000000-0000-0000-0000-000000000001', v.code, v.name
from (values ('CC01', 'Amministrazione'), ('CC02', 'Produzione'), ('CC03', 'Commerciale')) as v(code, name)
where not exists (
  select 1 from public.accounting_cost_centers c
  where c.company_id = '00000000-0000-0000-0000-000000000001' and c.code = v.code
);

-- Registrazione di esempio: vendita con IVA (Crediti = Ricavi + IVA a debito).
do $$
declare
  v_company uuid := '00000000-0000-0000-0000-000000000001';
  v_entry uuid;
  v_cred uuid; v_ric uuid; v_iva uuid;
begin
  if not exists (select 1 from public.accounting_entries where company_id = v_company) then
    select id into v_cred from public.accounting_accounts where company_id = v_company and code = '15.01';
    select id into v_ric  from public.accounting_accounts where company_id = v_company and code = '50.01';
    select id into v_iva  from public.accounting_accounts where company_id = v_company and code = '20.10';

    insert into public.accounting_entries (company_id, entry_date, description, doc_ref, numbering_year, numbering_seq, entry_number)
    values (v_company, current_date, 'Vendita merci con IVA 22%', 'Ft. 1/2026',
            extract(year from current_date)::int, 1, '1/' || extract(year from current_date)::int)
    returning id into v_entry;

    insert into public.accounting_lines (entry_id, position, account_id, description, debit, credit) values
      (v_entry, 0, v_cred, 'Credito v/cliente', 1220.00, 0),
      (v_entry, 1, v_ric,  'Ricavo vendita',       0, 1000.00),
      (v_entry, 2, v_iva,  'IVA a debito 22%',      0,  220.00);
  end if;
end $$;
