import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';
import '../town/material_view.dart';
import 'board_parchment.dart';
import 'daily_quests.dart';
import '../../theme/top_notice.dart';
import '../tutorial/feature_tour.dart';

/// 마을 의뢰 게시판 (11-10 #26): 오늘의 의뢰 · 주간 · 길드 · 긴급.
/// 경험치는 오늘의·주간 의뢰만, 길드·긴급 의뢰는 금화·재료만 준다.
/// 묶음 26 #180: 나무 게시판에 핀으로 꽂은 양피지 쪽지 모양
class BoardScreen extends StatelessWidget {
  const BoardScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return TourScreenMark(name: 'board', child: Scaffold(
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        header: true,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final p = controller.player;
            final today = p.today!;
            // 묶음 16 #142: 막 열린 게시판(Lv.4)은 오늘의·길드 의뢰만
            final full = controller.boardFull;
            final urgent = full ? controller.urgent : null;
            return ListView(
              padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
              children: [
                OrnateTopBar(
                  title: '의뢰 게시판',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 6),
                BulssiLine(
                    line: urgent != null && !controller.board.urgentDone
                        ? '긴급 의뢰가 붙었어! 오늘 자정까지야.'
                        : '오늘의 의뢰야. 길드 의뢰는 수락해야 시작돼!'),
                const SizedBox(height: 12),
                WoodBoard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (urgent != null) ...[
                        _UrgentPanel(controller: controller),
                        const SizedBox(height: 14),
                      ],
                      DailyQuestPanel(
                        quests: QuestRules.forDay(today),
                        allDone: QuestRules.allDone(today),
                        streak: QuestRules.allDoneStreak(p.history),
                      ),
                      if (full) ...[
                        const SizedBox(height: 14),
                        _WeeklyPanel(controller: controller),
                      ],
                      const SizedBox(height: 14),
                      _ErrandPanel(controller: controller),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ));
  }
}

/// 주간 의뢰 3개 (월요일 시작, 자동)
class _WeeklyPanel extends StatelessWidget {
  const _WeeklyPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final quests = BoardRules.thisWeek(controller.history);
    final left = BoardRules.daysLeftInWeek(controller.now);
    final n = quests.length;
    return FoldingQuestPanel(
      done: quests.every((q) => q.completed),
      foldedText: '주간 의뢰 모두 완료 · EXP +${n * BoardRules.weeklyExp} · '
          '금화 +${n * BoardRules.weeklyGold}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BoardPlaque('주간 의뢰', note: '$left일 남음'),
          const SizedBox(height: 4),
          for (final (i, q) in sortedQuests(quests).indexed)
            QuestRowView(
              quest: q,
              seed: i + 3,
              rewardExp: BoardRules.weeklyExp,
              extra: [
                (
                  const GameIcon('gold',
                      size: 15, fallback: Icons.monetization_on_rounded),
                  '금화 ${BoardRules.weeklyGold}'
                ),
              ],
            ),
          const SizedBox(height: 6),
          const _BoardNote(
              '하나 마칠 때마다 경험치 +${BoardRules.weeklyExp}, '
              '금화 +${BoardRules.weeklyGold}. 매주 월요일에 새로 시작해요.'),
        ],
      ),
    );
  }
}

/// 길드 의뢰 2칸 (예전 「수시 의뢰」)
class _ErrandPanel extends StatelessWidget {
  const _ErrandPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final b = controller.board;
    return FoldingQuestPanel(
      done: b.doneToday >= BoardRules.errandsPerDay,
      foldedText: '길드 의뢰 오늘 모두 완료 · ${b.doneToday}개',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BoardPlaque('길드 의뢰',
              note: '오늘 ${b.doneToday} / ${BoardRules.errandsPerDay}'),
          const SizedBox(height: 4),
          for (var i = 0; i < b.slots.length; i++)
            _ErrandCard(controller: controller, slot: i),
          const SizedBox(height: 6),
          const _BoardNote(
              '수락하면 그때부터 세요. 끝내면 2시간 뒤 새 의뢰가 붙고, 자정에 모두 바뀌어요.'),
        ],
      ),
    );
  }
}

class _ErrandCard extends StatefulWidget {
  const _ErrandCard({required this.controller, required this.slot});

  final AppController controller;
  final int slot;

  @override
  State<_ErrandCard> createState() => _ErrandCardState();
}

