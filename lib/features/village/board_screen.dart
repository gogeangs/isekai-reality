import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';
import 'daily_quests.dart';

/// 마을 의뢰 게시판 (11-10 #26): 일일 · 주간 · 수시 · 긴급.
/// 경험치는 일일·주간만, 수시·긴급은 금화·재료만 준다.
class BoardScreen extends StatelessWidget {
  const BoardScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1233),
      body: NightBackground(
        header: true,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final p = controller.player;
            final today = p.today!;
            final urgent = controller.urgent;
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
                        : '오늘의 의뢰야. 수시 의뢰는 수락해야 시작돼!'),
                const SizedBox(height: 12),
                if (urgent != null) ...[
                  _UrgentPanel(controller: controller),
                  const SizedBox(height: 12),
                ],
                DailyQuestPanel(
                  quests: QuestRules.forDay(today),
                  allDone: QuestRules.allDone(today),
                  streak: QuestRules.allDoneStreak(p.history),
                ),
                const SizedBox(height: 12),
                _WeeklyPanel(controller: controller),
                const SizedBox(height: 12),
                _ErrandPanel(controller: controller),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, {this.icon = Icons.assignment_rounded, this.note});

  final String title;
  final IconData icon;
  final String? note;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: AppColors.goldBright, size: 24),
        const SizedBox(width: 8),
        Text(title, style: AppText.title(18)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 1, color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        if (note != null) ...[
          const SizedBox(width: 8),
          Text(note!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ]);
}

/// 주간 의뢰 3개 (월요일 시작, 자동)
class _WeeklyPanel extends StatelessWidget {
  const _WeeklyPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final quests = BoardRules.thisWeek(controller.history);
    final left = BoardRules.daysLeftInWeek(controller.now);
    return OrnatePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header('주간 의뢰',
              icon: Icons.date_range_rounded, note: '$left일 남음'),
          const SizedBox(height: 2),
          for (final q in quests)
            QuestRowView(quest: q, rewardExp: BoardRules.weeklyExp),
          const SizedBox(height: 6),
          Text(
              '하나 마칠 때마다 경험치 +${BoardRules.weeklyExp}, '
              '금화 +${BoardRules.weeklyGold}. 매주 월요일에 새로 시작해요.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

/// 수시 의뢰 2칸
class _ErrandPanel extends StatelessWidget {
  const _ErrandPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final b = controller.board;
    return OrnatePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header('수시 의뢰',
              icon: Icons.push_pin_rounded,
              note: '오늘 ${b.doneToday} / ${BoardRules.errandsPerDay}'),
          const SizedBox(height: 6),
          for (var i = 0; i < b.slots.length; i++) ...[
            _ErrandCard(controller: controller, slot: i),
            if (i < b.slots.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
          const Text('수락하면 그때부터 세요. 끝내면 2시간 뒤 새 의뢰가 붙고, 자정에 모두 바뀌어요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ErrandCard extends StatelessWidget {
  const _ErrandCard({required this.controller, required this.slot});

  final AppController controller;
  final int slot;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final b = c.board;
    final s = b.slots[slot];
    final t = BoardRules.template(s.templateId);
    if (t == null) {
      final ready = s.readyAt;
      final String text;
      if (b.doneToday >= BoardRules.errandsPerDay) {
        text = '오늘 수시 의뢰는 다 끝냈어요. 내일 또 와요!';
      } else if (ready != null && c.now.isBefore(ready)) {
        final left = ready.difference(c.now);
        text = '새 의뢰가 ${left.inHours > 0 ? '${left.inHours}시간 ' : ''}'
            '${left.inMinutes % 60}분 뒤에 붙어요';
      } else {
        text = '오늘은 더 붙지 않아요';
      }
      return _CardBox(
        child: Row(children: [
          const Icon(Icons.hourglass_bottom_rounded,
              color: AppColors.textMuted, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
        ]),
      );
    }
    final progress = c.errandProgress(slot);
    final done = s.accepted && progress >= t.target;
    return _CardBox(
      highlight: done,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text(t.title,
                  style: AppText.title(16, color: AppColors.text)),
            ),
            if (s.accepted)
              Text('${comma(progress)} / ${comma(t.target)}${t.unit}',
                  style: const TextStyle(
                      color: AppColors.goldBright,
                      fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 2),
          Text('보상: ${t.rewardLabel}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          if (s.accepted) ...[
            const SizedBox(height: 6),
            GlowBar(ratio: progress / t.target, colors: BarColors.exp),
          ],
          const SizedBox(height: 8),
          Row(children: [
            if (s.accepted && !done)
              TextButton(
                onPressed: () => c.abandonErrand(slot),
                child: const Text('포기',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            const Spacer(),
            SizedBox(
              width: 130,
              child: GoldButton(
                label: !s.accepted
                    ? '수락'
                    : done
                        ? '보상 받기'
                        : '진행 중',
                height: 40,
                fontSize: 15,
                onPressed: !s.accepted
                    ? () => c.acceptErrand(slot)
                    : done
                        ? () async {
                            final ok = await c.claimErrand(slot);
                            if (!context.mounted || !ok) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('의뢰 완료! ${t.rewardLabel}')));
                          }
                        : null,
              ),
            ),
          ]),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xDD2A1230),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF6B5A), width: 1.6),
        boxShadow: const [
          BoxShadow(color: Color(0x55FF6B5A), blurRadius: 14),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.campaign_rounded, color: Color(0xFFFF8A7A)),
            const SizedBox(width: 6),
            Text('긴급 의뢰', style: AppText.title(18, color: const Color(0xFFFFB0A4))),
            const Spacer(),
            const Text('오늘 자정까지',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          Text(u.quest.title, style: AppText.title(17, color: AppColors.text)),
          const SizedBox(height: 2),
          Text('보상: $prize + 금화 ${u.quest.gold}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          if (b.urgentAccepted && !b.urgentDone) ...[
            const SizedBox(height: 6),
            GlowBar(ratio: progress / u.quest.target, colors: BarColors.gauge),
            const SizedBox(height: 2),
            Text('${comma(progress)} / ${comma(u.quest.target)}${u.quest.unit}',
                textAlign: TextAlign.end,
                style: const TextStyle(color: AppColors.text, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
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
                fontSize: 15,
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
        ],
      ),
    );
  }
}

class _CardBox extends StatelessWidget {
  const _CardBox({required this.child, this.highlight = false});

  final Widget child;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(
          color: const Color(0xAA12153A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: highlight
                  ? AppColors.goldBright
                  : AppColors.gold.withValues(alpha: 0.35)),
        ),
        child: child,
      );
}
