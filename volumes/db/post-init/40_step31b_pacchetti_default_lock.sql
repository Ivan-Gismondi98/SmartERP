-- ============================================================
--  SMARTERP · 40_step31b_pacchetti_default_lock.sql
--  I pacchetti di licenze PREDEFINITI (creati dal sistema) non sono
--  eliminabili: flag is_default + trigger che blocca la cancellazione.
--
--  Eseguire DOPO 39_step31_pacchetti_default.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/40_step31b_pacchetti_default_lock.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

alter table public.app_bundles
  add column if not exists is_default boolean not null default false;

-- Marca come predefiniti tutti i pacchetti seedati dal sistema.
update public.app_bundles set is_default = true
where name in (
  'Pacchetto Base', 'Pacchetto Pro',
  'Fatturazione', 'Vendite & CRM', 'Amministrazione',
  'Magazzino & Produzione', 'Acquisti & Magazzino', 'Operations',
  'Documenti & Progetti', 'Collaborazione', 'Suite completa'
);

-- Trigger: vieta l'eliminazione dei pacchetti predefiniti.
create or replace function public.prevent_default_bundle_delete()
returns trigger language plpgsql as $$
begin
  if old.is_default then
    raise exception 'Pacchetto predefinito: non eliminabile';
  end if;
  return old;
end;
$$;

drop trigger if exists trg_app_bundles_no_delete_default on public.app_bundles;
create trigger trg_app_bundles_no_delete_default
  before delete on public.app_bundles
  for each row execute function public.prevent_default_bundle_delete();
