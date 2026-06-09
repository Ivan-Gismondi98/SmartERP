-- ============================================================
--  SMARTERP · 45_step33_demo_mode.sql
--  AMBIENTE DI PROVA per organizzazione, gestito dallo sviluppatore.
--
--   1) Pulizia: elimina TUTTI i dati applicativi esistenti (l'organizzazione
--      e i suoi utenti restano). Si parte da un ambiente di produzione pulito.
--   2) companies.demo_mode (bool): lo sviluppatore lo attiva/disattiva per
--      una specifica organizzazione.
--   3) is_demo su ogni tabella dati: ogni riga inserita MENTRE demo_mode è
--      attivo viene marcata is_demo = true (trigger). Quindi sia i dati di
--      prova seedati sia quelli aggiunti da admin/dipendenti durante il test
--      sono "demo".
--   4) RPC set_demo_mode(company, on):
--        - ON  → attiva demo_mode e seeda i dati di prova (appaiono);
--        - OFF → disattiva e CANCELLA definitivamente tutte le righe is_demo
--                (i dati di prova e quelli aggiunti durante il test spariscono).
--
--  Eseguire DOPO 44_step32b_unifica_pacchetti.sql:
--    docker exec -i smarterp-db psql -U postgres -d postgres \
--      < volumes/db/post-init/45_step33_demo_mode.sql
--    docker exec smarterp-db psql -U postgres -d postgres \
--      -c "NOTIFY pgrst, 'reload schema';"
-- ============================================================
\set ON_ERROR_STOP on

-- ============================================================
--  1) PULIZIA dati applicativi (reset produzione)
-- ============================================================
delete from public.production_orders;
delete from public.invoices;
delete from public.sales_documents;
delete from public.purchase_documents;
delete from public.accounting_entries;
delete from public.maintenance_requests;
delete from public.maintenance_equipment;
delete from public.projects;
delete from public.crm_opportunities;
delete from public.documents;
delete from public.bom_components;
delete from public.inventory;
delete from public.products;
delete from public.customers;
delete from public.suppliers;
delete from public.accounting_accounts;
delete from public.accounting_cost_centers;

-- ============================================================
--  2) Schema: demo_mode + is_demo
-- ============================================================
alter table public.companies add column if not exists demo_mode boolean not null default false;

do $$
declare t text;
begin
  foreach t in array array[
    'customers','suppliers','products','inventory','invoices','sales_documents',
    'crm_opportunities','accounting_accounts','accounting_cost_centers',
    'accounting_entries','documents','production_orders','purchase_documents',
    'maintenance_equipment','maintenance_requests','projects','bom_components'
  ] loop
    execute format('alter table public.%I add column if not exists is_demo boolean not null default false;', t);
    execute format('create index if not exists idx_%I_demo on public.%I(company_id) where is_demo;', t, t);
  end loop;
end $$;

-- ============================================================
--  3) Trigger: marca is_demo le righe inserite con demo_mode attivo
-- ============================================================
create or replace function public.smarterp_mark_demo()
returns trigger language plpgsql as $mark$
declare v_demo boolean;
begin
  if NEW.company_id is not null then
    select demo_mode into v_demo from public.companies where id = NEW.company_id;
    if coalesce(v_demo, false) then
      NEW.is_demo := true;
    end if;
  end if;
  return NEW;
end;
$mark$;

do $$
declare t text;
begin
  foreach t in array array[
    'customers','suppliers','products','inventory','invoices','sales_documents',
    'crm_opportunities','accounting_accounts','accounting_cost_centers',
    'accounting_entries','documents','production_orders','purchase_documents',
    'maintenance_equipment','maintenance_requests','projects','bom_components'
  ] loop
    execute format('drop trigger if exists trg_%I_mark_demo on public.%I;', t, t);
    execute format('create trigger trg_%I_mark_demo before insert on public.%I '
                   'for each row execute function public.smarterp_mark_demo();', t, t);
  end loop;
end $$;

