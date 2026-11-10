import 'package:flutter/material.dart';

import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';

/// 재료 그림 (mat_<이름>.png). 그림이 오기 전에는 아이콘으로 대신한다.
class MaterialIcon extends StatelessWidget {
  const MaterialIcon(this.id, {super.key, this.size = 36});

  final MaterialId id;
  final double size;

  static IconData fallback(MaterialId id) => switch (id) {
        MaterialId.slimeJelly => Icons.water_drop_rounded,
        MaterialId.slimeCore => Icons.blur_circular_rounded,
        MaterialId.ratHide => Icons.texture_rounded,
        MaterialId.glossyFur => Icons.auto_awesome_rounded,
        MaterialId.batWing => Icons.flight_rounded,
        MaterialId.batFang => Icons.change_history_rounded,
        MaterialId.butterflyDust => Icons.grain_rounded,
        MaterialId.sleepPowder => Icons.bedtime_rounded,
        MaterialId.wardenShard => Icons.landscape_rounded,
        MaterialId.labyrinthCore => Icons.diamond_rounded,
        MaterialId.ironShard => Icons.hardware_rounded,
        MaterialId.twig => Icons.park_rounded,
        MaterialId.poisonGland => Icons.science_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final info = Materials.info(id);
    return Image.asset(
      info.asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1E2250),
          border: Border.all(
              color: info.rare ? AppColors.goldBright : AppColors.gold,
              width: info.rare ? 2 : 1),
        ),
        child: Icon(fallback(id),
            size: size * 0.58,
            color: info.rare ? AppColors.goldBright : AppColors.text),
      ),
    );
  }
}

/// 마석·금화 한 줄 (아이콘 + 숫자)
class WalletChip extends StatelessWidget {
  const WalletChip(
      {super.key, required this.icon, required this.label, this.size = 26});

  /// 'mana_stone' 또는 'gold'
  final String icon;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameIcon(icon,
              size: size,
              fallback: icon == 'gold'
                  ? Icons.monetization_on_rounded
                  : Icons.diamond_rounded),
          const SizedBox(width: 5),
          Text(label,
              style: AppText.title(size * 0.72, color: AppColors.goldBright)),
        ],
      );
}

/// 마석 N · 금화 N
class WalletRow extends StatelessWidget {
  const WalletRow(
      {super.key, required this.manaStones, required this.gold, this.size = 26});

  final int manaStones;
  final int gold;
  final double size;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 4,
        children: [
          WalletChip(icon: 'mana_stone', label: '마석 $manaStones', size: size),
          WalletChip(icon: 'gold', label: '금화 $gold', size: size),
        ],
      );
}

/// 가진 재료 목록 (가방 탭)
class MaterialGrid extends StatelessWidget {
  const MaterialGrid({super.key, required this.materials});

  final Map<MaterialId, int> materials;

  @override
  Widget build(BuildContext context) {
    if (materials.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('아직 재료가 없어요. 몬스터를 사냥하면 떨어뜨려요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      );
    }
    final ids = [
      for (final m in MaterialId.values)
        if ((materials[m] ?? 0) > 0) m,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final id in ids)
          Tooltip(
            message: Materials.info(id).description,
            child: SizedBox(
              width: 72,
              child: Column(children: [
                MaterialIcon(id, size: 40),
                const SizedBox(height: 2),
                Text(Materials.info(id).name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                        color: Materials.info(id).rare
                            ? AppColors.goldBright
                            : AppColors.text,
                        fontSize: 11,
                        height: 1.2)),
                Text('× ${materials[id]}',
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
      ],
    );
  }
}

/// 사냥 보상 줄: 마석·금화·재료 아이콘과 개수
class RewardItems extends StatelessWidget {
  const RewardItems({super.key, required this.reward});

  final HuntReward reward;

  @override
  Widget build(BuildContext context) {
    Widget chip(Widget icon, String text) => Container(
          padding: const EdgeInsets.fromLTRB(4, 3, 9, 3),
          decoration: BoxDecoration(
            color: const Color(0xCC12153A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            icon,
            const SizedBox(width: 4),
            Text(text,
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ]),
        );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        if (reward.manaStones > 0)
          chip(
              const GameIcon('mana_stone',
                  size: 22, fallback: Icons.diamond_rounded),
              '마석 +${reward.manaStones}'),
        if (reward.gold > 0)
          chip(
              const GameIcon('gold',
                  size: 22, fallback: Icons.monetization_on_rounded),
              '금화 +${reward.gold}'),
        for (final e in reward.materials.entries)
          chip(MaterialIcon(e.key, size: 22),
              '${Materials.info(e.key).name} +${e.value}'),
      ],
    );
  }
}
