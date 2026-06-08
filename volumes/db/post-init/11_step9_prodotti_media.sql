-- ============================================================
--  SMARTERP · 11_step9_prodotti_media.sql
--  STEP 9 — Immagine prodotto + visibilita' nei documenti (catalogo).
--
--  Eseguire DOPO 10_step8_chat.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/11_step9_prodotti_media.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- URL immagine del prodotto e flag "mostra immagine+descrizione nei
-- documenti" (fatture/preventivi in stile catalogo). La descrizione usa
-- la colonna products.description gia' esistente.
alter table public.products add column if not exists image_url text;
alter table public.products add column if not exists show_in_documents boolean not null default false;

-- Dati demo: arricchiamo la "Sedia in legno" con descrizione, immagine e flag.
update public.products set
  description = coalesce(description,
    'Sedia in legno massello di faggio, finitura naturale. Robusta e impilabile, ideale per sale riunioni e refettori.'),
  show_in_documents = true
where sku = 'SEDIA';
