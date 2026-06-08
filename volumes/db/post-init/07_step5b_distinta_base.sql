-- ============================================================
--  SMARTERP · 07_step5b_distinta_base.sql
--  STEP 5b — Distinta base (DiBa/BOM) e prodotti componibili.
--  Un prodotto "componibile" si costruisce da altri prodotti
--  (componenti) elencati nella distinta base. La produzione consuma
--  i componenti dal magazzino e incrementa il prodotto finito.
--
--  Eseguire DOPO 06_step5_magazzino.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/07_step5b_distinta_base.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- Flag: il prodotto e' costruibile da una distinta base.
alter table public.products
  add column if not exists is_composable boolean not null default false;

-- Distinta base: righe (prodotto finito -> componente + quantita').
create table if not exists public.bom_components (
  id           uuid primary key default uuid_generate_v4(),
  company_id   uuid not null references public.companies(id) on delete cascade,
  product_id   uuid not null references public.products(id) on delete cascade,   -- finito
  component_id uuid not null references public.products(id) on delete restrict,  -- componente
  quantity     numeric(12,3) not null default 1,
  note         text,
  created_at   timestamptz not null default now(),
  unique (product_id, component_id),
  check (product_id <> component_id)
);
create index if not exists idx_bom_product on public.bom_components(product_id);

-- RLS company-isolation (stesso pattern dei prodotti).
alter table public.bom_components enable row level security;
alter table public.bom_components force row level security;

drop policy if exists bom_super_admin_all on public.bom_components;
create policy bom_super_admin_all on public.bom_components
  for all to authenticated
  using      (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');

drop policy if exists bom_company_isolation on public.bom_components;
create policy bom_company_isolation on public.bom_components
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
--  Permesso: eseguire la produzione (manufacturing).
-- ============================================================
insert into public.permissions (code, module, description) values
  ('products.produce', 'products', 'Produrre prodotti componibili (distinta base)')
on conflict (code) do update set description = excluded.description;

insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, 'products.produce',
  case when r.role in ('admin','employee') then true else false end
from (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;

-- ============================================================
--  RPC produzione: consuma i componenti e incrementa il finito.
--  Verifica la disponibilita' di ogni componente (errore se manca).
-- ============================================================
create or replace function public.produce_product(
  p_product_id uuid,
  p_qty numeric
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_company uuid;
  v_count   int;
  r         record;
begin
  if p_qty is null or p_qty <= 0 then
    raise exception 'Quantita'' da produrre non valida';
  end if;

  select company_id into v_company from public.products where id = p_product_id;
  if v_company is null then
    raise exception 'Prodotto inesistente';
  end if;
  if not (public.auth_role() = 'super_admin'
          or v_company = public.auth_company_id()) then
    raise exception 'Non autorizzato';
  end if;

  select count(*) into v_count
  from public.bom_components where product_id = p_product_id;
  if v_count = 0 then
    raise exception 'Il prodotto non ha una distinta base';
  end if;

  -- Verifica disponibilita' di tutti i componenti.
  for r in
    select b.component_id, b.quantity * p_qty as needed,
           coalesce(i.quantity, 0) as available,
           p.name as comp_name
    from public.bom_components b
    join public.products p on p.id = b.component_id
    left join public.inventory i on i.product_id = b.component_id
    where b.product_id = p_product_id
  loop
    if r.available < r.needed then
      raise exception 'Componente "%" insufficiente: servono %, disponibili %',
        r.comp_name, r.needed, r.available;
    end if;
  end loop;

  -- Scarica i componenti.
  update public.inventory i
     set quantity = i.quantity - (b.quantity * p_qty)::int,
         updated_at = now()
  from public.bom_components b
  where b.product_id = p_product_id
    and i.product_id = b.component_id;

  -- Incrementa (o crea) la giacenza del prodotto finito.
  insert into public.inventory (company_id, product_id, quantity, reorder_level)
  values (v_company, p_product_id, p_qty::int, 0)
  on conflict (product_id)
  do update set quantity = public.inventory.quantity + (p_qty)::int,
                updated_at = now();
end;
$$;

grant execute on function public.produce_product(uuid, numeric)
  to authenticated, service_role;
