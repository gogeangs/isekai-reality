import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../town/material_view.dart';
import 'harvest_games.dart';
import '../bulssi/bulssi_bubble.dart';
import '../../theme/top_notice.dart';
import '../../core/format.dart';
import '../jobs/job_skill_bar.dart';

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
    BuildContext context, AppController c, HarvestSpot spot) async {
  // 묶음 31: 길 찾기 보물 상자 (도구 없이 연다)
  if (c.isTreasure(spot)) return _showTreasure(context, c, spot);
  // 묶음 20 #4: 새로 시작한 사람은 채집 도구를 만들어야 채집할 수 있다
  if (c.harvestNeedsTool) {
    final name = HarvestRules.toolName(spot.info.tool);
    showTopNotice(context, '${josa(name, '이/가')} 필요해요. 대장간에서 만들 수 있어요',
        icon: Icons.handyman_rounded);
    return;
  }
  return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.night,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => HarvestSheet(controller: c, spot: spot),
    );
}

class HarvestSheet extends StatelessWidget {
  const HarvestSheet({super.key, required this.controller, required this.spot});

  final AppController controller;
  final HarvestSpot spot;

  Future<void> _go(BuildContext context, HarvestGrade grade,
      {Map<MaterialId, int>? done}) async {
    final c = controller;
    final mats = done ?? await c.harvestAt(spot, grade);
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
    // 묶음 28 #181: 고대 유물 예언 조각 (처음 세 번)
    final piece = c.takeProphecy();
    if (piece != null && context.mounted) {
      await showProphecy(context, piece);
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
                          Text(info.name, style: AppText.title(19)),
                          const SizedBox(height: 2),
                          Row(children: [
                            const Text('남은 횟수 ',
                                style: TextStyle(
                                    color: AppColors.goldBright, fontSize: 14)),
                            GlyphDots(
                                filled: charges,
                                total: HarvestRules.maxCharges,
                                size: 11),
                            if (refill != null)
                              Flexible(
                                child: Text(' · ${_left(refill)} 뒤 하나 더',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppColors.goldBright,
                                        fontSize: 14)),
                              ),
                          ]),
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
                  // 묶음 30 #55: 풍요의 손길 · 발굴
                  JobSkillBar(controller: c, places: [
                    spot.kind == HarvestKind.relic
                        ? SkillPlace.relic
                        : SkillPlace.harvest,
                  ]),
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
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ),
                  const SizedBox(height: 10),
                  Opacity(
                    opacity: game == HarvestCheck.ok ? 1 : 0.45,
                    child: FrameButton(
                      key: const Key('harvestGame'),
                      label: '미니게임 · ${info.game}',
                      onPressed: game == HarvestCheck.ok
                          ? () async {
                              final tier = c.toolTier(info.tool);
                              final r = await Navigator.of(context)
                                  .push<HarvestGameResult>(MaterialPageRoute(
                                      builder: (_) => HarvestGameScreen(
                                            kind: spot.kind,
                                            ease: c.harvestEase(spot.kind),
                                            toolAsset:
                                                'tool_${info.tool.name}_${tier.name}',
                                            toolName: '${tier.label} ${info.toolName}',
                                            base: info.base,
                                            first: c.harvestGameFirst(spot.kind),
                                            streak: c.harvestKindStreak(spot.kind),
                                            vibrate: c.vibrate,
                                            sound: c.sound,
                                            onStart: () =>
                                                c.markHarvestGameSeen(spot.kind),
                                            // 묶음 46: 결과 연출에서 받은 재료를 보여 주려고 화면 안에서 채집을 마친다
                                            resolve: (p) => c.harvestAt(
                                                spot, p.grade,
                                                rare: p.rare),
                                          )));
                              if (r == null || !context.mounted) return;
                              // 「그만두기」 → 빠른 채집
                              if (r.quit) {
                                await _go(context, HarvestGrade.quick);
                              } else if (r.mats != null) {
                                await _go(context, r.grade, done: r.mats);
                              }
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
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
            style: AppText.title(19)),
        content: options.isEmpty
            ? const KText('빛나는 속성 코어가 있어야 해요. 공방 「가공」에서 만들 수 있어요.',
                style: TextStyle(color: AppColors.text))
            : Column(mainAxisSize: MainAxisSize.min, children: [
                const KText(
                    '빛나는 속성 코어 1개 + 금화 ${EquipmentRules.imbueGold}. 그 속성의 귀한 재료가 더 잘 나와요.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
    // 묶음 20 #157: 채집이 열리기 전(새로 시작한 사람은 첫 도구를 만들기 전)에는 숨김
    if (!controller.featureOpen(Feature.harvest) ||
        !controller.harvestToolsReady) {
      return const SizedBox.shrink();
    }
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
              Image.asset('assets/images/tool_${t.name}_${c.toolTier(t).name}.webp',
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


/// 예언 조각 (묶음 28 #181): 양피지가 펼쳐지고 → 글귀 → 정령 한마디
Future<void> showProphecy(BuildContext context, int index) =>
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xCC05060F),
      builder: (d) => _ProphecyView(index: index),
    );

class _ProphecyView extends StatefulWidget {
  const _ProphecyView({required this.index});

  final int index;

  @override
  State<_ProphecyView> createState() => _ProphecyViewState();
}

class _ProphecyViewState extends State<_ProphecyView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
    ..forward();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (text, spirit) = HarvestRules.prophecy[widget.index];
    final w = math.min(340.0, MediaQuery.sizeOf(context).width - 32);
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _a,
          builder: (context, _) {
            // 0~0.35 양피지가 옆으로 펼쳐짐 · 0.35~0.7 글귀 · 0.7~ 정령 한마디
            final open = Curves.easeOutCubic
                .transform((_a.value / 0.35).clamp(0.0, 1.0));
            final textIn = ((_a.value - 0.35) / 0.35).clamp(0.0, 1.0);
            final spiritIn = ((_a.value - 0.7) / 0.3).clamp(0.0, 1.0);
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Text('예언 조각 ${widget.index + 1}',
                  key: const Key('prophecyTitle'),
                  style: AppText.title(15, color: AppColors.goldBright)),
              const SizedBox(height: 8),
              ClipRect(
                child: Align(
                  widthFactor: 0.15 + 0.85 * open,
                  child: SizedBox(
                    width: w,
                    child: Stack(children: [
                      Positioned.fill(
                        child: Image.asset('assets/images/board_note.webp',
                            scale: 2.4,
                            centerSlice: const Rect.fromLTRB(110, 92, 690, 308),
                            fit: BoxFit.fill,
                            errorBuilder: (_, __, ___) => DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1E0B8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                )),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(26, 30, 26, 30),
                        child: Opacity(
                          opacity: textIn,
                          child: Text(text,
                              key: const Key('prophecyText'),
                              textAlign: TextAlign.center,
                              style: AppText.title(17,
                                      color: const Color(0xFF3A2614))
                                  .copyWith(height: 1.6)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Opacity(
                opacity: spiritIn,
                child: SizedBox(
                    width: w,
                    child: BulssiBubble(
                        key: const Key('prophecySpirit'), line: spirit, size: 48)),
              ),
              const SizedBox(height: 10),
              Opacity(
                opacity: spiritIn,
                child: TextButton(
                  key: const Key('prophecyClose'),
                  onPressed: spiritIn < 1 ? null : () => Navigator.pop(context),
                  child: const Text('기록에 남겨 두기'),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}


/// 길 찾기 보물 상자
Future<void> _showTreasure(
        BuildContext context, AppController c, HarvestSpot spot) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.night,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) {
              final p = c.lastPoint;
              final near = p != null &&
                  spot.point.distanceTo(p) <= HarvestRules.reachM;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Image.asset('assets/images/icon_gold.webp',
                        width: 52, height: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('숨은 보물 상자', style: AppText.title(19)),
                          const SizedBox(height: 4),
                          const Text('길 찾기로 찾은 상자예요. 금화와 재료가 들어 있어요',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 13)),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  GoldButton(
                    label: near ? '상자 열기' : '가까이 가면 열 수 있어요',
                    onPressed: !near
                        ? null
                        : () async {
                            final mats = await c.openTreasure(spot);
                            if (!sheet.mounted) return;
                            Navigator.of(sheet).pop();
                            if (mats == null || !context.mounted) return;
                            final line = [
                              '금화 +${c.lastTreasureGold}',
                              for (final e in mats.entries)
                                '${Materials.info(e.key).name} +${e.value}',
                            ].join(', ');
                            showTopNotice(context, '보물 상자를 열었어요! $line',
                                icon: Icons.inventory_2_rounded);
                          },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
