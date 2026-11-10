import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models/vitals.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../battle/battle_view.dart';
import '../town/material_view.dart';

/// 원정 결과 (성공·실패·놓쳤어요)
enum ExpeditionOutcome { success, fail, missed }

ExpeditionOutcome outcomeOf(Expedition ex) => ex.cleared == true
    ? ExpeditionOutcome.success
    : ex.escaped
        ? ExpeditionOutcome.missed
        : ExpeditionOutcome.fail;

/// 원정 결과에 받은 보상 ('exp'·'manaStone'·'gold'·재료 이름 → 수)
HuntReward rewardOf(Expedition ex) => HuntReward(
      exp: ex.reward['exp'] ?? 0,
      manaStones: ex.reward[Wallet.manaStone] ?? 0,
      gold: ex.reward[Wallet.gold] ?? 0,
      materials: {
        for (final e in ex.reward.entries)
          if (Materials.byName(e.key) case final m?) m: e.value,
      },
    );

/// 원정 결과 금테 카드 (11-11 #51)
Future<void> showExpeditionResult(
        BuildContext context, Expedition ex, String spiritName) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        child: ExpeditionResultCard(ex: ex, spiritName: spiritName),
      ),
    );

class ExpeditionResultCard extends StatelessWidget {
  const ExpeditionResultCard(
      {super.key, required this.ex, required this.spiritName});

  final Expedition ex;
  final String spiritName;

  static String ribbonAsset(ExpeditionOutcome o) => switch (o) {
        ExpeditionOutcome.success => 'assets/images/ribbon_success.png',
        ExpeditionOutcome.fail => 'assets/images/ribbon_fail.png',
        ExpeditionOutcome.missed => 'assets/images/ribbon_missed.png',
      };

  static String ribbonText(ExpeditionOutcome o) => switch (o) {
        ExpeditionOutcome.success => '원정 성공',
        ExpeditionOutcome.fail => '원정 실패',
        ExpeditionOutcome.missed => '놓쳤어요',
      };

  @override
  Widget build(BuildContext context) {
    final o = outcomeOf(ex);
    final id = Monsters.byName(ex.monster);
    final name = id == null ? '몬스터' : Monsters.info(id).name;
    final reward = rewardOf(ex);
    final line = switch (o) {
      ExpeditionOutcome.success =>
        '${josa(spiritName, '이/가')} ${josa(name, '을/를')} 사냥했어요!',
      ExpeditionOutcome.fail => '${josa(name, '이/가')} 너무 강했어요. '
          '${josa(spiritName, '은/는')} MP만 쓰고 무사히 돌아왔어요.',
      ExpeditionOutcome.missed => '${josa(name, '이/가')} 재빨리 도망쳤어요. '
          '${josa(spiritName, '은/는')} 무사히 돌아왔어요.',
    };
    final ribbonColor = switch (o) {
      ExpeditionOutcome.success => const Color(0xFFB8862B),
      ExpeditionOutcome.fail => const Color(0xFF7A3B4A),
      ExpeditionOutcome.missed => const Color(0xFF4A5378),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A2462), Color(0xFF141B3A)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.goldBright, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Color(0x99E8C66A), blurRadius: 18),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 64,
            child: Image.asset(
              ribbonAsset(o),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
                  decoration: BoxDecoration(
                    color: ribbonColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.goldBright, width: 1.5),
                  ),
                  child: Text(ribbonText(o),
                      style: AppText.title(22, color: AppColors.text)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Opacity(
              opacity: o == ExpeditionOutcome.success ? 1 : 0.55,
              child: MonsterPicture(
                  monster: id ?? MonsterId.ashSlime, size: 120),
            ),
          ),
          if (ex.newSpecies)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('도감에 새로 올랐어요!',
                    style: TextStyle(
                        color: AppColors.night,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          const SizedBox(height: 10),
          KText(line,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.text, fontSize: 15, height: 1.4)),
          if (!reward.isEmpty) ...[
            const SizedBox(height: 12),
            RewardItems(reward: reward, showExp: true),
          ],
          const SizedBox(height: 14),
          GoldButton(
            label: '좋아요',
            height: 46,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
