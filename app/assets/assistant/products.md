# Magazzino / Prodotti

## Creare un prodotto e gestire la giacenza
<!-- perm: products.create; roles: admin,employee; keywords: prodotto, nuovo prodotto, magazzino, giacenza, scorta, articolo -->
1. Apri **Magazzino** e tocca **＋ Nuovo prodotto**.
2. Inserisci nome, SKU, prezzo, aliquota IVA, unità.
3. Imposta **Quantità in giacenza** e **Scorta minima** (sotto questa soglia il
   prodotto è evidenziato come "sotto scorta").
4. Facoltativo: URL **immagine** e descrizione, e il toggle "Mostra nei
   documenti" per il layout catalogo in fattura.

## Distinta base e produzione (prodotti componibili)
<!-- perm: products.produce; roles: admin,employee; keywords: distinta base, diba, bom, produrre, componibile, assemblare, sedia, materie prime -->
Attiva **Prodotto componibile** e definisci la **distinta base** (componenti +
quantità). Poi tocca **Produci…** e indica la quantità: i componenti vengono
scaricati dal magazzino e la giacenza del prodotto finito aumenta. Se un
componente è insufficiente, la produzione viene bloccata con un messaggio.

## Scarico automatico del magazzino
<!-- keywords: scarico, vendita, scaricare magazzino, scorte -->
Quando emetti una fattura con righe collegate a prodotti, la giacenza si
scarica automaticamente; una nota di credito la reintegra.