-- ============================================================
--  4) RPC: set_demo_mode(company, on)  — solo super_admin
-- ============================================================
create or replace function public.set_demo_mode(p_company uuid, p_on boolean)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_cur boolean;
  v_c1 uuid; v_c2 uuid;
  v_sup uuid;
  v_p1 uuid; v_p2 uuid; v_p3 uuid;
  v_inv uuid; v_quote uuid; v_po uuid;
  v_acc_cred uuid; v_acc_ric uuid; v_acc_iva uuid; v_entry uuid;
  v_equip uuid; v_proj uuid;
begin
  if public.auth_role() <> 'super_admin' then
    raise exception 'Solo lo sviluppatore può gestire i dati di prova';
  end if;

  select demo_mode into v_cur from public.companies where id = p_company;
  if v_cur is null then
    raise exception 'Organizzazione inesistente';
  end if;
  if v_cur = p_on then
    return;  -- nessun cambiamento
  end if;

  update public.companies set demo_mode = p_on where id = p_company;

  if not p_on then
    -- OFF: elimina definitivamente tutte le righe di prova (figli in cascata).
    delete from public.production_orders     where company_id = p_company and is_demo;
    delete from public.invoices              where company_id = p_company and is_demo;
    delete from public.sales_documents       where company_id = p_company and is_demo;
    delete from public.purchase_documents    where company_id = p_company and is_demo;
    delete from public.accounting_entries    where company_id = p_company and is_demo;
    delete from public.maintenance_requests  where company_id = p_company and is_demo;
    delete from public.maintenance_equipment where company_id = p_company and is_demo;
    delete from public.projects              where company_id = p_company and is_demo;
    delete from public.crm_opportunities     where company_id = p_company and is_demo;
    delete from public.documents             where company_id = p_company and is_demo;
    delete from public.bom_components        where company_id = p_company and is_demo;
    delete from public.inventory             where company_id = p_company and is_demo;
    delete from public.products              where company_id = p_company and is_demo;
    delete from public.customers             where company_id = p_company and is_demo;
    delete from public.suppliers             where company_id = p_company and is_demo;
    delete from public.accounting_accounts   where company_id = p_company and is_demo;
    delete from public.accounting_cost_centers where company_id = p_company and is_demo;
    return;
  end if;

  -- ON: seed dati di prova (is_demo impostato dal trigger).
  -- Clienti
  insert into public.customers (company_id, is_company, name, vat_number, email, city)
  values (p_company, true, 'Cliente Prova Alfa S.r.l.', 'IT01234567890', 'alfa@example.com', 'Milano')
  returning id into v_c1;
  insert into public.customers (company_id, is_company, name, email, city)
  values (p_company, false, 'Mario Bianchi (prova)', 'mario.bianchi@example.com', 'Roma')
  returning id into v_c2;

  -- Fornitore
  insert into public.suppliers (company_id, name, vat_number, email, address)
  values (p_company, 'Fornitore Prova Beta', 'IT09876543210', 'beta@example.com', 'Via Demo 1, Torino')
  returning id into v_sup;

  -- Prodotti + giacenze (p3 componibile)
  insert into public.products (company_id, name, sku, unit_price, vat_rate, unit, is_composable)
  values (p_company, 'Vite M6 (prova)', 'DEMO-VITE', 0.20, 22, 'pz', false) returning id into v_p1;
  insert into public.products (company_id, name, sku, unit_price, vat_rate, unit, is_composable)
  values (p_company, 'Asse legno (prova)', 'DEMO-ASSE', 8.00, 22, 'pz', false) returning id into v_p2;
  insert into public.products (company_id, name, sku, unit_price, vat_rate, unit, is_composable)
  values (p_company, 'Sgabello (prova)', 'DEMO-SGAB', 35.00, 22, 'pz', true) returning id into v_p3;
  insert into public.inventory (company_id, product_id, quantity, reorder_level) values
    (p_company, v_p1, 500, 50), (p_company, v_p2, 80, 10), (p_company, v_p3, 5, 2);

  -- Distinta base dello sgabello + ordine di produzione
  insert into public.bom_components (company_id, product_id, component_id, quantity) values
    (p_company, v_p3, v_p1, 8), (p_company, v_p3, v_p2, 3);
  insert into public.production_orders (company_id, product_id, quantity, status, planned_date)
  values (p_company, v_p3, 10, 'draft', current_date + 7);

  -- Fattura (bozza) con una riga
  insert into public.invoices (company_id, customer_id, document_type, status, issue_date, subtotal, tax_amount, total)
  values (p_company, v_c1, 'TD01', 'draft', current_date, 200.00, 44.00, 244.00) returning id into v_inv;
  insert into public.invoice_items (invoice_id, position, product_id, description, quantity, unit_price, vat_rate, discount_percent, line_total)
  values (v_inv, 0, v_p2, 'Asse legno', 25, 8.00, 22, 0, 200.00);

  -- Preventivo (Vendite)
  insert into public.sales_documents (company_id, customer_id, doc_kind, status, issue_date, valid_until, subtotal, tax_amount, total)
  values (p_company, v_c2, 'quote', 'draft', current_date, current_date + 30, 35.00, 7.70, 42.70) returning id into v_quote;
  insert into public.sales_document_items (document_id, position, product_id, description, quantity, unit_price, vat_rate, discount_percent, line_total)
  values (v_quote, 0, v_p3, 'Sgabello su misura', 1, 35.00, 22, 0, 35.00);

  -- Ordine di acquisto
  insert into public.purchase_documents (company_id, supplier_id, doc_kind, status, issue_date, subtotal, tax_amount, total)
  values (p_company, v_sup, 'order', 'draft', current_date, 160.00, 35.20, 195.20) returning id into v_po;
  insert into public.purchase_document_items (document_id, position, product_id, description, quantity, unit_price, vat_rate, discount_percent, line_total)
  values (v_po, 0, v_p2, 'Asse legno (riordino)', 20, 8.00, 22, 0, 160.00);

  -- CRM
  insert into public.crm_opportunities (company_id, title, contact_company, stage, expected_value, probability, source)
  values (p_company, 'Fornitura sgabelli (prova)', 'Cliente Prova Alfa', 'qualified', 1500.00, 40, 'Demo');

  -- Contabilità: conti minimi + registrazione
  insert into public.accounting_accounts (company_id, code, name, nature) values
    (p_company, '15.01', 'Crediti verso clienti', 'attivo') returning id into v_acc_cred;
  insert into public.accounting_accounts (company_id, code, name, nature) values
    (p_company, '50.01', 'Ricavi vendite', 'ricavo') returning id into v_acc_ric;
  insert into public.accounting_accounts (company_id, code, name, nature) values
    (p_company, '20.10', 'IVA a debito', 'passivo') returning id into v_acc_iva;
  insert into public.accounting_cost_centers (company_id, code, name)
  values (p_company, 'CC-DEMO', 'Commerciale (prova)');
  insert into public.accounting_entries (company_id, entry_date, description, doc_ref)
  values (p_company, current_date, 'Vendita di prova con IVA 22%', 'Demo') returning id into v_entry;
  insert into public.accounting_lines (entry_id, position, account_id, description, debit, credit) values
    (v_entry, 0, v_acc_cred, 'Credito v/cliente', 244.00, 0),
    (v_entry, 1, v_acc_ric,  'Ricavo',               0, 200.00),
    (v_entry, 2, v_acc_iva,  'IVA a debito',          0,  44.00);

  -- Manutenzione
  insert into public.maintenance_equipment (company_id, name, code, category, location, status, next_service)
  values (p_company, 'Trapano a colonna (prova)', 'DEMO-MAC1', 'Macchinari', 'Officina', 'operational', current_date + 30)
  returning id into v_equip;
  insert into public.maintenance_requests (company_id, equipment_id, title, request_type, priority, status, scheduled_date)
  values (p_company, v_equip, 'Lubrificazione periodica (prova)', 'preventive', 'medium', 'open', current_date + 5);

  -- Progetti
  insert into public.projects (company_id, name, status, start_date, due_date, budget, manager)
  values (p_company, 'Progetto dimostrativo', 'active', current_date, current_date + 60, 5000.00, 'Demo')
  returning id into v_proj;
  insert into public.project_tasks (project_id, position, title, status, priority) values
    (v_proj, 0, 'Analisi requisiti', 'done', 'high'),
    (v_proj, 1, 'Sviluppo', 'in_progress', 'high'),
    (v_proj, 2, 'Collaudo', 'todo', 'medium');
end;
$fn$;

grant execute on function public.set_demo_mode(uuid, boolean) to authenticated, service_role;
