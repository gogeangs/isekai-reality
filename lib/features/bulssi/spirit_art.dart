import 'package:flutter/material.dart';

import '../../data/storage/record_store.dart';

/// 정령 종류별 그림
String spiritAsset(SpiritKind kind) => switch (kind) {
      SpiritKind.fire => 'assets/images/bulssi.png',
      SpiritKind.water => 'assets/images/spirit_water.png',
      SpiritKind.plant => 'assets/images/spirit_plant.png',
    };

/// 정령 종류별 물약 그림 (잡화상 '정령 물약')
String spiritPotionAsset(SpiritKind kind) =>
    'assets/images/potion_spirit_${kind.name}.png';

/// 정령의 속성 색 (빛, 일격 효과)
Color spiritColor(SpiritKind kind) => switch (kind) {
      SpiritKind.fire => const Color(0xFFF5C451),
      SpiritKind.water => const Color(0xFF7FD0FF),
      SpiritKind.plant => const Color(0xFF8FE08A),
    };

/// 정령 그림 한 장
class SpiritArt extends StatelessWidget {
  const SpiritArt({super.key, required this.kind, this.size = 64, this.name});

  final SpiritKind kind;
  final double size;
  final String? name;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      spiritAsset(kind),
      width: size,
      height: size * 1.1,
      fit: BoxFit.contain,
      semanticLabel: '정령 ${name ?? kind.defaultName}',
      errorBuilder: (_, __, ___) => Icon(
        switch (kind) {
          SpiritKind.fire => Icons.local_fire_department_rounded,
          SpiritKind.water => Icons.water_drop_rounded,
          SpiritKind.plant => Icons.eco_rounded,
        },
        color: spiritColor(kind),
        size: size * 0.78,
      ),
    );
  }
}
