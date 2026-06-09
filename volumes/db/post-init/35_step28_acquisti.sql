-- ============================================================
--  SMARTERP · 35_step28_acquisti.sql
--  Modulo ACQUISTI: documenti del ciclo passivo collegati ai Fornitori.
--   - offer    = offerta / richiesta d'offerta (RdO)
--   - order    = ordine di acquisto
--   - contract = contratto di fornitura
--  Struttura fiscale identica alle vendite (righe IVA + Natura), ma lato
--  fornitore. Numerazione gestionale per tipo+anno.
--
--  Applicativo licenziabile (app_code 'purchases').
--
--  Eseguire DOPO 34_step27_produzione.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/35_step28_acquisti.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- ============================================================
--  TABELLE
-- ============================================================
create table if not exists public.purchase_documents (
  id                 uuid primary key default uuid_generate_v4(),
  company_id         uuid not null references public.companies(id) on delete cascade,
  supplier_id        uuid references public.suppliers(id) on delete set null,
  doc_kind           text not null default 'order',  -- offer|order|contract
  doc_number         text,
  status             text not null default 'draft',  -- draft|sent|confirmed|received|cancelled
  issue_date         date not null default current_date,
  valid_until        date,                            -- validità offerta / scadenza contratto
  supplier_ref       text,                            -- rif. documento del fornitore
  subtotal           numeric(12,2) not null default 0,
  tax_amount         numeric(12,2) not null default 0,
  total              numeric(12,2) not null default 0,
  rounding           numeric(12,2) not null default 0,
  payment_terms      text,
  notes              text,
  numbering_year     int,
  numbering_seq      int,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index if not exists idx_purchase_docs_company on public.purchase_documents(company_id);
create index if not exists idx_purchase_docs_supplier on public.purchase_documents(supplier_id);

drop trigger if exists trg_purchase_docs_updated on public.purchase_documents;
create trigger trg_purchase_docs_updated before update on public.purchase_documents
  for each row execute function public.set_updated_at();

create table if not exists public.purchase_document_items (
  id               uuid primary key default uuid_generate_v4(),
  document_id      uuid not null references public.purchase_documents(id) on delete cascade,
  position         int not null default 0,
  product_id       uuid references public.products(id) on delete set null,
  description      text not null default '',
  quantity         numeric(12,3) not null default 1,
  unit_price       numeric(12,2) not null default 0,
  vat_rate         numeric(5,2) not null default 22,
  vat_nature       text,
  discount_percent numeric(5,2) not null default 0,
  line_total       numeric(12,2) not null default 0
);
create index if not exists idx_purchase_items_document on public.purchase_document_items(document_id);

-- ============================================================
--  NUMERAZIONE (per azienda, tipo, anno)
-- ============================================================
create or replace function public.assign_purchase_number(
  p_document_id uuid
) returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_company uuid;
  v_kind    text;
  v_year    int;
  v_seq     int;
  v_prefix  text;
  v_number  text;
begin
  select company_id, doc_kind, coalesce(numbering_year, extract(year from issue_date)::int)
    into v_company, v_kind, v_year
  from public.purchase_documents
  where id = p_document_id
  for update;

  if v_company is null then
    raise exception 'Documento di acquisto % inesistente', p_document_id;
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(v_company::text || ':purchase:' || v_kind || ':' || v_year::text, 46));

  select coalesce(max(numbering_seq), 0) + 1
    into v_seq
  from public.purchase_documents
  where company_id = v_company
    and doc_kind = v_kind
    and numbering_year = v_year
    and numbering_seq is not null;

  v_prefix := case v_kind when 'order' then 'OA ' when 'offer' then 'OFF ' when 'contract' then 'CON ' else '' end;
  v_number := v_prefix || v_seq::text || '/' || v_year::text;

  update public.purchase_documents
     set numbering_year = v_year,
         numbering_seq  = v_seq,
         doc_number     = v_number,
         status         = case when status = 'draft' then 'sent' else status end
   where id = p_document_id;

  return v_number;
end;
$$;

