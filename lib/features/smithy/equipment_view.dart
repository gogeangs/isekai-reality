import 'package:flutter/material.dart';

import '../../core/models/armory.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';

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
              Icon(slotIcon(info.slot), color: color, size: size * 0.55)),
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
                  : equipGradeColor(it.grade).withValues(alpha: 0.8)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (it == null)
              Icon(slotIcon(slot), color: AppColors.textMuted, size: 26)
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
    if (g.stats.total > 0) '스탯 +${g.stats.total}',
  ];
  return parts.isEmpty ? '아직 입은 장비가 없어요' : parts.join(' · ');
}
