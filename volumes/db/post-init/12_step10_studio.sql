-- ============================================================
--  SMARTERP · 12_step10_studio.sql
--  STEP 10 — App "Studio": modelli grafici salvabili per i documenti
--  (fatture/preventivi) + scelta del modello per documento.
--
--  Eseguire DOPO 11_step9_prodotti_media.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/12_step10_studio.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- Modelli documento: config grafica in jsonb, per azienda.
create table if not exists public.document_templates (
  id          uuid primary key default uuid_generate_v4(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  name        text not null,
  doc_type    text not null default 'both',   -- invoice | quote | both
  is_default  boolean not null default false,
  config      jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists idx_doc_templates_company on public.document_templates(company_id);

drop trigger if exists trg_doc_templates_updated on public.document_templates;
create trigger trg_doc_templates_updated before update on public.document_templates
  for each row execute function public.set_updated_at();

alter table public.document_templates enable row level security;
alter table public.document_templates force row level security;

drop policy if exists doc_templates_access on public.document_templates;
create policy doc_templates_access on public.document_templates
  for all to authenticated
  using (
        public.auth_role() = 'super_admin'
     or (public.auth_role() in ('admin','employee')
         and company_id = public.auth_company_id())
  )
  with check (
        public.auth_role() = 'super_admin'
     or (public.auth_role() in ('admin','employee')
         and company_id = public.auth_company_id())
  );

-- Modello scelto per la singola fattura (null = standard).
alter table public.invoices
  add column if not exists template_id uuid
  references public.document_templates(id) on delete set null;

-- Permessi modulo Studio.
insert into public.permissions (code, module, description, kind) values
  ('studio.view',   'studio', 'Vedere i modelli documento (Studio)', 'generic'),
  ('studio.manage', 'studio', 'Creare/modificare i modelli documento', 'generic')
on conflict (code) do update
  set description = excluded.description, kind = excluded.kind;

insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, p.code,
  case
    when r.role = 'admin' then true
    when r.role = 'employee' then p.code = 'studio.view'
    else false
  end
from (select code from public.permissions where module = 'studio') p
cross join (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;

-- Seed: un modello "Listino / Catalogo" per l'azienda demo.
insert into public.document_templates (company_id, name, doc_type, is_default, config)
select '00000000-0000-0000-0000-000000000001', 'Listino / Catalogo', 'both', true,
  jsonb_build_object(
    'header_text', 'Catalogo prodotti e offerta commerciale',
    'footer_text', 'Grazie per averci scelto. Pagamento a 30 giorni data fattura.',
    'show_logo', true,
    'line_style', 'catalog',
    'show_vat_summary', true,
    'primary_hex', null
  )
where not exists (
  select 1 from public.document_templates
  where company_id = '00000000-0000-0000-0000-000000000001'
    and name = 'Listino / Catalogo'
);
