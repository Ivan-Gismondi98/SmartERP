-- ============================================================
--  SMARTERP · 34_step27_produzione.sql
--  Modulo PRODUZIONE: ordini di produzione che pianificano e tracciano la
--  fabbricazione di prodotti componibili. Le distinte basi (bom_components)
--  e l'RPC produce_product esistono già (step 5b): qui si aggiunge il
--  livello "ordine" con esecuzione atomica del consumo materiali.
--
--  Applicativo licenziabile (app_code 'production').
--
--  Eseguire DOPO 33_step26_documenti.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/34_step27_produzione.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- ============================================================
--  TABELLA — ordini di produzione
-- ============================================================
create table if not exists public.production_orders (
  id             uuid primary key default uuid_generate_v4(),
  company_id     uuid not null references public.companies(id) on delete cascade,
  product_id     uuid not null references public.products(id) on delete restrict,
  quantity       numeric(12,3) not null default 1,
  status         text not null default 'draft',  -- draft|confirmed|in_progress|done|cancelled
  order_number   text,
  numbering_year int,
  numbering_seq  int,
  planned_date   date,
  started_at     timestamptz,
  completed_at   timestamptz,
  notes          text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index if not exists idx_prod_orders_company on public.production_orders(company_id);
create index if not exists idx_prod_orders_status on public.production_orders(status);

drop trigger if exists trg_prod_orders_updated on public.production_orders;
create trigger trg_prod_orders_updated before update on public.production_orders
  for each row execute function public.set_updated_at();

-- ============================================================
--  RLS company-isolation
-- ============================================================
alter table public.production_orders enable row level security;
alter table public.production_orders force row level security;

drop policy if exists prod_orders_super on public.production_orders;
create policy prod_orders_super on public.production_orders
  for all to authenticated
  using      (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');

drop policy if exists prod_orders_company on public.production_orders;
create policy prod_orders_company on public.production_orders
  for all to authenticated
  using (
        public.auth_role() in ('admin','employee')
    and company_id = public.auth_company_id()
  )
  with check (
        public.auth_role() in ('admin','employee')
    and company_id = public.auth_company_id()
  );

-- ============================================================
--  NUMERAZIONE PROGRESSIVA (per azienda, anno)
-- ============================================================
create or replace function public.assign_production_number(
  p_order_id uuid
) returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_company uuid;
  v_year    int;
  v_seq     int;
  v_number  text;
begin
  select company_id, coalesce(numbering_year, extract(year from coalesce(planned_date, current_date))::int)
    into v_company, v_year
  from public.production_orders
  where id = p_order_id
  for update;

  if v_company is null then
    raise exception 'Ordine di produzione % inesistente', p_order_id;
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(v_company::text || ':production:' || v_year::text, 45));

  select coalesce(max(numbering_seq), 0) + 1
    into v_seq
  from public.production_orders
  where company_id = v_company
    and numbering_year = v_year
    and numbering_seq is not null;

  v_number := 'OP ' || v_seq::text || '/' || v_year::text;

  update public.production_orders
     set numbering_year = v_year,
         numbering_seq  = v_seq,
         order_number   = v_number
   where id = p_order_id;

  return v_number;
end;
$$;

grant execute on function public.assign_production_number(uuid)
  to authenticated, service_role;

-- ============================================================
--  RPC — completa l'ordine: consuma i componenti della distinta base e
--  incrementa il prodotto finito (atomico). Guard anti-doppia esecuzione.
-- ============================================================
create or replace function public.complete_production_order(
  p_order_id uuid
) returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_company uuid;
  v_product uuid;
  v_qty     numeric;
  v_status  text;
  v_count   int;
  r         record;
begin
  select company_id, product_id, quantity, status
    into v_company, v_product, v_qty, v_status
  from public.production_orders
  where id = p_order_id
  for update;

  if v_company is null then
    raise exception 'Ordine inesistente';
  end if;
  if not (public.auth_role() = 'super_admin'
          or v_company = public.auth_company_id()) then
    raise exception 'Non autorizzato';
  end if;
  if v_status = 'done' then
    raise exception 'Ordine già completato';
  end if;
  if v_status = 'cancelled' then
    raise exception 'Ordine annullato';
  end if;
  if v_qty is null or v_qty <= 0 then
    raise exception 'Quantità da produrre non valida';
  end if;

  select count(*) into v_count
  from public.bom_components where product_id = v_product;
  if v_count = 0 then
    raise exception 'Il prodotto non ha una distinta base';
  end if;

  -- Verifica disponibilità di tutti i componenti.
  for r in
    select b.component_id, b.quantity * v_qty as needed,
           coalesce(i.quantity, 0) as available, p.name as comp_name
    from public.bom_components b
    join public.products p on p.id = b.component_id
    left join public.inventory i on i.product_id = b.component_id
    where b.product_id = v_product
  loop
    if r.available < r.needed then
      raise exception 'Componente "%" insufficiente: servono %, disponibili %',
        r.comp_name, r.needed, r.available;
    end if;
  end loop;

  -- Scarica i componenti.
  update public.inventory i
     set quantity = i.quantity - (b.quantity * v_qty)::int,
         updated_at = now()
  from public.bom_components b
  where b.product_id = v_product
    and i.product_id = b.component_id;

  -- Incrementa (o crea) la giacenza del finito.
  insert into public.inventory (company_id, product_id, quantity, reorder_level)
  values (v_company, v_product, v_qty::int, 0)
  on conflict (product_id)
  do update set quantity = public.inventory.quantity + (v_qty)::int,
                updated_at = now();

  update public.production_orders
     set status = 'done', completed_at = now(),
         started_at = coalesce(started_at, now())
   where id = p_order_id;
end;
$$;

grant execute on function public.complete_production_order(uuid)
  to authenticated, service_role;

-- ============================================================
--  PERMESSI
-- ============================================================
insert into public.permissions (code, module, description, kind, admin_manageable) values
  ('production.view',    'production', 'Visualizzare gli ordini di produzione', 'generic', true),
  ('production.create',  'production', 'Creare ordini di produzione', 'generic', true),
  ('production.edit',    'production', 'Modificare ordini di produzione', 'generic', true),
  ('production.delete',  'production', 'Eliminare ordini di produzione', 'generic', true),
  ('production.execute', 'production', 'Eseguire/completare gli ordini di produzione', 'generic', true),
  ('production.bom',     'production', 'Gestire le distinte basi', 'generic', true)
on conflict (code) do update
  set description = excluded.description, kind = excluded.kind, admin_manageable = excluded.admin_manageable;

insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, p.code,
  case
    when r.role = 'admin' then true
    when r.role = 'employee' then p.code <> 'production.delete'
    else false
  end
from (select code from public.permissions where module = 'production') p
cross join (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;

-- ============================================================
--  Licenza demo
-- ============================================================
insert into public.licenses (company_id, name, status, price, period, start_date, app_code, app_codes)
select '00000000-0000-0000-0000-000000000001', 'Produzione - mensile', 'active', 29.00, 'monthly',
       current_date, 'production', array['production']
where not exists (
  select 1 from public.licenses
  where company_id = '00000000-0000-0000-0000-000000000001'
    and app_codes @> array['production']
);
