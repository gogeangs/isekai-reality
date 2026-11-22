import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/top_notice.dart';
import '../alchemy/alchemy_screen.dart' show PotionIcon;

/// 묶음 81 #378: 상태 화면 HP · MP · 기력 막대 아래 지금 걸린 물약 칩 줄
/// (물약 그림 · 이름 · 남은 전투/시간/걸음 — 지도 물약 띠와 같은 값). 누르면 효과 한 줄. 없으면 null
Widget? buffChips(AppController c) {
  final buffs = c.activeBuffs;
  if (buffs.isEmpty) return null;
  return Wrap(
    key: const Key('statusBuffs'),
    spacing: 6,
    runSpacing: 4,
    children: [
      for (final b in buffs)
        Builder(
          builder: (context) => GestureDetector(
            key: Key('statusBuff_${b.key}'),
            onTap: () {
              final id = AlchemyRules.byName(b.key);
              final effect = id == null ? c.buffName(b) : AlchemyRules.info(id).description;
              showTopNotice(context, '${c.buffName(b)} · $effect');
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(3, 2, 9, 2),
              decoration: BoxDecoration(
                color: const Color(0xE6151838),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                PotionIcon(potion: AlchemyRules.byName(b.key), suspicious: b.key.startsWith('?:'), size: 20),
                const SizedBox(width: 3),
                Text('${c.buffName(b)} · ${c.buffLeftLabel(b).replaceAll(' 남음', '')}',
                    style: const TextStyle(color: AppColors.text, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
    ],
  );
}
