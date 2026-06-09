-- ============================================================
--  SMARTERP · 39_step31_pacchetti_default.sql
--  Pacchetti di licenze (bundle) PREDEFINITI, creati al primo avvio.
--  Raggruppano le applicazioni che ha senso vendere insieme; vengono
--  proposti per primi quando si assegna una licenza a un'organizzazione.
--  (I bundle sono modelli di catalogo: NON sono assegnati ad alcuna org.)
--
--  Eseguire DOPO 38_step23b_vendite_template.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/39_step31_pacchetti_default.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
--
--  Idempotente: inserisce solo i bundle non ancora presenti (per nome).
-- ============================================================
\set ON_ERROR_STOP on

insert into public.app_bundles (name, description, app_codes, price, period)
select v.name, v.descr, v.codes, v.price, 'monthly'
from (values
  -- Fatturazione: la vendita/fatturazione richiede l'anagrafica clienti.
  ('Fatturazione',          'Vendite, Fatture e Clienti',
     array['invoices','customers'], 39.00),
  -- Vendite & CRM: pipeline commerciale + preventivi/fatture + clienti.
  ('Vendite & CRM',         'CRM, Vendite/Fatture e Clienti',
     array['crm','invoices','customers'], 59.00),
  -- Amministrazione: fatturazione + contabilità + documenti.
  ('Amministrazione',       'Fatture, Clienti, Contabilità e Documenti',
     array['invoices','customers','accounting','documents'], 79.00),
  -- Magazzino & Produzione: la produzione consuma il magazzino.
  ('Magazzino & Produzione','Magazzino/Prodotti e Produzione',
     array['products','production'], 59.00),
  -- Acquisti & Magazzino: gli acquisti riforniscono il magazzino.
  ('Acquisti & Magazzino',  'Acquisti (con Fornitori) e Magazzino',
     array['purchases','products'], 45.00),
  -- Operations: ciclo completo produzione/acquisti/manutenzione.
  ('Operations',            'Magazzino, Produzione, Acquisti e Manutenzione',
     array['products','production','purchases','maintenance'], 99.00),
  -- Documenti & Progetti: gestione documentale e project management.
  ('Documenti & Progetti',  'Documenti e Progetti',
     array['documents','projects'], 29.00),
  -- Collaborazione: strumenti trasversali.
  ('Collaborazione',        'Chat, Studio e Assistente IA',
     array['chat','studio','assistant'], 29.00),
  -- Suite completa: tutte le applicazioni ('suite' sblocca tutto).
  ('Suite completa',        'Tutte le applicazioni SmartERP',
     array['suite'], 149.00)
) as v(name, descr, codes, price)
where not exists (
  select 1 from public.app_bundles b where b.name = v.name
);
