import 'package:flutter/material.dart' hide Element;

import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../battle/element_view.dart';

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
        MaterialId.rabbitMeat || MaterialId.boarMeat => Icons.set_meal_rounded,
        MaterialId.smallHorn => Icons.change_history_rounded,
        MaterialId.goldenRabbitFur => Icons.auto_awesome_rounded,
        MaterialId.toughHide => Icons.texture_rounded,
        MaterialId.smallTusk => Icons.change_history_rounded,
        MaterialId.fireJelly || MaterialId.fireCore => Icons.local_fire_department_rounded,
        MaterialId.waterJelly || MaterialId.waterCore => Icons.water_drop_rounded,
        MaterialId.windJelly || MaterialId.windCore => Icons.air_rounded,
        MaterialId.mudJelly || MaterialId.earthCore => Icons.landscape_rounded,
        MaterialId.lightJelly || MaterialId.lightCore => Icons.wb_sunny_rounded,
        MaterialId.darkJelly || MaterialId.shadowCore => Icons.dark_mode_rounded,
        MaterialId.herb => Icons.eco_rounded,
        MaterialId.labyrinthStone => Icons.view_in_ar_rounded,
        MaterialId.runeStone => Icons.auto_fix_high_rounded,
        MaterialId.ironIngot => Icons.view_agenda_rounded,
        MaterialId.hardWood => Icons.forest_rounded,
        MaterialId.tannedLeather => Icons.layers_rounded,
        MaterialId.herbExtract => Icons.local_drink_rounded,
        MaterialId.essence => Icons.opacity_rounded,
        MaterialId.glowFireCore => Icons.local_fire_department_rounded,
        MaterialId.glowWaterCore => Icons.water_drop_rounded,
        MaterialId.glowWindCore => Icons.air_rounded,
        MaterialId.glowEarthCore => Icons.landscape_rounded,
        MaterialId.glowLightCore => Icons.wb_sunny_rounded,
        MaterialId.glowShadowCore => Icons.dark_mode_rounded,
        MaterialId.iceJelly || MaterialId.iceCore || MaterialId.glowIceCore =>
          Icons.ac_unit_rounded,
        MaterialId.thunderJelly ||
        MaterialId.thunderCore ||
        MaterialId.glowThunderCore =>
          Icons.bolt_rounded,
        MaterialId.metalJelly || MaterialId.metalCore || MaterialId.glowMetalCore =>
          Icons.hardware_rounded,
        MaterialId.poisonJelly ||
        MaterialId.poisonCore ||
        MaterialId.glowPoisonCore =>
          Icons.science_rounded,
        MaterialId.dewHerb => Icons.spa_rounded,
        MaterialId.manaOre => Icons.diamond_rounded,
        MaterialId.sturdyKnot => Icons.forest_rounded,
        MaterialId.riverPearl => Icons.circle_rounded,
        // 속성 마석 (11-11 #74): 마석 모양
        MaterialId.stoneFire ||
        MaterialId.stoneWater ||
        MaterialId.stoneWind ||
        MaterialId.stoneEarth ||
        MaterialId.stoneLight ||
        MaterialId.stoneDark ||
        MaterialId.stoneIce ||
        MaterialId.stoneThunder ||
        MaterialId.stoneMetal ||
        MaterialId.stonePoison =>
          Icons.hexagon_rounded,
        // 보스 전용 재료 (11-11 #75)
        MaterialId.bossWardenHeart => Icons.favorite_rounded,
        MaterialId.bossKingOrb => Icons.local_fire_department_rounded,
        MaterialId.bossFrostFang => Icons.ac_unit_rounded,
        MaterialId.bossTreantHeart => Icons.park_rounded,
        MaterialId.bossQueenWing => Icons.dark_mode_rounded,
        MaterialId.bossThunderFeather => Icons.bolt_rounded,
        MaterialId.bossShard => Icons.extension_rounded,
        // 11-11 #83 채집 2
        MaterialId.shadeMushroom ||
        MaterialId.poisonMushroom ||
        MaterialId.moonMushroom =>
          Icons.emoji_nature_rounded,
        MaterialId.springPetal ||
        MaterialId.summerPetal ||
        MaterialId.autumnPetal ||
        MaterialId.winterPetal =>
          Icons.local_florist_rounded,
        MaterialId.sunPollen => Icons.wb_sunny_rounded,
        MaterialId.breezeBloom => Icons.filter_vintage_rounded,
        MaterialId.roughGem => Icons.diamond_outlined,
        MaterialId.gemFire ||
        MaterialId.gemWater ||
        MaterialId.gemWind ||
        MaterialId.gemEarth ||
        MaterialId.gemLight ||
        MaterialId.gemDark ||
        MaterialId.gemIce ||
        MaterialId.gemThunder ||
        MaterialId.gemMetal ||
        MaterialId.gemPoison =>
          Icons.diamond_rounded,
        MaterialId.ancientShard => Icons.account_balance_rounded,
        MaterialId.relicSeal => Icons.verified_rounded,
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
          color: AppColors.chipBg,
          border: Border.all(
              color: info.rare ? AppColors.goldBright : AppColors.gold,
              width: info.rare ? 2 : 1),
        ),
        child: Icon(fallback(id),
            size: size * 0.58,
            color: fallback(id) == Icons.hexagon_rounded
                ? elementColor(Materials.elementOf(id))
                : info.rare
                    ? AppColors.goldBright
                    : AppColors.text),
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
        child: KText('아직 재료가 없어요. 몬스터를 사냥하면 떨어뜨려요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
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
                        fontSize: 12,
                        height: 1.2)),
                Text('× ${materials[id]}',
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
      ],
    );
  }
}

/// 보상 칸 (11-11 #51): 전투·던전·원정 결과가 같이 쓴다.
/// 네모 칸 안에 그림, 아래에 이름과 개수. [showExp] 이면 경험치 칸도.
class RewardItems extends StatelessWidget {
  const RewardItems({super.key, required this.reward, this.showExp = false});

  final HuntReward reward;
  final bool showExp;

  @override
  Widget build(BuildContext context) {
    final slots = <(Widget, String, String, bool)>[
      if (showExp && reward.exp > 0)
        (
          const Icon(Icons.auto_awesome_rounded,
              color: AppColors.goldBright, size: 28),
          '경험치',
          '+${reward.exp}',
          false
        ),
      if (reward.manaStones > 0)
        (
          const GameIcon('mana_stone', size: 30, fallback: Icons.diamond_rounded),
          '마석',
          '+${reward.manaStones}',
          false
        ),
      if (reward.gold > 0)
        (
          const GameIcon('gold',
              size: 30, fallback: Icons.monetization_on_rounded),
          '금화',
          '+${reward.gold}',
          false
        ),
      for (final e in reward.materials.entries)
        (
          MaterialIcon(e.key, size: 32),
          Materials.info(e.key).name,
          '+${e.value}',
          Materials.info(e.key).rare
        ),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (icon, name, count, rare) in slots)
          SizedBox(
            width: 64,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.slotBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: rare
                          ? AppColors.goldBright
                          : AppColors.gold.withValues(alpha: 0.55),
                      width: rare ? 2 : 1),
                ),
                child: Stack(children: [
                  Center(child: icon),
                  Positioned(
                    right: 3,
                    bottom: 1,
                    child: Text(count,
                        style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            shadows: [Shadow(blurRadius: 3)])),
                  ),
                ]),
              ),
              const SizedBox(height: 3),
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ]),
          ),
      ],
    );
  }
}
