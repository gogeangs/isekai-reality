import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models/daily_record.dart';
import '../../core/models/player_state.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';

/// 기록: 최근 7일 걸음 · 수면 · 공부 · 방문 · 던전 · 경험치
class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key, required this.player});

  final PlayerState player;

  static const int days = 7;

  @override
  Widget build(BuildContext context) {
    final history = player.history;
    final start = history.length > days ? history.length - days : 0;
    final recent = [
      for (var i = start; i < history.length; i++)
        (record: history[i], exp: player.dailyExp[i]),
    ];
    final today = history.isEmpty ? null : history.last.date;

    final totalSteps = recent.fold<int>(0, (s, d) => s + d.record.steps);
    final sleeps = [
      for (final d in recent)
        if (d.record.sleepMinutes != null) d.record.sleepMinutes!,
    ];
    final avgSleep =
        sleeps.isEmpty ? null : sleeps.reduce((a, b) => a + b) ~/ sleeps.length;
    final totalStudy = recent.fold<int>(0, (s, d) => s + d.record.studyMinutes);
    final totalExp = recent.fold<int>(0, (s, d) => s + d.exp.total);
    final goalDays = recent.where((d) => d.record.stepGoalAchieved).length;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text('기록',
              style: TextStyle(
                  color: AppColors.goldBright,
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('최근 ${recent.length}일',
              style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 12),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StepChart(days: [for (final d in recent) d.record], today: today),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(icon: Icons.directions_walk_rounded,
                        text: '걸음 ${comma(totalSteps)}'),
                    _Chip(icon: Icons.flag_rounded,
                        text: '목표 달성 $goalDays일'),
                    _Chip(icon: Icons.nightlight_round,
                        text: avgSleep == null
                            ? '수면 기록 없음'
                            : '평균 수면 ${hoursMinutes(avgSleep)}'),
                    _Chip(icon: Icons.menu_book_rounded,
                        text: '공부 ${hoursMinutes(totalStudy)}'),
                    _Chip(icon: Icons.star_rounded,
                        text: '경험치 ${comma(totalExp)}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final d in recent.reversed)
            _DayCard(record: d.record, exp: d.exp, today: today),
        ],
      ),
    );
  }

  static String dayLabel(DateTime date, DateTime? today) {
    const week = ['월', '화', '수', '목', '금', '토', '일'];
    final base = '${date.month}월 ${date.day}일 (${week[date.weekday - 1]})';
    if (today == null) return base;
    final diff = DateTime(today.year, today.month, today.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    if (diff == 0) return '오늘 · $base';
    if (diff == 1) return '어제 · $base';
    return base;
  }
}

/// 7일 걸음 막대. 목표를 넘긴 날은 금색.
class _StepChart extends StatelessWidget {
  const _StepChart({required this.days, required this.today});

  final List<DailyRecord> days;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    const week = ['월', '화', '수', '목', '금', '토', '일'];
    final maxSteps = days.fold<int>(
        RuleConstants.minStepGoal,
        (m, d) => [m, d.steps, d.stepGoal].reduce((a, b) => a > b ? a : b));

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      d.steps >= 1000
                          ? '${(d.steps / 1000).toStringAsFixed(1)}k'
                          : '${d.steps}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 96 * (d.steps / maxSteps).clamp(0.02, 1.0),
                      decoration: BoxDecoration(
                        color: d.stepGoalAchieved
                            ? AppColors.gold
                            : AppColors.gauge.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(week[d.date.weekday - 1],
                        style: TextStyle(
                          color: d.date == today
                              ? AppColors.goldBright
                              : AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: d.date == today
                              ? FontWeight.w800
                              : FontWeight.w400,
                        )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.record, required this.exp, required this.today});

  final DailyRecord record;
  final DailyExpBreakdown exp;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final clears = r.dungeonRuns.where((x) => x.cleared).length;
    final expParts = [
      if (exp.dungeon > 0) '던전 ${exp.dungeon}',
      if (exp.fieldMonster > 0) '필드 ${exp.fieldMonster}',
      if (exp.exploration > 0) '탐험 ${exp.exploration}',
      if (exp.sleep > 0) '수면 ${exp.sleep}',
      if (exp.study > 0) '공부 ${exp.study}',
      if (exp.quest > 0) '퀘스트 ${exp.quest}',
      if (exp.streakBonus > 0) '연속 접속 ${exp.streakBonus}',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.panelBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text(RecordsScreen.dayLabel(r.date, today),
                  style: const TextStyle(
                      color: AppColors.goldBright,
                      fontWeight: FontWeight.w700)),
            ),
            Text('+${comma(exp.total)} EXP',
                style: const TextStyle(
                    color: AppColors.gold, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Fact(
                icon: r.stepGoalAchieved
                    ? Icons.check_circle_rounded
                    : Icons.directions_walk_rounded,
                text: '${comma(r.steps)} / ${comma(r.stepGoal)}보',
                highlight: r.stepGoalAchieved,
              ),
              _Fact(
                icon: Icons.nightlight_round,
                text: r.sleepMinutes == null
                    ? '수면 기록 없음'
                    : '수면 ${hoursMinutes(r.sleepMinutes!)}',
                highlight: r.sleptWell,
              ),
              if (r.studyMinutes > 0)
                _Fact(icon: Icons.menu_book_rounded,
                    text: '공부 ${hoursMinutes(r.studyMinutes)}'),
              if (r.visitedPlaceIds.isNotEmpty)
                _Fact(icon: Icons.place_rounded,
                    text: '장소 ${r.visitedPlaceIds.length}곳'),
              if (r.dungeonRuns.isNotEmpty)
                _Fact(icon: Icons.door_front_door_rounded,
                    text: '던전 ${r.dungeonRuns.length}회 (클리어 $clears)'),
              if (r.fieldMonstersPurified > 0)
                _Fact(icon: Icons.auto_awesome_rounded,
                    text: '정화 ${r.fieldMonstersPurified}마리'),
            ],
          ),
          if (expParts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(expParts.join(' · '),
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text, this.highlight = false});

  final IconData icon;
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: highlight ? AppColors.gold : AppColors.textMuted),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: AppColors.text, fontSize: 13)),
    ]);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.track,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: AppColors.gold),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: AppColors.text, fontSize: 13)),
      ]),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.panelBorder.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}
