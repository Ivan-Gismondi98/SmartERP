// ============================================================
//  SMARTERP · app_info.dart — informazioni applicazione (versione, autore).
//  Versione: aaaa.mm.gg.<ramo>  (1 = rilascio da master).
// ============================================================
class AppInfo {
  AppInfo._();

  static const String name = 'SmartERP';
  static const String version = '2026.06.09.1';
  static const String author = 'Ivan Gismondi';
  static const String team = 'CodigoTeam';
  static const String githubUrl = 'https://github.com/Codigo-Team';

  /// "© 2026 Ivan Gismondi · CodigoTeam"
  static String get copyright => '© 2026 $author · $team';
}