class _ErrandCardState extends State<_ErrandCard> {
  /// 이 화면을 보는 동안 수락했으면 도장이 「쿵」 찍힌다
  bool? _wasAccepted;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final slot = widget.slot;
    final c = controller;
    final b = c.board;
    final s = b.slots[slot];
    final t = BoardRules.template(s.templateId);
    if (t == null) {
      final ready = s.readyAt;
      final String text;
      if (b.doneToday >= BoardRules.errandsPerDay) {
        text = '오늘 길드 의뢰는 다 끝냈어요. 내일 또 와요!';
      } else if (ready != null && c.now.isBefore(ready)) {
        final left = ready.difference(c.now);
        text = '새 의뢰가 ${left.inHours > 0 ? '${left.inHours}시간 ' : ''}'
            '${left.inMinutes % 60}분 뒤에 붙어요';
      } else {
        text = '오늘은 더 붙지 않아요';
      }
      _wasAccepted = null;
      return ParchmentNote(
        seed: slot + 7,
        faded: true,
        child: Row(children: [
          const Icon(Icons.hourglass_bottom_rounded, color: kInkSoft, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: kInkSoft, fontSize: 14)),
          ),
        ]),
      );
    }
    final progress = c.errandProgress(slot);
    final done = s.accepted && progress >= t.target;
    // 수락이 바뀌는 순간만 도장을 찍는 연출 (원래 수락돼 있던 쪽지는 그냥 찍혀 있다)
    final stampIn = _wasAccepted == false && s.accepted;
    _wasAccepted = s.accepted;
    return ParchmentNote(
      key: ValueKey('errandNote_${slot}_${s.templateId}'),
      seed: slot + (s.templateId?.length ?? 0),
      faded: done,
      stamp: done
          ? const DoneStamp()
          : s.accepted
              ? WaxSeal(key: ValueKey('seal_$slot'), stampIn: stampIn)
              : null,
      action: Row(children: [
            SizedBox(
              width: 130,
              child: GoldButton(
                key: Key(!s.accepted
                    ? 'errandAccept_$slot'
                    : done
                        ? 'errandClaim_$slot'
                        : 'errandWait_$slot'),
                label: !s.accepted
                    ? '수락'
                    : done
                        ? '보상 받기'
                        : '진행 중',
                height: 40,
                fontSize: 14,
                onPressed: !s.accepted
                    ? () => c.acceptErrand(slot)
                    : done
                        ? () async {
                            final ok = await c.claimErrand(slot);
                            if (!context.mounted || !ok) return;
                            showTopNotice(context, '의뢰 완료! ${t.rewardLabel}');
                          }
                        : null,
              ),
            ),
            if (s.accepted && !done)
              TextButton(
                onPressed: () => c.abandonErrand(slot),
                child: const Text('포기', style: TextStyle(color: kInkSoft)),
              ),
            const Spacer(),
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.title, style: noteTitle(16)),
          if (s.accepted) ...[
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: InkBar(ratio: progress / t.target)),
              const SizedBox(width: 8),
              Text('${comma(progress)} / ${comma(t.target)}${t.unit}',
                  style: const TextStyle(
                      color: kInkSoft,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
          ],
          ErrandRewards(t: t),
        ],
      ),
    );
  }
}

/// 긴급 의뢰 (빨간 테두리)
class _UrgentPanel extends StatelessWidget {
  const _UrgentPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final u = c.urgent!;
    final b = c.board;
    final progress = c.urgentProgress;
    final ready = b.urgentAccepted && progress >= u.quest.target;
    final prize = u.prize == UrgentPrize.key
        ? '던전 열쇠 1'
        : Materials.info(u.rare).name;
    if (b.urgentDone) {
      return FoldingQuestPanel(
        done: true,
        foldedText: '긴급 의뢰 완료 · $prize · 금화 +${u.quest.gold}',
        child: ParchmentNote(
          seed: 2,
          faded: true,
          stamp: const DoneStamp(),
          child: KText(u.quest.title, style: noteTitle(16)),
        ),
      );
    }
    // 긴급 의뢰: 빨간 테두리 쪽지
    return ParchmentNote(
      seed: 2,
      edge: const Color(0xFFB8322A),
      stamp: b.urgentAccepted ? const WaxSeal() : null,
      action: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 130,
              child: GoldButton(
                label: b.urgentDone
                    ? '완료'
                    : !b.urgentAccepted
                        ? '수락'
                        : ready
                            ? '보상 받기'
                            : '진행 중',
                height: 40,
                fontSize: 14,
                onPressed: b.urgentDone
                    ? null
                    : !b.urgentAccepted
                        ? () => c.acceptUrgent()
                        : ready
                            ? () => c.claimUrgent()
                            : null,
              ),
            ),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.campaign_rounded, color: Color(0xFFB8322A)),
            const SizedBox(width: 6),
            Text('긴급 의뢰', style: noteTitle(18).copyWith(color: const Color(0xFF9E2A22))),
            const Spacer(),
            const Text('오늘 자정까지',
                style: TextStyle(
                    color: kInkSoft, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text(u.quest.title, style: noteTitle(16)),
          if (b.urgentAccepted && !b.urgentDone) ...[
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: InkBar(ratio: progress / u.quest.target)),
              const SizedBox(width: 8),
              Text('${comma(progress)} / ${comma(u.quest.target)}${u.quest.unit}',
                  style: const TextStyle(
                      color: kInkSoft, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ],
          NoteRewards(items: [
            (
              u.prize == UrgentPrize.key
                  ? const GameIcon('key', size: 15)
                  : MaterialIcon(u.rare, size: 15),
              prize
            ),
            (
              const GameIcon('gold',
                  size: 15, fallback: Icons.monetization_on_rounded),
              '금화 ${u.quest.gold}'
            ),
          ]),
        ],
      ),
    );
  }
}

/// 게시판 아래 작은 설명 (나무 위 밝은 글씨)
class _BoardNote extends StatelessWidget {
  const _BoardNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: KText(text,
            style: const TextStyle(
                color: Color(0xFFEBD7AE),
                fontSize: 12,
                shadows: [Shadow(color: Color(0xCC000000), blurRadius: 3)])),
      );
}

/// 길드 의뢰 보상 띠: 금화·마석·재료를 아이콘과 함께 (11-11 #46)
class ErrandRewards extends StatelessWidget {
  const ErrandRewards({super.key, required this.t});

  final ErrandTemplate t;

  @override
  Widget build(BuildContext context) => NoteRewards(items: [
        if (t.gold > 0)
          (
            const GameIcon('gold',
                size: 15, fallback: Icons.monetization_on_rounded),
            '금화 ${t.gold}'
          ),
        if (t.manaStones > 0)
          (
            const GameIcon('mana_stone',
                size: 15, fallback: Icons.diamond_rounded),
            '마석 ${t.manaStones}'
          ),
        for (final e in t.materials.entries)
          (MaterialIcon(e.key, size: 15), '${Materials.info(e.key).name} ${e.value}'),
      ]);
}
