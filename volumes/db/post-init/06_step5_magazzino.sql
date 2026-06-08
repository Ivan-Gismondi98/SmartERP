-- ============================================================
--  SMARTERP · 06_step5_magazzino.sql
--  STEP 5 — Magazzino/Prodotti: RLS company-isolation su products e
--  inventory, permessi del modulo, e SCARICO AUTOMATICO delle giacenze
--  all'emissione della fattura (reintegro per le note di credito).
--
--  Eseguire DOPO 05_step4_pdf_mora.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/06_step5_magazzino.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- ============================================================
--  RLS company-isolation su products e inventory
-- ============================================================
alter table public.products enable row level security;
alter table public.products force row level security;

drop policy if exists products_super_admin_all on public.products;
create policy products_super_admin_all on public.products
  for all to authenticated
  using      (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');

drop policy if exists products_company_isolation on public.products;
create policy products_company_isolation on public.products
  for all to authenticated
  using (
        public.auth_role() in ('admin','employee')
    and company_id = public.auth_company_id()
  )
  with check (
        public.auth_role() in ('admin','employee')
    and company_id = public.auth_company_id()
  );

alter table public.inventory enable row level security;
alter table public.inventory force row level security;

drop policy if exists inventory_super_admin_all on public.inventory;
create policy inventory_super_admin_all on public.inventory
  for all to authenticated
  using      (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');

drop policy if exists inventory_company_isolation on public.inventory;
create policy inventory_company_isolation on public.inventory
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
--  Permessi modulo magazzino/prodotti
-- ============================================================
insert into public.permissions (code, module, description) values
  ('products.view',   'products', 'Visualizzare prodotti e giacenze'),
  ('products.create', 'products', 'Creare prodotti'),
  ('products.edit',   'products', 'Modificare prodotti e giacenze'),
  ('products.delete', 'products', 'Eliminare prodotti')
on conflict (code) do update set description = excluded.description;

insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, p.code,
  case
    when r.role = 'admin' then true
    when r.role = 'employee' then p.code <> 'products.delete'
    else false
  end
from (select code from public.permissions where module = 'products') p
cross join (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;

-- ============================================================
--  RPC emissione: guard anti-doppia emissione + scarico magazzino.
--  Le note di credito (TD04) REINTEGRANO le giacenze.
-- ============================================================
create or replace function public.assign_invoice_number(p_invoice_id uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  v_company  uuid;
  v_year     int;
  v_seq      int;
  v_existing int;
  v_existing_num text;
  v_doctype  text;
  v_number   text;
  v_sign     int;
begin
  select company_id, numbering_seq, invoice_number, document_type,
         coalesce(numbering_year, extract(year from issue_date)::int)
    into v_company, v_existing, v_existing_num, v_doctype, v_year
  from public.invoices where id = p_invoice_id for update;

  if v_company is null then
    raise exception 'Fattura % inesistente', p_invoice_id;
  end if;

  -- Gia' emessa: non rinumerare e non scaricare di nuovo.
  if v_existing is not null then
    return v_existing_num;
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(v_company::text || ':' || v_year::text, 42));

  select coalesce(max(numbering_seq), 0) + 1
    into v_seq
  from public.invoices
  where company_id = v_company
    and numbering_year = v_year
    and numbering_seq is not null;

  v_number := v_seq::text || '/' || v_year::text;

  update public.invoices
     set numbering_year = v_year,
         numbering_seq  = v_seq,
         invoice_number = v_number,
         status         = case when status = 'draft' then 'sent' else status end,
         issued_at      = coalesce(issued_at, now())
   where id = p_invoice_id;

  -- Movimento di magazzino: TD04 reintegra (+), gli altri scaricano (-).
  v_sign := case when v_doctype = 'TD04' then 1 else -1 end;
  update public.inventory inv
     set quantity   = inv.quantity + v_sign * agg.qty,
         updated_at = now()
  from (
    select product_id, sum(quantity)::int as qty
    from public.invoice_items
    where invoice_id = p_invoice_id and product_id is not null
    group by product_id
  ) agg
  where inv.product_id = agg.product_id
    and inv.company_id = v_company;

  return v_number;
end;
$$;

grant execute on function public.assign_invoice_number(uuid)
  to authenticated, service_role;
