// ============================================================
//  SMARTERP · permission_codes.dart
//  Costanti dei codici permesso (devono combaciare con la tabella
//  public.permissions del DB).
// ============================================================
class Perm {
  Perm._();

  static const invoicesView = 'invoices.view';
  static const invoicesCreate = 'invoices.create';
  static const invoicesEdit = 'invoices.edit';
  static const invoicesDelete = 'invoices.delete';
  static const invoicesIssue = 'invoices.issue';
  static const invoicesExport = 'invoices.export';
  static const invoicesPrint = 'invoices.print';
  static const invoicesSdiSend = 'invoices.sdi_send';

  static const customersView = 'customers.view';
  static const customersCreate = 'customers.create';
  static const customersEdit = 'customers.edit';
  static const customersDelete = 'customers.delete';

  static const productsView = 'products.view';
  static const productsCreate = 'products.create';
  static const productsEdit = 'products.edit';
  static const productsDelete = 'products.delete';

  static const suppliersView = 'suppliers.view';
  static const suppliersCreate = 'suppliers.create';
  static const suppliersEdit = 'suppliers.edit';
  static const suppliersDelete = 'suppliers.delete';

  static const salesView = 'sales.view';
  static const salesCreate = 'sales.create';
  static const salesEdit = 'sales.edit';
  static const salesDelete = 'sales.delete';
  static const salesIssue = 'sales.issue';
  static const salesConvert = 'sales.convert';

  static const crmView = 'crm.view';
  static const crmCreate = 'crm.create';
  static const crmEdit = 'crm.edit';
  static const crmDelete = 'crm.delete';

  static const chatView = 'chat.view';
  static const chatSend = 'chat.send';
  static const chatManage = 'chat.manage';
  static const chatVideo = 'chat.video';

  static const studioView = 'studio.view';
  static const studioManage = 'studio.manage';

  static const errorsView = 'errors.view';
  static const ticketsView = 'tickets.view';

  static const devDashboard = 'dev.dashboard';
  static const licensesManage = 'licenses.manage';
  static const usersManage = 'users.manage';
  static const companiesManage = 'companies.manage';
  static const orgUsersManage = 'org.users.manage';

  static const settingsPermissionsManage = 'settings.permissions.manage';
  static const settingsCompanyManage = 'settings.company.manage';
}
