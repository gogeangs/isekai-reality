import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';

/// 일일 의뢰 상자 (11-10: 상태 화면에서 의뢰 게시판으로 옮김)
// ───────────────────────────────────────────────────────────── 일일 퀘스트

class DailyQuestPanel extends StatelessWidget {
  const DailyQuestPanel({
    super.key,
    required this.quests,
    required this.allDone,
    required this.streak,
  });

  final List<QuestProgress> quests;
  final bool allDone;

  /// 3개를 모두 마친 날이 이어진 일수 (표시만)
  final int streak;

  @override
  Widget build(BuildContext context) {
    final total = quests.length * QuestRules.rewardExp + QuestRules.allDoneBonusExp;
    return FoldingQuestPanel(
      done: allDone,
      foldedText: '일일 퀘스트 모두 완료 · 연속 $streak일째 · EXP +$total',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const GameIcon('quest', size: 26),
            const SizedBox(width: 8),
            Text('일일 퀘스트', style: AppText.title(19)),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 1,
                color: AppColors.gold.withValues(alpha: 0.4),
              ),
            ),
          ]),
          const SizedBox(height: 2),
          for (final q in sortedQuests(quests)) QuestRowView(quest: q),
          const SizedBox(height: 8),
          AllDoneRow(done: allDone, streak: streak),
        ],
      ),
    );
  }
}

/// 진행 중인 의뢰를 위로, 끝낸 의뢰를 아래로 (11-11 #45)
List<QuestProgress> sortedQuests(List<QuestProgress> qs) => [
      for (final q in qs)
        if (!q.completed) q,
      for (final q in qs)
        if (q.completed) q,
    ];

/// 한 종류를 모두 끝내면 한 줄로 접히는 의뢰 상자 (11-11 #45). 누르면 펼친다.
class FoldingQuestPanel extends StatefulWidget {
  const FoldingQuestPanel({
    super.key,
    required this.done,
    required this.foldedText,
    required this.child,
  });

  final bool done;
  final String foldedText;
  final Widget child;

  @override
  State<FoldingQuestPanel> createState() => _FoldingQuestPanelState();
}

class _FoldingQuestPanelState extends State<FoldingQuestPanel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.done || _open) {
      return GestureDetector(
        onTap: widget.done ? () => setState(() => _open = false) : null,
        behavior: HitTestBehavior.translucent,
        child: OrnatePanel(child: widget.child),
      );
    }
    return GestureDetector(
      onTap: () => setState(() => _open = true),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xAA6FE3B0)),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF8FF0C4), size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: KText(widget.foldedText,
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
          const Icon(Icons.expand_more_rounded, color: AppColors.textMuted),
        ]),
      ),
    );
  }
}

/// 보상 표시 (아이콘 + 수량). [icon] 이 없으면 경험치 아이콘.
class RewardChip extends StatelessWidget {
  const RewardChip({super.key, required this.text, this.done = false, this.icon});

  final String text;
  final bool done;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 3, 8, 3),
      decoration: BoxDecoration(
        color: done ? const Color(0x3346E0A0) : const Color(0x33E8B04A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: done
                ? const Color(0xAA6FE3B0)
                : AppColors.gold.withValues(alpha: 0.7)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        done
            ? const Icon(Icons.check_rounded, size: 15, color: Color(0xFF8FF0C4))
            : icon ?? const GameIcon('exp', size: 16),
        const SizedBox(width: 3),
        Text(text,
            style: TextStyle(
                color: done ? const Color(0xFF8FF0C4) : AppColors.goldBright,
                fontSize: 12,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class QuestRowView extends StatelessWidget {
  const QuestRowView({super.key, required this.quest, this.rewardExp, this.extra = const []});

  final QuestProgress quest;

  /// 보상 경험치 (없으면 일일 퀘스트 경험치)
  final int? rewardExp;

  /// 경험치 말고 더 받는 보상 (예: 주간 의뢰의 금화)
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    final current =
        quest.unit == '보' ? comma(quest.current) : '${quest.current}';
    final target = quest.unit == '보' ? comma(quest.target) : '${quest.target}';
    // 끝낸 의뢰는 흐리게 (11-11 #45)
    return Opacity(
      opacity: quest.completed ? 0.55 : 1,
      child: Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0x66101333),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            gradient: quest.completed ? kGoldGradient : null,
            border: Border.all(color: AppColors.gold, width: 1.4),
          ),
          child: quest.completed
              ? const Icon(Icons.check_rounded,
                  size: 18, color: AppColors.goldInk)
              : null,
        ),
        const SizedBox(width: 10),
        // 이름은 넓게, 진행 막대는 이름 아래 짧게 (C2)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(keepAll(quest.title),
                  style: const TextStyle(color: AppColors.text, fontSize: 14)),
              const SizedBox(height: 4),
              if (quest.completed)
                Text('완료', style: AppText.title(14))
              else
                Row(children: [
                  SizedBox(
                    width: 70,
                    child: GlowBar(
                      ratio: quest.target == 0
                          ? 0
                          : quest.current / quest.target,
                      colors: BarColors.exp,
                      height: 6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text('$current / $target${quest.unit}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                  ),
                ]),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            RewardChip(
                text: 'EXP ${rewardExp ?? QuestRules.rewardExp}',
                done: quest.completed),
            for (final w in extra) ...[const SizedBox(height: 3), w],
          ],
        ),
      ]),
      ),
    );
  }
}

/// 3개 모두 완료 보너스 + 연속 달성 일수 (11-10 C2)
class AllDoneRow extends StatelessWidget {
  const AllDoneRow({super.key, required this.done, required this.streak});

  final bool done;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(colors: [
          AppColors.gold.withValues(alpha: done ? 0.28 : 0.14),
          AppColors.gold.withValues(alpha: 0.04),
        ]),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
      ),
      child: Row(children: [
        const GameIcon('medal', size: 26),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(done ? '모두 완료!' : '3개 모두 완료하면 보너스',
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              Text(
                streak > 0 ? '연속 달성 $streak일째' : '연속 달성을 시작해 보세요',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        RewardChip(text: 'EXP +${QuestRules.allDoneBonusExp}', done: done),
      ]),
    );
  }
}
