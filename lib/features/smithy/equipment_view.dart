import 'package:flutter/material.dart';

import '../../core/models/armory.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../status/stat_icon.dart';
import 'slot_glyph.dart';

export 'slot_glyph.dart';

/// 장비 등급 색: 흰색 · 초록 · 파랑 · 보라 · 주황
Color equipGradeColor(EquipGrade g) => switch (g) {
      EquipGrade.white => AppColors.text,
      EquipGrade.green => const Color(0xFF7BE08A),
      EquipGrade.blue => const Color(0xFF6BB4FF),
      EquipGrade.purple => const Color(0xFFC79BFF),
      EquipGrade.orange => const Color(0xFFFFA244),
    };

IconData slotIcon(EquipSlot s) => switch (s) {
      EquipSlot.weapon => Icons.gavel_rounded,
      EquipSlot.head => Icons.face_retouching_natural_rounded,
      EquipSlot.body => Icons.checkroom_rounded,
      EquipSlot.hands => Icons.back_hand_rounded,
      EquipSlot.feet => Icons.hiking_rounded,
      EquipSlot.accessory => Icons.diamond_outlined,
    };

/// 입은 칸 테두리 색 (11-11 #98): 일반 흰색 · 희귀 파랑 · 영웅 보라 · 보스 장비 주황
Color wornBorderColor(EquipItem it) {
  if (EquipmentRules.isBossGear(it.base)) return const Color(0xFFFFA244);
  return switch (it.grade) {
    EquipGrade.white || EquipGrade.green => AppColors.text,
    EquipGrade.blue => const Color(0xFF6BB4FF),
    EquipGrade.purple || EquipGrade.orange => const Color(0xFFC79BFF),
  };
}

/// 강화 단계 → 테두리 빛 세기 (숫자는 숨긴다)
double enhanceGlow(int enhance) =>
    enhance <= 0 ? 0 : 3 + 13 * (enhance / EquipmentRules.maxEnhance).clamp(0.0, 1.0);

/// 장비 그림 (equip_*.png). 그림이 없으면 부위 아이콘. 등급 색 테두리.
class EquipIcon extends StatelessWidget {
  const EquipIcon(
      {super.key, required this.base, this.grade, this.size = 48});

  final EquipBase base;
  final EquipGrade? grade;
  final double size;

  @override
  Widget build(BuildContext context) {
    final info = EquipmentRules.info(base);
    final color =
        grade == null ? AppColors.gold : equipGradeColor(grade!);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D48),
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(
            color: color.withValues(alpha: grade == null ? 0.5 : 0.9),
            width: grade == null || grade == EquipGrade.white ? 1 : 2),
        boxShadow: grade != null && grade!.index >= EquipGrade.blue.index
            ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)]
            : null,
      ),
      child: Image.asset('assets/images/${info.asset}.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              Center(
                child: SlotGlyph(info.slot,
                    // 보스 장비는 세트 빛깔로 (11-11 #82, 그림이 오기 전)
                    color: switch (BossGearRules.setOf(base)) {
                      final set? => Color(BossGearRules.info(set).aura),
                      null => color,
                    },
                    size: size * 0.55),
              )),
    );
  }
}

/// 장비 이름 (등급 색)
class EquipName extends StatelessWidget {
  const EquipName(this.item, {super.key, this.size = 15});

  final EquipItem item;
  final double size;

  @override
  Widget build(BuildContext context) => Text(item.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
          color: equipGradeColor(item.grade),
          fontSize: size,
          fontWeight: FontWeight.w800));
}

/// 내구도 막대
class DurabilityBar extends StatelessWidget {
  const DurabilityBar({super.key, required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final r = value / EquipmentRules.maxDurability;
    final color = value <= 0
        ? const Color(0xFFE57373)
        : r < 0.3
            ? const Color(0xFFF0B04B)
            : const Color(0xFF7BE08A);
    return Row(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: r.clamp(0, 1).toDouble(),
            minHeight: 5,
            color: color,
            backgroundColor: const Color(0x33FFFFFF),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text(value <= 0 ? '내구도 0 · 능력 절반' : '내구도 $value',
          style: TextStyle(color: color, fontSize: 11)),
    ]);
  }
}

