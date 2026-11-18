import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';

/// 묶음 65 #252: 홈 「걸음 상자가 도착했어요」 → 눌러 열기 (그날 안 열면 다음 날도 남음)
class StepChestRow extends StatelessWidget {
  const StepChestRow({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final chests = controller.stepChests;
          if (chests.isEmpty) return const SizedBox.shrink();
          final best = chests.map((c) => c.$2).reduce((a, b) => a > b ? a : b);
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GestureDetector(
              key: const Key('stepChestRow'),
              behavior: HitTestBehavior.opaque,
              onTap: () => openStepChests(context, controller),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                decoration: BoxDecoration(
                  color: const Color(0xAA12142E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
                ),
                child: Row(children: [
                  Image.asset(WalkRewardRules.chestArt[best],
                      width: 40, height: 40, errorBuilder: (_, __, ___) => const SizedBox(width: 40)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        chests.length > 1 ? '걸음 상자가 도착했어요 · ${chests.length}개' : '걸음 상자가 도착했어요',
                        style: const TextStyle(color: AppColors.goldBright, fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                  const Text('열기', style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w700)),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
                ]),
              ),
            ),
          );
        },
      );
}

Future<void> openStepChests(BuildContext context, AppController c) async {
  final r = await c.openStepChests();
  if (r == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (d) => GameAlert(
      key: const Key('stepChestOpened'),
      title: const Text('걸음 상자를 열었어요'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Image.asset(WalkRewardRules.chestArt[r.best], height: 80, errorBuilder: (_, __, ___) => const SizedBox()),
        const SizedBox(height: 6),
        for (final g in r.got)
          Text(g, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('좋아요'))],
    ),
  );
}
