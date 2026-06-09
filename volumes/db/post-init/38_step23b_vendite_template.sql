-- ============================================================
--  SMARTERP · 38_step23b_vendite_template.sql
--  Estensione modulo VENDITE: collega un modello documento (Studio) al
--  preventivo/ordine, per l'export PDF/Word con la grafica scelta.
--
--  Eseguire DOPO 37_step30_progetti.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/38_step23b_vendite_template.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

alter table public.sales_documents
  add column if not exists template_id uuid
  references public.document_templates(id) on delete set null;
