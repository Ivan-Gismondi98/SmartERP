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

  static const customersView = 'customers.view';
  static const customersCreate = 'customers.create';
  static const customersEdit = 'customers.edit';
  static const customersDelete = 'customers.delete';

  static const productsView = 'products.view';
  static const productsCreate = 'products.create';
  static const productsEdit = 'products.edit';
  static const productsDelete = 'products.delete';

  static const settingsPermissionsManage = 'settings.permissions.manage';
}
