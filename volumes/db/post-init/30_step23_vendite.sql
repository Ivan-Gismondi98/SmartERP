-- ============================================================
--  SMARTERP · 30_step23_vendite.sql
--  Modulo VENDITE: documenti di vendita pre-fattura (preventivi e
--  ordini/conferme d'ordine). Stessa struttura fiscale delle fatture
--  (righe con aliquota IVA + Natura, calcolo per aliquota), ma documenti
--  NON fiscali: niente SdI, niente bollo obbligatorio. Un preventivo
--  accettato si converte in fattura nel modulo Fatture.
--
--  Norme IT 2026: il preventivo/ordine non è documento fiscale; la
--  numerazione progressiva qui è gestionale (per tipo+anno) e diventa
--  rilevante solo alla conversione in fattura.
--
--  Eseguire DOPO 29_step22_richieste_account.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/30_step23_vendite.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- ============================================================
--  SEZIONE A — TABELLE
-- ============================================================
create table if not exists public.sales_documents (
  id                    uuid primary key default uuid_generate_v4(),
  company_id            uuid not null references public.companies(id) on delete cascade,
  customer_id           uuid references public.customers(id) on delete set null,
  doc_kind              text not null default 'quote',   -- 'quote' (preventivo) | 'order' (ordine)
  doc_number            text,                             -- assegnato alla conferma (seq/anno)
  status                text not null default 'draft',    -- draft|sent|accepted|rejected|converted
  issue_date            date not null default current_date,
  valid_until           date,                             -- validità offerta (preventivi)
  subtotal              numeric(12,2) not null default 0,
  tax_amount            numeric(12,2) not null default 0,
  total                 numeric(12,2) not null default 0,
  stamp_duty            numeric(12,2) not null default 0,
  rounding              numeric(12,2) not null default 0,
  payment_method        text,
  payment_terms         text,
  payment_terms_days    int,
  notes                 text,
  numbering_year        int,
  numbering_seq         int,
  converted_invoice_id  uuid references public.invoices(id) on delete set null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index if not exists idx_sales_documents_company on public.sales_documents(company_id);
create index if not exists idx_sales_documents_customer on public.sales_documents(customer_id);

drop trigger if exists trg_sales_documents_updated on public.sales_documents;
create trigger trg_sales_documents_updated before update on public.sales_documents
  for each row execute function public.set_updated_at();

create table if not exists public.sales_document_items (
  id               uuid primary key default uuid_generate_v4(),
  document_id      uuid not null references public.sales_documents(id) on delete cascade,
  position         int not null default 0,
  product_id       uuid references public.products(id) on delete set null,
  description      text not null default '',
  quantity         numeric(12,3) not null default 1,
  unit_price       numeric(12,2) not null default 0,
  vat_rate         numeric(5,2) not null default 22,
  vat_nature       text,                          -- N1..N7 (quando aliquota = 0)
  discount_percent numeric(5,2) not null default 0,
  line_total       numeric(12,2) not null default 0
);
create index if not exists idx_sales_items_document on public.sales_document_items(document_id);

-- ============================================================
--  SEZIONE B — NUMERAZIONE PROGRESSIVA (per azienda, tipo doc, anno)
--  Gestionale: serie separate per preventivi e ordini. Assegnata alla
--  "conferma" del documento (status draft -> sent).
-- ============================================================
create or replace function public.assign_sales_number(
  p_document_id uuid
) returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_company uuid;
  v_kind    text;
  v_year    int;
  v_seq     int;
  v_number  text;
begin
  select company_id, doc_kind,
         coalesce(numbering_year, extract(year from issue_date)::int)
    into v_company, v_kind, v_year
  from public.sales_documents
  where id = p_document_id
  for update;

  if v_company is null then
    raise exception 'Documento di vendita % inesistente', p_document_id;
  end if;

  -- Serializza l'assegnazione per (azienda, tipo, anno).
  perform pg_advisory_xact_lock(
    hashtextextended(v_company::text || ':' || v_kind || ':' || v_year::text, 43));

  select coalesce(max(numbering_seq), 0) + 1
    into v_seq
  from public.sales_documents
  where company_id = v_company
    and doc_kind = v_kind
    and numbering_year = v_year
    and numbering_seq is not null;

  v_number := v_seq::text || '/' || v_year::text;

  update public.sales_documents
     set numbering_year = v_year,
         numbering_seq  = v_seq,
         doc_number     = v_number,
         status         = case when status = 'draft' then 'sent' else status end
   where id = p_document_id;

  return v_number;
end;
$$;

grant execute on function public.assign_sales_number(uuid)
  to authenticated, service_role;

-- ============================================================
--  SEZIONE C — RLS company-isolation (stesso pattern di invoices)
-- ============================================================
alter table public.sales_documents enable row level security;
alter table public.sales_documents force row level security;

drop policy if exists sales_documents_super on public.sales_documents;
create policy sales_documents_super on public.sales_documents
  for all to authenticated
  using      (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');

drop policy if exists sales_documents_company on public.sales_documents;
create policy sales_documents_company on public.sales_documents
  for all to authenticated
  using (
        public.auth_role() in ('admin','employee')
    and company_id = public.auth_company_id()
  )
  with check (
        public.auth_role() in ('admin','employee')
    and company_id = public.auth_company_id()
  );

alter table public.sales_document_items enable row level security;
alter table public.sales_document_items force row level security;

drop policy if exists sales_items_super on public.sales_document_items;
create policy sales_items_super on public.sales_document_items
  for all to authenticated
  using      (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');

drop policy if exists sales_items_company on public.sales_document_items;
create policy sales_items_company on public.sales_document_items
  for all to authenticated
  using (
    exists (
      select 1 from public.sales_documents d
      where d.id = sales_document_items.document_id
        and public.auth_role() in ('admin','employee')
        and d.company_id = public.auth_company_id()
    )
  )
  with check (
    exists (
      select 1 from public.sales_documents d
      where d.id = sales_document_items.document_id
        and public.auth_role() in ('admin','employee')
        and d.company_id = public.auth_company_id()
    )
  );

-- ============================================================
--  SEZIONE D — PERMESSI
-- ============================================================
insert into public.permissions (code, module, description, kind, admin_manageable) values
  ('sales.view',    'sales', 'Visualizzare preventivi e ordini', 'generic', true),
  ('sales.create',  'sales', 'Creare preventivi e ordini', 'generic', true),
  ('sales.edit',    'sales', 'Modificare preventivi e ordini in bozza', 'generic', true),
  ('sales.delete',  'sales', 'Eliminare preventivi e ordini in bozza', 'generic', true),
  ('sales.issue',   'sales', 'Confermare (numerare) preventivi e ordini', 'generic', true),
  ('sales.convert', 'sales', 'Convertire un preventivo/ordine in fattura', 'generic', true)
on conflict (code) do update
  set description = excluded.description, kind = excluded.kind, admin_manageable = excluded.admin_manageable;

insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, p.code,
  case
    when r.role = 'admin' then true
    when r.role = 'employee' then p.code <> 'sales.delete'
    else false
  end
from (select code from public.permissions where module = 'sales') p
cross join (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;
