import 'package:flutter/material.dart';

import '../../core/rules/level_rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';
import '../bulssi/spirit_art.dart';

/// 레벨업 연출 (목업 확정본 기준). [from] → [to] 로 여러 레벨이 한 번에 오를 수도 있다.
class LevelUpDialog extends StatelessWidget {
  const LevelUpDialog(
      {super.key, required this.from, required this.to, this.title});

  final int from;
  final int to;

  /// 대표 칭호 (월계관 배지 리본에 쓴다)
  final String? title;

  /// 불씨 대사 36~39
  String get _line {
    if (from < 10 && to >= 10) return 'Lv.10이야! 이제 진짜 각성자다운걸?';
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
                Text('Lv.$from  →  Lv.$to', style: AppText.title(24)),
                const SizedBox(height: 14),
                ChipBadge(
                    text: '다음 레벨까지 ${LevelRules.expRequiredFor(to)}',
                    icon: Icons.auto_awesome_rounded),
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