/// 장비 6칸 (가방·프로필). [onTap] 이 있으면 칸을 눌러 벗는다.
class EquipGrid extends StatelessWidget {
  const EquipGrid({super.key, required this.armory, this.onTap});

  final Armory armory;
  final void Function(EquipSlot slot, EquipItem? item)? onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.95,
      children: [
        for (final slot in EquipSlot.values)
          _SlotTile(
            slot: slot,
            item: armory.wornIn(slot),
            onTap: onTap == null ? null : () => onTap!(slot, armory.wornIn(slot)),
          ),
      ],
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot, this.item, this.onTap});

  final EquipSlot slot;
  final EquipItem? item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final it = item;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0x66101333),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: it == null
                  ? AppColors.gold.withValues(alpha: 0.3)
                  : wornBorderColor(it).withValues(alpha: 0.9),
              width: it == null ? 1 : 1.6),
          boxShadow: it != null && it.enhance > 0
              ? [
                  BoxShadow(
                      color: wornBorderColor(it).withValues(alpha: 0.45),
                      blurRadius: enhanceGlow(it.enhance)),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (it == null)
              SlotGlyph(slot, color: AppColors.textMuted, size: 26)
            else
              EquipIcon(base: it.base, grade: it.grade, size: 40),
            const SizedBox(height: 3),
            Text(EquipmentRules.slotLabel(slot),
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            Text(it == null ? '비어 있음' : it.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: it == null
                        ? AppColors.textMuted
                        : equipGradeColor(it.grade),
                    fontSize: 10.5)),
          ],
        ),
      ),
    );
  }
}

/// 입은 장비의 힘 한 줄
String gearSummary(GearBonus g) {
  String pct(double r) => (r * 100).toStringAsFixed(r * 100 % 1 == 0 ? 0 : 1);
  final parts = [
    if (g.attack > 0) '공격 +${pct(g.attack)}%',
    if (g.reduce > 0) '받는 피해 -${pct(g.reduce)}%',
    if (g.maxHp > 0) '최대 HP +${pct(g.maxHp)}%',
    if (g.skillFaster > 0) '일격 충전 빨리',
    for (final k in StatKind.values)
      if (g.stats.of(k) > 0) '${k.label} +${g.stats.of(k)}',
  ];
  return parts.isEmpty ? '아직 입은 장비가 없어요' : parts.join(' · ');
}

/// 장비 능력 (11-11 묶음 13 A4): 공격·방어 같은 능력은 글로, 스탯은 [메달] +N 으로.
/// [compare] 가 있으면 지금 입은 것과 비교해 오르면 초록 ↑, 내리면 빨강 ↓.
class ItemStats extends StatelessWidget {
  const ItemStats(this.item, {super.key, this.compare, this.fontSize = 11.5});

  final EquipItem item;

  /// 지금 그 부위에 입은 장비 (비교용)
  final EquipItem? compare;
  final double fontSize;

  static const _up = Color(0xFF7BE08A);
  static const _down = Color(0xFFE57373);

  @override
  Widget build(BuildContext context) {
    final effect = EquipmentRules.itemEffectLabel(item);
    final mine = EquipmentRules.itemStats(item);
    final other = compare == null || compare!.uid == item.uid
        ? null
        : EquipmentRules.itemStats(compare!);
    final kinds = [
      for (final k in StatKind.values)
        if ((mine[k] ?? 0) > 0 || (other?[k] ?? 0) > 0) k,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (effect.isNotEmpty)
          Text(effect,
              style: TextStyle(color: AppColors.textMuted, fontSize: fontSize)),
        if (kinds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(spacing: 8, runSpacing: 2, children: [
              for (final k in kinds)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  StatIcon(k, size: fontSize + 8, color: AppColors.goldBright),
                  const SizedBox(width: 2),
                  Text('+${mine[k] ?? 0}',
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700)),
                  if (other != null && (mine[k] ?? 0) != (other[k] ?? 0))
                    Text((mine[k] ?? 0) > (other[k] ?? 0) ? ' ↑' : ' ↓',
                        style: TextStyle(
                            color: (mine[k] ?? 0) > (other[k] ?? 0)
                                ? _up
                                : _down,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w900)),
                ]),
            ]),
          ),
      ],
    );
  }
}
