import 'package:flutter/material.dart';

import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';

/// 수식어 등급 색 (11-10 #21): 없음 흰색, 일반 초록, 희귀 파랑, 전설 주황
Color modGradeColor(ModGrade g) => switch (g) {
      ModGrade.none => AppColors.text,
      ModGrade.common => const Color(0xFF7BE08A),
      ModGrade.rare => const Color(0xFF6BB4FF),
      ModGrade.legend => const Color(0xFFFFA244),
    };

/// 수식어 몬스터 설명 칸 (전투 전·결과 화면)
class ModifierPanel extends StatelessWidget {
  const ModifierPanel({super.key, required this.mods, this.foeCount = 1});

  final List<ModifierId> mods;

  /// 함께 나오는 몬스터 수
  final int foeCount;

  @override
  Widget build(BuildContext context) {
    if (mods.isEmpty) return const SizedBox.shrink();
    return OrnatePanel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final m in mods) _ModRow(info: ModifierRules.info(m)),
          if (foeCount > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: KText('$foeCount마리와 차례로 싸워요',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _ModRow extends StatelessWidget {
  const _ModRow({required this.info});

  final ModifierInfo info;

  @override
  Widget build(BuildContext context) {
    final color = modGradeColor(info.grade);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color),
          ),
          child: Text(ModifierRules.gradeLabel(info.grade),
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: '${info.name}  ',
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
              TextSpan(
                  text: info.behavior,
                  style: const TextStyle(color: AppColors.text, fontSize: 14)),
            ]),
          ),
        ),
      ]),
    );
  }
}
