import 'package:flutter/material.dart';

import '../../core/rules/level_rules.dart';
import '../../theme/app_colors.dart';
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              color: AppColors.night,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.gold, width: 2),
              boxShadow: [
                BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.45),
                    blurRadius: 40,
                    spreadRadius: 4),
              ],
            ),
            child: Column(
              children: [
                const Text('LEVEL UP',
                    style: TextStyle(
                        color: AppColors.goldBright,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2)),
                const SizedBox(height: 12),
                Text('Lv.$from  →  Lv.$to',
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 34,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.panelBorder),
                  ),
                  child: Text(
                    '다음 레벨까지 ${LevelRules.expRequiredFor(to)}',
                    style: const TextStyle(color: AppColors.text, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 20),
                BulssiBubble(line: _line),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.night,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('계속',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
