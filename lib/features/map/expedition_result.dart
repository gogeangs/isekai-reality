import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/models/vitals.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../battle/battle_view.dart';
import '../town/material_view.dart';
import '../../theme/top_notice.dart';

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
        BuildContext context, Expedition ex, String spiritName,
        {String? more, AppController? controller}) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        child: ExpeditionResultCard(
            ex: ex, spiritName: spiritName, more: more, controller: controller),
      ),
    );

class ExpeditionResultCard extends StatelessWidget {
  const ExpeditionResultCard(
      {super.key,
      required this.ex,
      required this.spiritName,
      this.more,
      this.controller});

  /// 광고 보상 버튼용 (없으면 버튼 없음)
  final AppController? controller;
  final Expedition ex;
  final String spiritName;

  /// 여러 원정이 한꺼번에 끝났을 때 '1 / 3'
  final String? more;

  static String ribbonAsset(ExpeditionOutcome o) => switch (o) {
        ExpeditionOutcome.success => 'assets/images/ribbon_success.webp',
        ExpeditionOutcome.fail => 'assets/images/ribbon_fail.webp',
        ExpeditionOutcome.missed => 'assets/images/ribbon_missed.webp',
      };

  /// 그림 안 가운데 띠의 위·아래 (그림 높이 비율). 그림마다 다르다 (11-11 #94)
  static (double, double) ribbonBand(ExpeditionOutcome o) => switch (o) {
        ExpeditionOutcome.success => (0.15, 0.51),
        ExpeditionOutcome.fail => (0.18, 0.53),
        ExpeditionOutcome.missed => (0.18, 0.53),
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
          // 리본 그림 위에 글자 (그림이 없으면 색 띠). 11-11 #94: 그림 안 가운데 띠
          // 자리(비율)에 정확히 맞추고, 띠 높이에 맞게 글자 크기를 정한다
          SizedBox(
            height: 84,
            child: Center(
              child: AspectRatio(
                aspectRatio: 3,
                child: LayoutBuilder(builder: (context, box) {
                  final (b0, b1) = ribbonBand(o);
                  final bandTop = box.maxHeight * b0;
                  final bandH = box.maxHeight * (b1 - b0);
                  final text = ribbonText(o);
                  final size = (bandH * 0.62).clamp(12.0, 26.0);
                  final style = AppText.title(size, color: AppColors.text)
                      .copyWith(height: 1.0);
                  return Stack(children: [
                    Positioned.fill(
                      child: Image.asset(
                        ribbonAsset(o),
                        fit: BoxFit.fill,
                        errorBuilder: (_, __, ___) => Stack(children: [
                          Positioned(
                            left: box.maxWidth * 0.12,
                            right: box.maxWidth * 0.12,
                            top: bandTop,
                            height: bandH,
                            child: Container(
                              decoration: BoxDecoration(
                                color: ribbonColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppColors.goldBright, width: 1.5),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    Positioned(
                      key: const Key('ribbonText'),
                      left: box.maxWidth * 0.18,
                      right: box.maxWidth * 0.18,
                      top: bandTop + bandH * 0.12,
                      height: bandH * 0.76,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Stack(children: [
                            // 테두리
                            Text(text,
                                style: TextStyle(
                                    fontFamily: style.fontFamily,
                                    fontSize: style.fontSize,
                                    fontWeight: style.fontWeight,
                                    letterSpacing: style.letterSpacing,
                                    height: 1.0,
                                    foreground: Paint()
                                      ..style = PaintingStyle.stroke
                                      ..strokeWidth = 3
                                      ..color = const Color(0xCC1A1030))),
                            Text(text,
                                style: style.copyWith(shadows: const [
                                  Shadow(
                                      color: Color(0xCC000000), blurRadius: 4)
                                ])),
                          ]),
                        ),
                      ),
                    ),
                  ]);
                }),
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
                  color: AppColors.text, fontSize: 14, height: 1.4)),
          if (!reward.isEmpty) ...[
            const SizedBox(height: 12),
            RewardItems(reward: reward, showExp: true),
          ],
          const SizedBox(height: 14),
          if (more != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(more!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ),
          // 묶음 15 #103: 광고 보고 기본 보상 두 배 · 한 번 더 보내기
          if (controller case final c?)
            _AdRewards(controller: c, ex: ex),
          GoldButton(
            label: more != null &&
                    more!.split(' / ').first != more!.split(' / ').last
                ? '다음'
                : '좋아요',
            height: 46,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}


class _AdRewards extends StatefulWidget {
  const _AdRewards({required this.controller, required this.ex});

  final AppController controller;
  final Expedition ex;

  @override
  State<_AdRewards> createState() => _AdRewardsState();
}

class _AdRewardsState extends State<_AdRewards> {
  bool _doubled = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final ex = widget.ex;
    final canDouble = !_doubled && c.canDoubleExpedition(ex);
    if (!canDouble && !_doubled) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
            child: AdButton(
              key: const Key('adDouble'),
              label: _doubled ? '두 배 받았어요' : '광고 보고 두 배',
              height: 42,
              onPressed: _doubled
                  ? null
                  : () async {
                      final ok = await c.adDoubleExpedition(ex);
                      if (!mounted) return;
                      if (ok) {
                        setState(() => _doubled = true);
                      } else {
                        showTopNotice(context, '광고를 불러오지 못했어요.');
                      }
                    },
            ),
          ),
      ]),
    );
  }
}
