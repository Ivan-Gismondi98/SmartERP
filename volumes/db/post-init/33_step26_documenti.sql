-- ============================================================
--  SMARTERP · 33_step26_documenti.sql
--  Modulo DOCUMENTI: gestione documenti interni dell'organizzazione,
--  archiviati su Supabase Storage (bucket 'documents'). Metadati in
--  public.documents con isolamento per azienda (RLS).
--
--  Applicativo licenziabile (app_code 'documents').
--
--  Eseguire DOPO 32_step25_contabilita.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/33_step26_documenti.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- ============================================================
--  TABELLA — documenti (metadati; il file sta su Storage)
-- ============================================================
create table if not exists public.documents (
  id          uuid primary key default uuid_generate_v4(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  title       text not null,
  category    text not null default 'Generale',
  description text,
  file_name   text not null,
  file_path   text not null,                  -- path su Storage (per delete)
  file_url    text not null,                  -- URL pubblico
  mime_type   text,
  size_bytes  bigint not null default 0,
  uploaded_by uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists idx_documents_company on public.documents(company_id);
create index if not exists idx_documents_category on public.documents(company_id, category);

drop trigger if exists trg_documents_updated on public.documents;
create trigger trg_documents_updated before update on public.documents
  for each row execute function public.set_updated_at();

-- ============================================================
--  RLS company-isolation
-- ============================================================
alter table public.documents enable row level security;
alter table public.documents force row level security;

drop policy if exists documents_super on public.documents;
create policy documents_super on public.documents
  for all to authenticated
  using      (public.auth_role() = 'super_admin')
  with check (public.auth_role() = 'super_admin');

drop policy if exists documents_company on public.documents;
create policy documents_company on public.documents
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
--  PERMESSI
-- ============================================================
insert into public.permissions (code, module, description, kind, admin_manageable) values
  ('documents.view',   'documents', 'Visualizzare i documenti', 'generic', true),
  ('documents.create', 'documents', 'Caricare documenti', 'generic', true),
  ('documents.edit',   'documents', 'Modificare i dati dei documenti', 'generic', true),
  ('documents.delete', 'documents', 'Eliminare documenti', 'generic', true)
on conflict (code) do update
  set description = excluded.description, kind = excluded.kind, admin_manageable = excluded.admin_manageable;

insert into public.role_permissions (company_id, role, permission_code, allowed)
select null, r.role, p.code,
  case
    when r.role = 'admin' then true
    when r.role = 'employee' then p.code <> 'documents.delete'
    else false
  end
from (select code from public.permissions where module = 'documents') p
cross join (values ('admin'::public.user_role), ('employee'::public.user_role), ('customer'::public.user_role)) as r(role)
on conflict do nothing;

-- ============================================================
--  STORAGE — bucket 'documents' (riusa i grant globali dello step 15b)
-- ============================================================
insert into storage.buckets (id, name, public)
values ('documents', 'documents', true)
on conflict (id) do update set public = true;

drop policy if exists documents_objects on storage.objects;
create policy documents_objects on storage.objects
  for all to authenticated
  using (bucket_id = 'documents')
  with check (bucket_id = 'documents');

do $$
begin
  if to_regclass('storage.prefixes') is not null then
    execute 'alter table storage.prefixes enable row level security';
    execute 'drop policy if exists documents_prefixes on storage.prefixes';
    execute $p$create policy documents_prefixes on storage.prefixes
      for all to authenticated
      using (bucket_id = 'documents')
      with check (bucket_id = 'documents')$p$;
  end if;
end $$;

-- ============================================================
--  Licenza demo (azienda demo).
-- ============================================================
insert into public.licenses (company_id, name, status, price, period, start_date, app_code, app_codes)
select '00000000-0000-0000-0000-000000000001', 'Documenti - mensile', 'active', 9.00, 'monthly',
       current_date, 'documents', array['documents']
where not exists (
  select 1 from public.licenses
  where company_id = '00000000-0000-0000-0000-000000000001'
    and app_codes @> array['documents']
);
