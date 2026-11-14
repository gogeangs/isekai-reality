import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/ornaments.dart';
import 'board_parchment.dart';

/// 오늘의 의뢰 (11-10: 상태 화면에서 의뢰 게시판으로 옮김).
/// 묶음 26 #180: 「일일 퀘스트」 → 「오늘의 의뢰」, 양피지 쪽지 모양

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
      foldedText: '오늘의 의뢰 모두 완료 · 연속 $streak일째 · EXP +$total',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BoardPlaque('오늘의 의뢰'),
          const SizedBox(height: 4),
          for (final (i, q) in sortedQuests(quests).indexed)
            QuestRowView(quest: q, seed: i),
          const SizedBox(height: 4),
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

/// 한 종류를 모두 끝내면 작은 쪽지 한 장으로 접히는 의뢰 묶음 (11-11 #45). 누르면 펼친다.
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
        child: widget.child,
      );
    }
    return GestureDetector(
      onTap: () => setState(() => _open = true),
      child: ParchmentNote(
        seed: widget.foldedText.length,
        faded: true,
        stamp: const DoneStamp(small: true),
        child: Row(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 60),
              child: KText(widget.foldedText,
                  style: const TextStyle(
                      color: kInk, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
          const Icon(Icons.expand_more_rounded, color: kInkSoft),
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
  Widget build(BuildContext context) => NoteRewards(
        done: done,
        items: [(icon ?? const GameIcon('exp', size: 15), text)],
      );
}

/// 의뢰 쪽지 한 장 (오늘의 의뢰·주간 의뢰)
class QuestRowView extends StatelessWidget {
  const QuestRowView(
      {super.key,
      required this.quest,
      this.rewardExp,
      this.extra = const [],
      this.seed = 0});

  final QuestProgress quest;

  /// 보상 경험치 (없으면 오늘의 의뢰 경험치)
  final int? rewardExp;

  /// 경험치 말고 더 받는 보상 (예: 주간 의뢰의 금화) — (아이콘, 글)
  final List<(Widget, String)> extra;

  /// 쪽지 기울기
  final int seed;

  @override
  Widget build(BuildContext context) {
    final current =
        quest.unit == '보' ? comma(quest.current) : '${quest.current}';
    final target = quest.unit == '보' ? comma(quest.target) : '${quest.target}';
    // 끝낸 의뢰는 흐리게 + 「완료」 인장 (11-11 #45, 묶음 26 #180)
    return ParchmentNote(
      seed: seed + quest.title.length,
      faded: quest.completed,
      stamp: quest.completed ? const DoneStamp() : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(keepAll(quest.title), style: noteTitle(15)),
          const SizedBox(height: 6),
          if (!quest.completed)
            Row(children: [
              Expanded(
                child: InkBar(
                    ratio: quest.target == 0 ? 0 : quest.current / quest.target),
              ),
              const SizedBox(width: 8),
              Text('$current / $target${quest.unit}',
                  maxLines: 1,
                  style: const TextStyle(
                      color: kInkSoft,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
          NoteRewards(done: quest.completed, items: [
            (const GameIcon('exp', size: 15),
                'EXP ${rewardExp ?? QuestRules.rewardExp}'),
            ...extra,
          ]),
        ],
      ),
    );
  }
}

/// 3개 모두 완료 보너스 + 연속 달성 일수: 맨 아래 큰 쪽지(금색 리본) (11-10 C2, 묶음 26 #180)
class AllDoneRow extends StatelessWidget {
  const AllDoneRow({super.key, required this.done, required this.streak});

  final bool done;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return ParchmentNote(
      key: const Key('allDoneNote'),
      seed: 5,
      ribbon: true,
      stamp: done ? const DoneStamp() : null,
      child: Row(children: [
        const GameIcon('medal', size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(done ? '모두 완료!' : '3개 모두 완료하면 보너스',
                  style: noteTitle(16)),
              Text(
                streak > 0 ? '연속 달성 $streak일째' : '연속 달성을 시작해 보세요',
                style: const TextStyle(color: kInkSoft, fontSize: 12),
              ),
              NoteRewards(done: done, items: [
                (const GameIcon('exp', size: 15),
                    'EXP +${QuestRules.allDoneBonusExp}'),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}
