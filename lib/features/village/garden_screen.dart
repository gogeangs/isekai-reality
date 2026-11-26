import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../town/material_view.dart';
import '../tutorial/feature_tour.dart' show TourScreenMark;
import 'npc_header.dart';

/// 마을 새 건물 「약초밭」 (묶음 48 #230): 포포 · 밭 칸(처음 3칸 → 6칸) · 씨앗 주머니.
/// 씨앗을 심으면 시간이 지나며 자란다 (묶음 66 #266, 앱을 꺼 둬도).
/// 칸마다 새싹 → 자람 → 다 자람(빛남) 모습 + 「약 ○시간 ○분 뒤」. 다 자란 것은 시들지 않는다
class GardenScreen extends StatelessWidget {
  const GardenScreen({super.key, required this.controller});

  final AppController controller;

  /// 묶음 85 #411: 씨앗마다 그림 (자람: 버섯 포자만 따로 · 다 자람: 약초 · 꽃 · 버섯 · 빛 씨앗)
  static String plotAsset(GardenPlotView p) {
    if (p.empty) return 'assets/images/garden_plot_empty.webp';
    final name = switch (p.stage) {
      0 => 'sprout',
      1 => p.seed == MaterialId.sporeSeed ? 'grow_mushroom' : 'grow',
      _ => switch (p.seed) {
          MaterialId.herbSeed => 'ready_herb',
          MaterialId.sporeSeed => 'ready_mushroom',
          MaterialId.glowSeed => 'ready_glow',
          _ => 'ready',
        },
    };
    return 'assets/images/garden_plot_$name.webp';
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final top = MediaQuery.paddingOf(context).top;
    return TourScreenMark(
      name: 'garden',
      child: Scaffold(
        key: const Key('gardenScreen'),
        backgroundColor: AppColors.deepNight,
        body: NightBackground(
          header: true,
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) {
              final plots = c.gardenPlots;
              final pouch = c.seedPouch;
              return ListView(
                padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
                children: [
                  OrnateTopBar(
                    title: '약초밭',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 6),
                  NpcHeader(
                    controller: c,
                    npc: Npc.popo,
                    guide: VillageRules.gardenGuide,
                    situation: c.gardenReady > 0
                        ? GardenRules.readyLine
                        : plots.any((p) => p.empty) && pouch.isNotEmpty
                            ? GardenRules.emptyLine
                            : null,
                  ),
                  const SizedBox(height: 10),
                  OrnatePanel(
                    key: const Key('gardenPlots'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Expanded(child: Text('밭', style: AppText.title(17))),
                        ]),
                        const SizedBox(height: 10),
                        LayoutBuilder(builder: (context, box) {
                          const gap = 8.0;
                          final w = (box.maxWidth - gap * 2) / 3;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final p in plots)
                                SizedBox(
                                    width: w,
                                    child: _PlotTile(controller: c, plot: p)),
                              for (var i = plots.length; i < GardenRules.maxPlots; i++)
                                SizedBox(width: w, child: _LockedTile(slot: i)),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  OrnatePanel(
                    key: const Key('gardenPouch'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('씨앗 주머니', style: AppText.title(17)),
                        const SizedBox(height: 8),
                        if (pouch.isEmpty)
                          const KText('씨앗이 없어요',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13))
                        else
                          for (final e in pouch.entries) _SeedRow(seed: e.key, count: e.value),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PlotTile extends StatelessWidget {
  const _PlotTile({required this.controller, required this.plot});

  final AppController controller;
  final GardenPlotView plot;

  Future<void> _plant(BuildContext context) async {
    final c = controller;
    final pouch = c.seedPouch;
    if (pouch.isEmpty) {
      showTopNotice(context, '심을 씨앗이 없어요. 채집하다 줍거나 잡화상에서 사요.',
          icon: Icons.grass_rounded);
      return;
    }
    final seed = await showModalBottomSheet<MaterialId>(
      context: context,
      backgroundColor: AppColors.night,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Padding(
          key: const Key('gardenSeedSheet'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('어떤 씨앗을 심을까요?', style: AppText.title(18)),
              const SizedBox(height: 10),
              for (final e in pouch.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    key: Key('plantSeed_${e.key.name}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(sheet).pop(e.key),
                    child: _SeedRow(seed: e.key, count: e.value),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (seed == null || !context.mounted) return;
    final ok = await c.plantSeed(plot.slot, seed);
    if (ok && context.mounted) {
      showTopNotice(context, '${josa(Materials.info(seed).name, '을/를')} 심었어요. 시간이 지나면 자라요!',
          icon: Icons.grass_rounded);
    }
  }

  Future<void> _harvest(BuildContext context) async {
    final r = await controller.harvestPlot(plot.slot);
    if (r == null || !context.mounted) return;
    showTopNotice(context, '${Materials.info(r.material).name} ${r.count}개를 거뒀어요!',
        icon: Icons.eco_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final p = plot;
    final seed = p.seed;
    final String line;
    if (seed == null) {
      line = '빈 칸';
    } else if (p.ready) {
      line = '다 자랐어요!';
    } else {
      line = p.leftText;
    }
    return Column(
      key: Key('gardenPlot_${p.slot}'),
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: GestureDetector(
            onTap: () => p.empty
                ? _plant(context)
                : p.ready
                    ? _harvest(context)
                    : null,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.slotBg,
                // 묶음 65 #257: 테두리 두께는 모두 같게, 다 자란 칸은 색 · 안쪽 빛으로만
                border: Border.all(
                    color: p.ready ? AppColors.goldBright : AppColors.gold.withValues(alpha: 0.45), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(fit: StackFit.expand, children: [
                  Image.asset(GardenScreen.plotAsset(p),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.grass_rounded,
                          color: AppColors.gold)),
                  if (seed != null)
                    Positioned(
                      left: 4,
                      top: 4,
                      child: MaterialIcon(seed, size: 22),
                    ),
                  if (p.ready)
                    const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [Color(0x00FFE7A0), Color(0x55FFD54F)],
                            stops: [0.55, 1],
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // 이름 + 상태 두 줄 자리 고정 (칸마다 버튼 높이가 같게)
        SizedBox(
          height: _GardenRows.of(context),
          child: Column(children: [
            Text(seed == null ? line : Materials.info(seed).name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w700)),
            if (seed != null)
              Text(line,
                  key: Key('gardenLeft_${p.slot}'),
                  maxLines: 1,
                  style: TextStyle(color: p.ready ? AppColors.goldBright : AppColors.textMuted, fontSize: 11.5)),
          ]),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 34,
          width: double.infinity,
          child: p.empty
              ? _TileButton(
                  key: Key('gardenPlant_${p.slot}'),
                  label: '심기',
                  onTap: () => _plant(context))
              : p.ready
                  ? _TileButton(
                      key: Key('gardenHarvest_${p.slot}'),
                      label: '거두기',
                      gold: true,
                      onTap: () => _harvest(context))
                  : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// 아직 못 쓰는 칸 (포포와 친해지면 늘어남)
class _LockedTile extends StatelessWidget {
  const _LockedTile({required this.slot});

  final int slot;

  @override
  Widget build(BuildContext context) => Column(
        key: Key('gardenLocked_$slot'),
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.slotBg.withValues(alpha: 0.5),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.lock_rounded, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 4),
          // 다른 칸과 같은 높이 (두 줄 + 버튼 자리)
          SizedBox(
            height: _GardenRows.of(context) + 4 + 34,
            child: const KText('포포의 부탁으로 넓어져요',
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ),
        ],
      );
}

/// 약초밭 칸 아래 글 자리 (이름 + 상태 두 줄)
abstract final class _GardenRows {
  static const double text = 34;
  static double of(BuildContext context) => MediaQuery.textScalerOf(context).scale(text);
}

class _SeedRow extends StatelessWidget {
  const _SeedRow({required this.seed, required this.count});

  final MaterialId seed;
  final int count;

  @override
  Widget build(BuildContext context) {
    final need = GardenRules.minutesOf(seed);
    return Container(
      key: Key('seed_${seed.name}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: AppColors.slotBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Row(children: [
        MaterialIcon(seed, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${Materials.info(seed).name} ×$count',
                style: const TextStyle(
                    color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
            Text('약 ${GardenRules.hoursText(need)}이면 다 자라요',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

class _TileButton extends StatelessWidget {
  const _TileButton(
      {super.key, required this.label, required this.onTap, this.gold = false});

  final String label;
  final VoidCallback onTap;
  final bool gold;

  @override
  Widget build(BuildContext context) => Material(
        color: gold ? const Color(0xFF3A2E0E) : const Color(0xFF1B1E4C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
              color: gold ? AppColors.goldBright : AppColors.gold, width: 1.3),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: gold ? AppColors.goldBright : AppColors.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      );
}
