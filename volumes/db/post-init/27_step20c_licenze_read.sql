-- ============================================================
--  SMARTERP · 27_step20c_licenze_read.sql
--  Tutti i membri dell'organizzazione (anche dipendenti/utenti) devono
--  poter LEGGERE le proprie licenze, così l'app mostra le app attive.
--  (Prima solo admin/super: i dipendenti non vedevano alcun modulo.)
--
--  Eseguire DOPO 26_step20b_impersonate_token.sql + NOTIFY reload.
-- ============================================================
\set ON_ERROR_STOP on

drop policy if exists licenses_admin_read on public.licenses;
drop policy if exists licenses_company_read on public.licenses;
create policy licenses_company_read on public.licenses
  for select to authenticated
  using (
        public.auth_role() = 'super_admin'
     or company_id = public.auth_company_id()
  );
