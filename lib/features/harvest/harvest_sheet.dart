import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../town/material_view.dart';
import 'harvest_games.dart';
import '../../theme/top_notice.dart';

String harvestReason(HarvestCheck c) => switch (c) {
      HarvestCheck.ok => '',
      HarvestCheck.far => '가까이 가야 채집할 수 있어요',
      HarvestCheck.empty => '다 캤어요. 시간이 지나면 다시 차올라요',
      HarvestCheck.moving => '멈춰야 할 수 있어요',
      HarvestCheck.noTool => '도구가 닳았어요. 고치면 다시 할 수 있어요',
      HarvestCheck.passenger => '차 안에서는 할 수 없어요',
    };

String _left(Duration d) =>
    d.inMinutes >= 60 ? '${d.inHours}시간 ${d.inMinutes % 60}분' : '${d.inMinutes + 1}분';

/// 지도에서 채집 자리를 눌렀을 때 (11-11 #56)
Future<void> showHarvestSheet(
    BuildContext context, AppController c, HarvestSpot spot) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.night,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => HarvestSheet(controller: c, spot: spot),
    );

class HarvestSheet extends StatelessWidget {
  const HarvestSheet({super.key, required this.controller, required this.spot});

  final AppController controller;
  final HarvestSpot spot;

  Future<void> _go(BuildContext context, HarvestGrade grade) async {
    final c = controller;
    final mats = await c.harvestAt(spot, grade);
    if (!context.mounted || mats == null) return;
    final line = [
      for (final e in mats.entries) '${Materials.info(e.key).name} +${e.value}',
    ].join(', ');
    showTopNotice(context, grade == HarvestGrade.quick
            ? '채집했어요! $line'
            : '${gradeLabel(grade)} $line');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final c = controller;
          final info = spot.info;
          final charges = c.harvestCharges(spot);
          final refill = c.harvestRefill(spot);
          final quick = c.canHarvest(spot);
          final game = c.canHarvest(spot, minigame: true);
          final dur = c.toolDurability(info.tool);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    MaterialIcon(info.base, size: 56),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(info.name, style: AppText.title(20)),
                          const SizedBox(height: 2),
                          Text(
                              '남은 횟수 ${'●' * charges}${'○' * (HarvestRules.maxCharges - charges)}'
                              '${refill != null ? ' · ${_left(refill)} 뒤 하나 더' : ''}',
                              style: const TextStyle(color: AppColors.goldBright, fontSize: 13)),
                          Text(
                              '${Materials.info(info.base).name}이(가) 늘 나오고, 가끔 ${Materials.info(info.rare).name}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  GoldButton(
                    key: const Key('harvestQuick'),
                    label: '빠른 채집',
                    onPressed: quick == HarvestCheck.ok
                        ? () => _go(context, HarvestGrade.quick)
                        : null,
                  ),
                  if (quick != HarvestCheck.ok)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(harvestReason(quick),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                    ),
                  const SizedBox(height: 10),
                  Opacity(
                    opacity: game == HarvestCheck.ok ? 1 : 0.45,
                    child: FrameButton(
                      key: const Key('harvestGame'),
                      label: '미니게임 · ${info.game}',
                      onPressed: game == HarvestCheck.ok
                          ? () async {
                              final g = await Navigator.of(context).push<HarvestGrade>(
                                  MaterialPageRoute(
                                      builder: (_) => HarvestGameScreen(kind: spot.kind)));
                              if (g != null && context.mounted) await _go(context, g);
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                      game == HarvestCheck.ok || game == quick
                          ? '${info.toolName} 내구도 $dur / ${HarvestRules.toolMax} · 잘하면 더 많이, 귀한 재료도 잘 나와요'
                          : harvestReason(game),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                ],
              ),
            ),
          );
        },
      );
}

/// 채집 도구 목록과 수리 (대장간: 곡괭이·도끼, 공방: 낫·낚싯대)
class ToolRepairPanel extends StatelessWidget {
  const ToolRepairPanel({super.key, required this.controller, required this.smithy});

  final AppController controller;
  final bool smithy;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final tools = [
      for (final t in HarvestTool.values)
        if (HarvestRules.smithyTool(t) == smithy) t,
    ];
    return OrnatePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('채집 도구 수리', style: AppText.title(16)),
          const SizedBox(height: 2),
          KText(
              c.harvest.granted
                  ? '금화 ${HarvestRules.repairGold} + 재료 1개로 내구도를 다 채워요.'
                  : '처음 채집할 때 기본 도구를 받아요.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          for (final t in tools)
            Row(children: [
              MaterialIcon(HarvestRules.ofTool(t).base, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    '${HarvestRules.toolName(t)} ${c.toolDurability(t)} / ${HarvestRules.toolMax}',
                    style: const TextStyle(color: AppColors.text)),
              ),
              TextButton(
                onPressed: c.harvest.granted &&
                        c.toolDurability(t) < HarvestRules.toolMax &&
                        c.player.gold >= HarvestRules.repairGold &&
                        c.player.materialCount(HarvestRules.repairMaterial(t)) > 0
                    ? () async {
                        if (await c.repairTool(t) && context.mounted) {
                          showTopNotice(context, '${HarvestRules.toolName(t)}를 고쳤어요!');
                        }
                      }
                    : null,
                child: Text('수리 (${Materials.info(HarvestRules.repairMaterial(t)).name} 1)'),
              ),
            ]),
        ],
      ),
    );
  }
}
