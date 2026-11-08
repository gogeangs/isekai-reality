import 'package:flutter/material.dart';

import '../../core/rules/level_rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';

/// 레벨업 연출 (목업 확정본 기준). [from] → [to] 로 여러 레벨이 한 번에 오를 수도 있다.
class LevelUpDialog extends StatelessWidget {
  const LevelUpDialog({super.key, required this.from, required this.to});

  final int from;
  final int to;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 빛과 리본 배너
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 300,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.goldBright.withValues(alpha: 0.55),
                    Colors.transparent,
                  ]),
                ),
              ),
              Column(children: [
                const EyeEmblem(size: 54),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 26, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      Color(0xFF4A2C7A),
                      Color(0xFF6E3FA0),
                      Color(0xFF4A2C7A)
                    ]),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.goldBright, width: 1.5),
                  ),
                  child: Text('LEVEL UP', style: AppText.title(30)),
                ),
              ]),
            ],
          ),
          OrnatePanel(
            highlight: true,
            ornament: true,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              children: [
                const LaurelRow(),
                Text('Lv.$from  →  Lv.$to', style: AppText.title(36)),
                const SizedBox(height: 14),
                ChipBadge(
                    text: '다음 레벨까지 ${LevelRules.expRequiredFor(to)}',
                    icon: Icons.auto_awesome_rounded),
                const SizedBox(height: 16),
                BulssiBubble(line: _line),
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
