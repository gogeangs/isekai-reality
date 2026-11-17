import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../town/material_view.dart';
import 'npc_header.dart' show NpcFace;

/// 건물 레벨업 (묶음 54): 시설 맨 위 마을 사람 말풍선 아래 작은 칸.
/// 「★2로 고치기」(모은 정도 점) → 고치기 창 · 고치는 중이면 「고치는 중 · ○분」.
class BuildingUpgradeBar extends StatelessWidget {
  const BuildingUpgradeBar({super.key, required this.controller, required this.npc});

  final AppController controller;
  final Npc npc;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final c = controller;
          final b = BuildingRules.ofNpc(npc);
          if (b == null || !c.buildingsOpen || !c.facilityOpen(b.name)) {
            return const SizedBox.shrink();
          }
          final star = c.buildingStar(b);
          final left = c.buildingFixLeft(b);
          final Widget chip;
          if (left != null) {
            chip = _Chip(
              key: Key('upgradeFixing_${b.name}'),
              icon: Icons.construction_rounded,
              text: '고치는 중 · ${fixLeftText(left)}',
              onTap: () => showBuildingSheet(context, c, b),
            );
          } else if (star >= BuildingRules.maxStar) {
            chip = _Chip(
              key: Key('upgradeMax_${b.name}'),
              icon: Icons.star_rounded,
              text: '★$star 건물',
              onTap: () => showBuildingSheet(context, c, b),
            );
          } else {
            final (have, all) = c.buildingProgress(b);
            chip = _Chip(
              key: Key('upgradeOpen_${b.name}'),
              icon: Icons.handyman_rounded,
              text: '★${star + 1}로 고치기',
              ready: have == all,
              dots: (have, all),
              onTap: () => showBuildingSheet(context, c, b),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(alignment: Alignment.centerLeft, child: chip),
          );
        },
      );
}

/// 남은 시간 「1시간 20분」 · 「5분」
String fixLeftText(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  if (h > 0) return m > 0 ? '$h시간 $m분' : '$h시간';
  return '${m < 1 ? 1 : m}분';
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
    this.ready = false,
    this.dots,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool ready;
  final (int, int)? dots;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
          decoration: BoxDecoration(
            gradient: ready ? kGoldGradient : null,
            color: ready ? null : const Color(0xCC0B0D26),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.8)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: ready ? AppColors.goldInk : AppColors.goldBright),
            const SizedBox(width: 5),
            Text(text,
                style: TextStyle(
                    color: ready ? AppColors.goldInk : const Color(0xFFE6DCC4),
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
            if (dots case (final have, final all)) ...[
              const SizedBox(width: 6),
              ProgressDots(have: have, all: all, ink: ready),
            ],
          ]),
        ),
      );
}

/// 모은 정도 (채운 칸은 금빛 점)
class ProgressDots extends StatelessWidget {
  const ProgressDots({super.key, required this.have, required this.all, this.ink = false});

  final int have;
  final int all;
  final bool ink;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < all; i++)
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < have
                  ? (ink ? AppColors.goldInk : AppColors.goldBright)
                  : const Color(0x55FFFFFF),
            ),
          ),
      ]);
}

