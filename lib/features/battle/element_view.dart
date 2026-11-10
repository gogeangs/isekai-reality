import 'package:flutter/material.dart' hide Element;

import '../../core/rules/element_rules.dart';

/// 속성 색 (그림이 없을 때 동그라미 색)
Color elementColor(Element? e) => switch (e) {
      Element.fire => const Color(0xFFFF7A45),
      Element.water => const Color(0xFF4FA8FF),
      Element.ice => const Color(0xFFA8E6FF),
      Element.wind => const Color(0xFF6FE3B0),
      Element.thunder => const Color(0xFFFFD84A),
      Element.earth => const Color(0xFFB08850),
      Element.metal => const Color(0xFFB8C0CC),
      Element.poison => const Color(0xFF9BD45A),
      Element.light => const Color(0xFFFFF0A0),
      Element.dark => const Color(0xFF8A5CD6),
      null => const Color(0xFF9AA6D8),
    };

IconData elementIconData(Element? e) => switch (e) {
      Element.fire => Icons.local_fire_department_rounded,
      Element.water => Icons.water_drop_rounded,
      Element.ice => Icons.ac_unit_rounded,
      Element.wind => Icons.air_rounded,
      Element.thunder => Icons.bolt_rounded,
      Element.earth => Icons.landscape_rounded,
      Element.metal => Icons.hardware_rounded,
      Element.poison => Icons.science_rounded,
      Element.light => Icons.wb_sunny_rounded,
      Element.dark => Icons.dark_mode_rounded,
      null => Icons.radio_button_unchecked_rounded,
    };

/// 속성 아이콘 (11-11 #63). 숫자 없이 아이콘만 보여 준다.
/// 그림(assets/images/icon_el_<속성>.png, 무속성은 icon_el_none.png)이 없으면 색 동그라미.
/// [level] 은 장비 속성 강화 단계 (11-11 #74): 숫자 대신 빛이 진해진다.
class ElementIcon extends StatelessWidget {
  const ElementIcon(this.element, {super.key, this.size = 20, this.level = 0});

  final Element? element;
  final double size;
  final int level;

  @override
  Widget build(BuildContext context) {
    final e = element;
    final icon = _icon(e);
    if (e == null || level <= 0) return icon;
    return DecoratedBox(
      key: ValueKey('elGlow$level'),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: elementColor(e).withValues(alpha: 0.25 + 0.2 * level),
            blurRadius: 4.0 + 4 * level,
            spreadRadius: 0.5 * level,
          ),
        ],
      ),
      child: icon,
    );
  }

  Widget _icon(Element? e) {
    return Tooltip(
      message: e == null ? '무속성' : '${e.label} 속성',
      child: Image.asset(
        e?.asset ?? 'assets/images/icon_el_none.png',
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: elementColor(e).withValues(alpha: 0.25),
            border: Border.all(color: elementColor(e), width: 1.2),
          ),
          child: Icon(elementIconData(e),
              size: size * 0.66, color: elementColor(e)),
        ),
      ),
    );
  }
}
