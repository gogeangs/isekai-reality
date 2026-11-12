import 'package:flutter/material.dart';

import '../../core/rules/level_rules.dart';
import '../../core/rules/stat_rules.dart';
import '../status/stat_icon.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';
import '../bulssi/spirit_art.dart';

/// 레벨업 연출 (목업 확정본 기준). [from] → [to] 로 여러 레벨이 한 번에 오를 수도 있다.
class LevelUpDialog extends StatelessWidget {
  const LevelUpDialog(
      {super.key,
      required this.from,
      required this.to,
      this.title,
      this.healedFrom});

  final int from;
  final int to;

  /// 레벨 업으로 채우기 전 HP·MP (묶음 14 #102). 있으면 막대가 가득 차오른다.
  final ({int hp, int maxHp, int mp, int mpMax})? healedFrom;

  /// 대표 칭호 (월계관 배지 리본에 쓴다)
  final String? title;

  /// 불씨 대사 36~39
  String get _line {
    if (from < 10 && to >= 10) return 'Lv.10이야! 이제 진짜 각성자다운걸?';
    // #102: HP·MP가 가득 찼다는 대사
    if (healedFrom != null) {
      const healed = [
        '레벨 업! 힘이 가득 차올랐어.',
        '레벨 업! 몸도 마음도 개운해졌지?',
        '레벨 업! 지친 것도 싹 날아갔어.',
      ];
      return healed[to % healed.length];
    }
    const lines = [
      '레벨 업! 네 불꽃이 한층 더 밝아졌어.',
      '이세계 어딘가가 조금 더 환해졌을 거야.',
      '또 성장했네! 매일매일 강해지고 있어.',
    ];
    return lines[to % lines.length];
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18),
      child: SingleChildScrollView(
       child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 빛과 리본 배너
          const ArtBanner(
            asset: 'assets/images/banner_levelup.png',
            width: 230,
            aspect: 520 / 489,
            text: 'LEVEL UP',
            textOffset: 0.08,
            fontSize: 30,
          ),
          const SizedBox(height: 4),
          OrnatePanel(
            highlight: true,
            ornament: true,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              children: [
                // 큰 월계관 배지는 평소 상태창에서 빼고 레벨업 순간에만 (11-10 C1)
                LaurelBadge(level: to, title: title ?? '새내기 각성자'),
                Text('Lv.$from  →  Lv.$to', style: AppText.level(22)),
                const SizedBox(height: 14),
                ChipBadge(
                    text: '다음 레벨까지 ${LevelRules.expRequiredFor(to)}',
                    icon: Icons.auto_awesome_rounded),
                const SizedBox(height: 10),
                // 11-11 #95: 받은 스탯 포인트 + 다섯 스탯 메달
                Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final k in StatKind.values) ...[
                    StatIcon(k, size: 22),
                    const SizedBox(width: 4),
                  ],
                  const SizedBox(width: 4),
                  Text('스탯 포인트 +${(to - from) * StatRules.pointsPerLevel}',
                      style: const TextStyle(
                          color: AppColors.goldBright,
                          fontWeight: FontWeight.w700)),
                ]),
                if (healedFrom case final h?) ...[
                  const SizedBox(height: 12),
                  _RefillBars(from: h),
                ],
                const SizedBox(height: 16),
                BulssiBubble(line: _line, mood: SpiritMood.cheer),
                const SizedBox(height: 18),
                GoldButton(
                  label: '계속',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
       ),
      ),
    );
  }
}

/// 작은 장식 줄: ✦ ─── ✦
class LaurelRow extends StatelessWidget {
  const LaurelRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Diamond(size: 6),
        SizedBox(width: 8),
        Icon(Icons.auto_awesome_rounded, color: AppColors.goldBright, size: 18),
        SizedBox(width: 8),
        Diamond(size: 6),
      ]),
    );
  }
}

/// HP·MP 막대가 가득 차오르는 짧은 연출 (#102)
class _RefillBars extends StatelessWidget {
  const _RefillBars({required this.from});

  final ({int hp, int maxHp, int mp, int mpMax}) from;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final hp0 = from.maxHp == 0 ? 1.0 : from.hp / from.maxHp;
    final mp0 = from.mpMax == 0 ? 1.0 : from.mp / from.mpMax;
    return Column(key: const Key('levelUpRefill'), children: [
      const Text('HP·MP가 가득 찼어요',
          style: TextStyle(
              color: AppColors.goldBright, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: still ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, t, __) => Column(children: [
          Row(children: [
            const SizedBox(
                width: 34,
                child: Text('HP',
                    style: TextStyle(color: AppColors.text, fontSize: 12))),
            Expanded(
                child: GlowBar(
                    ratio: hp0 + (1 - hp0) * t, colors: BarColors.hp, height: 8)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const SizedBox(
                width: 34,
                child: Text('MP',
                    style: TextStyle(color: AppColors.text, fontSize: 12))),
            Expanded(
                child: GlowBar(
                    ratio: mp0 + (1 - mp0) * t,
                    colors: BarColors.mana,
                    height: 8)),
          ]),
        ]),
      ),
    ]);
  }
}
