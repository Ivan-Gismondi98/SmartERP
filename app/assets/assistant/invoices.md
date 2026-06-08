# Fatture

## Creare una nuova fattura
<!-- perm: invoices.create; roles: admin,employee; keywords: creare fattura, nuova fattura, fatturare, prima fattura, emettere documento, bozza -->
Per creare una fattura:
1. Apri il modulo **Fatture** dalla dashboard.
2. Tocca **＋ Nuova fattura** in basso a destra.
3. Seleziona il **Cliente** dal menu (se non c'è, crealo prima nel modulo Clienti).
4. Imposta **Data documento** e, se vuoi, i **Giorni alla scadenza** (calcola la scadenza).
5. Aggiungi le **righe**: scegli un prodotto (compila descrizione/prezzo/IVA) oppure scrivi una riga libera; imposta Qtà, Prezzo, Sconto % e Aliquota IVA.
6. Per le righe ad aliquota 0% scegli la **Natura** (N1–N7).
7. Controlla il riepilogo IVA e il totale in fondo, poi **Salva bozza**.

## Emettere una fattura (numero progressivo)
<!-- perm: invoices.issue; roles: admin,employee; keywords: emettere, emissione, numero, protocollo, confermare fattura -->
Apri una fattura in **bozza** e tocca **Emetti**. Viene assegnato il numero
progressivo definitivo (es. `1/2026`) e la fattura non è più modificabile.
All'emissione, se le righe sono collegate a prodotti, il **magazzino viene
scaricato** automaticamente.

## Stampare il PDF della fattura
<!-- perm: invoices.print; keywords: stampa, pdf, scaricare, stampare fattura -->
Apri una fattura **emessa** e tocca **Stampa PDF**: vedi l'anteprima e puoi
stampare o scaricare. Il PDF usa il modello grafico scelto (app Studio) e il
branding aziendale (colori/logo).

## Esportare l'XML per lo SdI (FatturaPA)
<!-- perm: invoices.export; keywords: xml, sdi, fatturapa, fattura elettronica, esportare -->
Apri una fattura emessa e tocca **Esporta XML**: ottieni il file conforme al
tracciato SdI, da copiare o scaricare. La firma e l'invio reale allo SdI sono
passaggi esterni (accreditamento).

## Generare il documento Word
<!-- perm: invoices.print; keywords: word, docx, documento word -->
Dal dettaglio di una fattura emessa tocca **Word** per scaricare il .docx.

## Creare una nota di credito
<!-- perm: invoices.create; roles: admin,employee; keywords: nota di credito, storno, rimborso, td04 -->
Apri la fattura emessa e tocca **Nota di credito**: crea una bozza collegata
(TD04) che potrai modificare ed emettere. Reintegra il magazzino all'emissione.

## Interessi di mora sulle fatture scadute
<!-- perm: invoices.edit; roles: admin,employee; keywords: mora, interessi, scaduta, ritardo, sollecito -->
Nel form fattura attiva **Interessi di mora se scaduta** e imposta il tasso
annuo. Per le fatture scadute, dettaglio e PDF mostrano gli interessi maturati
sul ritardo.