/// 고치기 창: 마을 사람 「고치려면 이게 필요해」 + 필요한 것 + 「가져다 주기」
Future<void> showBuildingSheet(BuildContext context, AppController c, Building b) {
  final info = BuildingRules.info(b);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.night,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheet) => SafeArea(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final star = c.buildingStar(b);
          final left = c.buildingFixLeft(b);
          final need = c.buildingNeed(b);
          final say = left != null
              ? BuildingRules.fixingLine
              : need == null
                  ? BuildingRules.maxLine
                  : BuildingRules.needLine;
          return SingleChildScrollView(
            key: const Key('buildingSheet'),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  NpcFace(npc: info.npc, size: 52),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(child: Text(info.name, style: AppText.title(18))),
                          const SizedBox(width: 6),
                          _Stars(star: star),
                        ]),
                        KText(say,
                            key: const Key('buildingSay'),
                            style: const TextStyle(
                                color: Color(0xFFE6DCC4),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                // 지금 좋아진 것
                if (star >= 2)
                  for (var s = 2; s <= star; s++)
                    _EffectLine(star: s, text: info.textFor(s), got: true),
                if (left != null) ...[
                  _EffectLine(star: star + 1, text: info.textFor(star + 1), got: false),
                  const SizedBox(height: 10),
                  OrnatePanel(
                    child: Row(children: [
                      const Icon(Icons.construction_rounded,
                          color: AppColors.goldBright, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: KText(
                            '고치는 중이에요 · ${fixLeftText(left)} 남았어요',
                            key: const Key('buildingFixLeft'),
                            style: const TextStyle(color: AppColors.text, fontSize: 14)),
                      ),
                    ]),
                  ),
                ] else if (need != null) ...[
                  _EffectLine(star: star + 1, text: info.textFor(star + 1), got: false),
                  const SizedBox(height: 10),
                  OrnatePanel(
                    key: const Key('buildingNeed'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Text('★${star + 1}로 고치려면', style: AppText.title(15)),
                          const Spacer(),
                          ProgressDots(
                              have: c.buildingProgress(b).$1,
                              all: c.buildingProgress(b).$2),
                        ]),
                        const SizedBox(height: 8),
                        _NeedRow(
                          icon: Image.asset('assets/images/icon_gold.webp',
                              width: 24,
                              height: 24,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.monetization_on_rounded,
                                  color: AppColors.goldBright,
                                  size: 22)),
                          name: '금화',
                          have: c.player.gold,
                          need: need.gold,
                        ),
                        for (final e in need.mats.entries)
                          _NeedRow(
                            key: Key('buildingMat_${e.key.name}'),
                            icon: MaterialIcon(e.key, size: 24),
                            name: Materials.info(e.key).name,
                            have: c.player.materialCount(e.key),
                            need: e.value,
                          ),
                        const SizedBox(height: 6),
                        KText(
                            '고치는 데 ${BuildingRules.fixTime(star + 1).inHours}시간 · '
                            '그동안에도 그대로 쓸 수 있어요',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GoldButton(
                    key: const Key('buildingDeliver'),
                    label: '가져다 주기',
                    height: 50,
                    fontSize: 19,
                    onPressed: c.canUpgradeBuilding(b)
                        ? () async {
                            final ok = await c.deliverBuilding(b);
                            if (!sheet.mounted) return;
                            Navigator.of(sheet).pop();
                            if (ok && context.mounted) {
                              showTopNotice(
                                  context,
                                  '${info.name}을 고치기 시작했어요! '
                                  '${BuildingRules.fixTime(star + 1).inHours}시간 뒤 ★${star + 1}',
                                  icon: Icons.construction_rounded);
                            }
                          }
                        : null,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _Stars extends StatelessWidget {
  const _Stars({required this.star});

  final int star;

  @override
  Widget build(BuildContext context) => Row(
        key: const Key('buildingStars'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < BuildingRules.maxStar; i++)
            Icon(i < star ? Icons.star_rounded : Icons.star_border_rounded,
                size: 18, color: AppColors.goldBright),
        ],
      );
}

class _EffectLine extends StatelessWidget {
  const _EffectLine({required this.star, required this.text, required this.got});

  final int star;
  final String text;
  final bool got;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('★$star',
              style: TextStyle(
                  color: got ? AppColors.goldBright : AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          Expanded(
            child: KText(got ? text : '고치면 · $text',
                style: TextStyle(
                    color: got ? AppColors.text : AppColors.textMuted,
                    fontSize: 13.5,
                    height: 1.35)),
          ),
        ]),
      );
}

class _NeedRow extends StatelessWidget {
  const _NeedRow({
    super.key,
    required this.icon,
    required this.name,
    required this.have,
    required this.need,
  });

  final Widget icon;
  final String name;
  final int have;
  final int need;

  @override
  Widget build(BuildContext context) {
    final ok = have >= need;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 28, child: Center(child: icon)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(name,
              style: const TextStyle(color: AppColors.text, fontSize: 14)),
        ),
        Text('${comma(have)} / ${comma(need)}',
            style: TextStyle(
                color: ok ? AppColors.goldBright : const Color(0xFFFF8A80),
                fontSize: 14,
                fontWeight: FontWeight.w800)),
        const SizedBox(width: 4),
        Icon(ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16, color: ok ? AppColors.goldBright : AppColors.textMuted),
      ]),
    );
  }
}
