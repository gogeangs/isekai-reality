import 'package:flutter/material.dart';

import '../../data/storage/record_store.dart';

/// 정령 표정 (11-10): 걱정(HP 낮음·쓰러짐), 축하(레벨업·정화), 졸림(여관 휴식)
enum SpiritMood { normal, worried, cheer, sleepy }

/// 정령 종류·표정별 그림
String spiritMoodAsset(SpiritKind kind, SpiritMood mood) =>
    mood == SpiritMood.normal
        ? spiritAsset(kind)
        : 'assets/images/spirit_${kind.name}_${mood.name}.webp';

/// 정령 종류별 그림 (기본 표정)
String spiritAsset(SpiritKind kind) => switch (kind) {
      SpiritKind.fire => 'assets/images/bulssi.webp',
      SpiritKind.water => 'assets/images/spirit_water.webp',
      SpiritKind.plant => 'assets/images/spirit_plant.webp',
    };

/// 정령 종류별 물약 그림 (잡화상 '정령 물약')
String spiritPotionAsset(SpiritKind kind) =>
    'assets/images/potion_spirit_${kind.name}.webp';

/// 정령의 속성 색 (빛, 일격 효과)
Color spiritColor(SpiritKind kind) => switch (kind) {
      SpiritKind.fire => const Color(0xFFF5C451),
      SpiritKind.water => const Color(0xFF7FD0FF),
      SpiritKind.plant => const Color(0xFF8FE08A),
    };

/// 정령 그림 한 장
class SpiritArt extends StatelessWidget {
  const SpiritArt({
    super.key,
    required this.kind,
    this.size = 64,
    this.name,
    this.mood = SpiritMood.normal,
  });

  final SpiritKind kind;
  final double size;
  final String? name;
  final SpiritMood mood;

  @override
  Widget build(BuildContext context) {
    if (mood != SpiritMood.normal) {
      // 표정 그림이 없으면 기본 그림
      return Image.asset(
        spiritMoodAsset(kind, mood),
        width: size,
        height: size * 1.1,
        fit: BoxFit.contain,
        semanticLabel: '정령 ${name ?? kind.defaultName}',
        errorBuilder: (_, __, ___) =>
            SpiritArt(kind: kind, size: size, name: name),
      );
    }
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
