import 'package:flutter/material.dart' hide Element;

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
    // 고대 유물: 옛 이야기 한 조각 (11-11 #83)
    final lore = c.lastRelicLore;
    if (spot.kind == HarvestKind.relic && lore != null) {
      showTopNotice(context, '옛 이야기 · $lore',
          icon: Icons.menu_book_rounded, duration: const Duration(seconds: 6));
    }
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
                              switch (spot.kind) {
                                HarvestKind.mushroom => '그늘버섯·독버섯이 늘 나오고, 가끔 달빛 버섯',
                                HarvestKind.flower => '계절 꽃잎이 늘 나오고, 가끔 햇살 꽃가루·바람꽃',
                                HarvestKind.gem => '원석 조각이 늘 나오고, 가끔 속성 보석',
                                _ => '${Materials.info(info.base).name}이(가) 늘 나오고, 가끔 ${Materials.info(info.rare).name}',
                              },
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
                                      builder: (_) => HarvestGameScreen(
                                          kind: spot.kind,
                                          ease: c.harvestEase(spot.kind))));
                              if (g != null && context.mounted) await _go(context, g);
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                      game == HarvestCheck.ok || game == quick
                          ? '${c.toolTier(info.tool).label} ${info.toolName} 내구도 $dur / ${c.toolMaxOf(info.tool)} · 잘하면 더 많이, 귀한 재료도 잘 나와요'
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

/// 채집 도구 목록·수리·등급·속성 (대장간: 곡괭이·도끼, 공방: 낫·낚싯대·붓)
class ToolRepairPanel extends StatelessWidget {
  const ToolRepairPanel({super.key, required this.controller, required this.smithy});

  final AppController controller;
  final bool smithy;

  /// 빛나는 속성 코어가 있는 속성만 고를 수 있다 (금화 100)
  Future<void> _imbue(BuildContext context, HarvestTool t) async {
    final c = controller;
    final options = [
      for (final e in Element.values)
        if (c.player.materialCount(EquipmentRules.imbueCore(e)) > 0) e,
    ];
    final picked = await showDialog<Element>(
      context: context,
      builder: (d) => GameAlert(
        title: Text('${HarvestRules.toolName(t)}에 속성 입히기',
            style: AppText.title(18)),
        content: options.isEmpty
            ? const KText('빛나는 속성 코어가 있어야 해요. 공방 「가공」에서 만들 수 있어요.',
                style: TextStyle(color: AppColors.text))
            : Column(mainAxisSize: MainAxisSize.min, children: [
                const KText(
                    '빛나는 속성 코어 1개 + 금화 ${EquipmentRules.imbueGold}. 그 속성의 귀한 재료가 더 잘 나와요.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final e in options)
                    ActionChip(
                      label: Text(e.label),
                      onPressed: () => Navigator.of(d).pop(e),
                    ),
                ]),
              ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(), child: const Text('닫기')),
        ],
      ),
    );
    if (picked == null) return;
    final ok = await c.imbueTool(t, picked);
    if (context.mounted) {
      showTopNotice(context,
          ok ? '${HarvestRules.toolName(t)}에 ${picked.label} 속성을 입혔어요!' : '금화나 코어가 모자라요.');
    }
  }

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
          Text('채집 도구', style: AppText.title(16)),
          const SizedBox(height: 2),
          KText(
              c.harvest.granted
                  ? '수리: 금화 ${HarvestRules.repairGold} + 재료 1개 · 더 좋은 도구로 만들면 오래 가고 채집이 쉬워져요.'
                  : '처음 채집할 때 기본 도구를 받아요.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          for (final t in tools) ...[
            const SizedBox(height: 6),
            Row(children: [
              // 도구 등급별 그림 (없으면 재료 아이콘)
              Image.asset('assets/images/tool_${t.name}_${c.toolTier(t).name}.png',
                  width: 28,
                  height: 28,
                  errorBuilder: (_, __, ___) =>
                      MaterialIcon(HarvestRules.ofTool(t).base, size: 28)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    '${c.toolTier(t).label} ${HarvestRules.toolName(t)}'
                    '${c.toolElement(t) == null ? '' : ' (${c.toolElement(t)!.label})'}'
                    ' ${c.toolDurability(t)} / ${c.toolMaxOf(t)}',
                    style: const TextStyle(color: AppColors.text)),
              ),
              TextButton(
                onPressed: c.harvest.granted &&
                        c.toolDurability(t) < c.toolMaxOf(t) &&
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
            Wrap(spacing: 6, children: [
              if (HarvestRules.upgradeCost(c.toolTier(t)) case final cost?)
                TextButton(
                  key: Key('toolUpgrade_${t.name}'),
                  onPressed: c.canUpgradeTool(t) == CraftCheck.ok
                      ? () async {
                          if (await c.upgradeTool(t) && context.mounted) {
                            showTopNotice(context,
                                '${c.toolTier(t).label} ${HarvestRules.toolName(t)}를 만들었어요!');
                          }
                        }
                      : null,
                  child: Text(
                      '${ToolTier.values[c.toolTier(t).index + 1].label} 도구로 (${[
                    for (final e in cost.mats.entries)
                      '${Materials.info(e.key).name} ${e.value}',
                    '금화 ${cost.gold}',
                  ].join(', ')})'),
                ),
              TextButton(
                key: Key('toolImbue_${t.name}'),
                onPressed: () => _imbue(context, t),
                child: const Text('속성 입히기'),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
