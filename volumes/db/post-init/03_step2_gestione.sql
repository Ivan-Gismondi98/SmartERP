-- ============================================================
--  SMARTERP · 03_step2_gestione.sql
--  STEP 2 — Gestione interna: note di credito (riferimento alla
--  fattura originale) e supporto al workflow.
--
--  Eseguire DOPO 02_step1_fatture_permessi.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/03_step2_gestione.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- Riferimento alla fattura originale (per le note di credito TD04).
alter table public.invoices
  add column if not exists reference_invoice_id uuid
  references public.invoices(id) on delete set null;

create index if not exists idx_invoices_reference
  on public.invoices(reference_invoice_id);
