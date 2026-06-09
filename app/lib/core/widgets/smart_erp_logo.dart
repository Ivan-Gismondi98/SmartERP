// ============================================================
//  SMARTERP · smart_erp_logo.dart — logo dell'applicazione.
//  Mark: tessera con gradiente e mini bar-chart (analytics/ERP).
//  Wordmark: "Smart" + "ERP" (accento sul colore primario).
// ============================================================
import 'package:flutter/material.dart';

class SmartErpLogo extends StatelessWidget {
  const SmartErpLogo({
    super.key,
    this.size = 40,
    this.showWordmark = true,
  });

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, cs.tertiary],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.35),
            blurRadius: size * 0.22,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.26),
        child: _Bars(color: cs.onPrimary),
      ),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.32),
        Text.rich(
          TextSpan(children: [
            TextSpan(
              text: 'Smart',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: size * 0.52,
                color: cs.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            TextSpan(
              text: 'ERP',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: size * 0.52,
                color: cs.primary,
                letterSpacing: -0.5,
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

/// Tre barre crescenti (mini bar-chart) allineate in basso.
class _Bars extends StatelessWidget {
  const _Bars({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget bar(double heightFactor) => Expanded(
          child: FractionallySizedBox(
            heightFactor: heightFactor,
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        bar(0.45),
        const SizedBox(width: 2),
        bar(0.72),
        const SizedBox(width: 2),
        bar(1.0),
      ],
    );
  }
}
