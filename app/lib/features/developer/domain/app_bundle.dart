// ============================================================
//  SMARTERP · app_bundle.dart — pacchetto di licenze (aggregato di app).
// ============================================================
class AppBundle {
  const AppBundle({
    required this.id,
    required this.name,
    this.description,
    this.appCodes = const [],
    this.price = 0,
    this.period = 'monthly',
  });

  final String id;
  final String name;
  final String? description;
  final List<String> appCodes;
  final double price;
  final String period;

  factory AppBundle.fromJson(Map<String, dynamic> j) => AppBundle(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        appCodes: ((j['app_codes'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(),
        price: (j['price'] as num?)?.toDouble() ?? 0,
        period: (j['period'] as String?) ?? 'monthly',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description':
            (description == null || description!.trim().isEmpty) ? null : description!.trim(),
        'app_codes': appCodes,
        'price': price,
        'period': period,
      };
}
