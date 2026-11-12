import 'package:flutter/material.dart';

import '../../core/rules/rules.dart';

/// 스탯 아이콘 (11-11 #95): 둥근 금테 메달 그림(stat_<스탯>.png)이 들어오면 그것을,
/// 오기 전에는 지금 아이콘을 쓴다. 스탯이 나오는 모든 곳에서 함께 쓴다.
class StatIcon extends StatelessWidget {
  const StatIcon(this.kind, {super.key, this.size = 22, this.color});

  final StatKind kind;
  final double size;

  /// 그림이 없을 때 아이콘 색
  final Color? color;

  static IconData fallback(StatKind k) => switch (k) {
        StatKind.strength => Icons.fitness_center_rounded,
        StatKind.agility => Icons.directions_run_rounded,
        StatKind.intellect => Icons.auto_fix_high_rounded,
        StatKind.vitality => Icons.favorite_rounded,
        StatKind.luck => Icons.auto_awesome_rounded,
      };

  static String asset(StatKind k) => 'assets/images/stat_${k.name}.webp';

  @override
  Widget build(BuildContext context) => Image.asset(
        asset(kind),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(fallback(kind),
            size: size, color: color ?? const Color(0xFFF5D06A)),
      );
}