grant execute on function public.assign_purchase_number(uuid)
  to authenticated, service_role;

-- ============================================================
--  RLS company-isolation
-- ============================================================
alter table public.purchase_documents enable row level security;
alter table public.purchase_documents force row level security;

drop policy if exists purchase_docs_super on public.purchase_documents;
create policy purchase_docs_super on public.purchase_documents
  for all to authenticated
  using      (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');

drop policy if exists purchase_docs_company on public.purchase_documents;
create policy purchase_docs_company on public.purchase_documents
  for all to authenticated
  using (
        public.auth_role() in ('admin','employee')
    and company_id = public.auth_company_id()
  )
  with check (
        public.auth_role() in ('admin','employee')
    and company_id = public.auth_company_id()
  );

alter table public.purchase_document_items enable row level security;
alter table public.purchase_document_items force row level security;

drop policy if exists purchase_items_super on public.purchase_document_items;
create policy purchase_items_super on public.purchase_document_items
  for all to authenticated
  using      (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');

drop policy if exists purchase_items_company on public.purchase_document_items;
create policy purchase_items_company on public.purchase_document_items
  for all to authenticated
  using (
    exists (select 1 from public.purchase_documents d
            where d.id = purchase_document_items.document_id
              and public.auth_role() in ('admin','employee')
              and d.company_id = public.auth_company_id())
  )
  with check (
    exists (select 1 from public.purchase_documents d
            where d.id = purchase_document_items.document_id
              and public.auth_role() in ('admin','employee')
              and d.company_id = public.auth_company_id())
  );

-- ============================================================
--  PERMESSI
-- ============================================================
insert into public.permissions (code, module, description, kind, admin_manageable) values
  ('purchases.view',   'purchases', 'Visualizzare offerte, ordini e contratti d''acquisto', 'generic', true),
  ('purchases.create', 'purchases', 'Creare documenti di acquisto', 'generic', true),
  ('purchases.edit',   'purchases', 'Modificare documenti di acquisto', 'generic', true),
  ('purchases.delete', 'purchases', 'Eliminare documenti di acquisto', 'generic', true),
  ('purchases.issue',  'purchases', 'Confermare (numerare) i documenti di acquisto', 'generic', true)
on conflict (code) do update
  set description = excluded.description, kind = excluded.kind, admin_manageable = excluded.admin_manageable;

insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, p.code,
  case
    when r.role = 'admin' then true
    when r.role = 'employee' then p.code <> 'purchases.delete'
    else false
  end
from (select code from public.permissions where module = 'purchases') p
cross join (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;

-- ============================================================
--  Licenza demo + ordine d'acquisto di esempio (verso il fornitore demo).
-- ============================================================
insert into public.licenses (company_id, name, status, price, period, start_date, app_code, app_codes)
select '00000000-0000-0000-0000-000000000001', 'Acquisti - mensile', 'active', 19.00, 'monthly',
       current_date, 'purchases', array['purchases']
where not exists (
  select 1 from public.licenses
  where company_id = '00000000-0000-0000-0000-000000000001'
    and app_codes @> array['purchases']
);

do $$
declare
  v_company uuid := '00000000-0000-0000-0000-000000000001';
  v_supplier uuid;
  v_doc uuid;
begin
  select id into v_supplier from public.suppliers
    where company_id = v_company order by created_at limit 1;

  if v_supplier is not null
     and not exists (select 1 from public.purchase_documents where company_id = v_company) then
    insert into public.purchase_documents
      (company_id, supplier_id, doc_kind, status, issue_date, notes,
       subtotal, tax_amount, total)
    values (v_company, v_supplier, 'order', 'draft', current_date,
            'Riordino materie prime', 1000.00, 220.00, 1220.00)
    returning id into v_doc;

    insert into public.purchase_document_items
      (document_id, position, description, quantity, unit_price, vat_rate, line_total)
    values
      (v_doc, 0, 'Tavole di legno grezzo', 100, 8.00, 22, 800.00),
      (v_doc, 1, 'Viteria assortita', 1, 200.00, 22, 200.00);
  end if;
end $$;
