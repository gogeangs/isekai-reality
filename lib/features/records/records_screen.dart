import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models/daily_record.dart';
import '../../core/models/player_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../core/rules/village_rules.dart';
import '../bulssi/bulssi_bubble.dart';
import '../village/npc_request.dart';

/// 기록 (목업 구도): 이번 주 / 지난 주, 걸음·필드 몬스터·여관 휴식 그래프, 주간 요약 3칸.
class RecordsScreen extends StatefulWidget {
  const RecordsScreen(
      {super.key,
      required this.player,
      this.embedded = false,
      this.prophecy = const [],
      this.kingStory = const [],
      this.npcStories = const [],
      this.trial,
      this.memory});

  /// 묶음 42 #226: 마을 사람 이야기 (만난 사람마다 조각 4개, 못 본 조각은 null)
  final List<(Npc, List<String?>)> npcStories;

  /// 묶음 43 #228: 시련 최고 기록 (이번 주 · 지금까지, 훈련장 전엔 null)
  final ({int week, int ever})? trial;

  /// 왕의 사연 (묶음 34): 쓰러뜨린 분신 순서대로 늘어난다
  final List<String> kingStory;

  final PlayerState player;

  /// 떠난 정령과의 추억 (묶음 29 #182): 처음 만난 날 · 함께한 날 수 · 함께 잡은 몬스터 수
  final ({String name, DateTime met, int days, int monsters})? memory;

  /// 모은 고대 유물 글귀 (묶음 28 #181, 모은 것만)
  final List<String> prophecy;

  /// 프로필 안 '기록' 영역으로 쓸 때 (위쪽 제목·여백 없이, 11-10 #24)
  final bool embedded;

  static const List<String> week = ['월', '화', '수', '목', '금', '토', '일'];

  static String dayLabel(DateTime date, DateTime? today) {
    final base = '${date.month}월 ${date.day}일 (${week[date.weekday - 1]})';
    if (today == null) return base;
    final diff = DateTime(today.year, today.month, today.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    if (diff == 0) return '오늘 · $base';
    if (diff == 1) return '어제 · $base';
    return base;
  }

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  bool _lastWeek = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final history = p.history;
    final today = history.isEmpty ? DateTime.now() : history.last.date;
    final end = _lastWeek ? today.subtract(const Duration(days: 7)) : today;
    final days = [
      for (var i = 6; i >= 0; i--) end.subtract(Duration(days: i)),
    ];
    final byKey = {for (final r in history) r.dayKey: r};
    final records = [for (final d in days) byKey[DailyRecord.dayKeyOf(d)]];

    // 주간 요약: 경험치, 레벨업 수, 새 칭호 수
    final firstKey = DailyRecord.dayKeyOf(days.first);
    final lastKey = DailyRecord.dayKeyOf(days.last);
    var weekExp = 0;
    var before = <DailyRecord>[];
    var upTo = <DailyRecord>[];
    for (var i = 0; i < history.length; i++) {
      final k = history[i].dayKey;
      if (k.compareTo(firstKey) < 0) before = history.sublist(0, i + 1);
      if (k.compareTo(lastKey) <= 0) upTo = history.sublist(0, i + 1);
      if (k.compareTo(firstKey) >= 0 && k.compareTo(lastKey) <= 0) {
        weekExp += p.dailyExp[i].total;
      }
    }
    final startState = PlayerState.fromHistory(name: p.name, history: before);
    final endState = PlayerState.fromHistory(name: p.name, history: upTo);
    final levelUps = before.isEmpty && upTo.isEmpty
        ? 0
        : endState.level.level - startState.level.level;
    final newTitles =
        endState.titles.difference(startState.titles).length;

    // 가장 잘 걸은 날
    var best = -1;
    for (var i = 0; i < 7; i++) {
      if ((records[i]?.steps ?? 0) > (best < 0 ? 0 : records[best]!.steps)) {
        best = i;
      }
    }
    final goal = history.isEmpty ? 5000 : history.last.stepGoal;
    final top = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: Colors.transparent,
      child: ListView(
        padding: widget.embedded
            ? const EdgeInsets.fromLTRB(0, 4, 0, 24)
            : EdgeInsets.fromLTRB(14, top + 6, 14, 24),
        children: [
          if (!widget.embedded) const OrnateTopBar(title: '기록'),
          const SizedBox(height: 6),
          BulssiLine(line: best < 0
                ? '이 주에는 기록이 없어. 이번 주에 같이 채워 보자!'
                : '가장 많이 걸은 날은 ${RecordsScreen.week[days[best].weekday - 1]}요일이야! '
                    '${comma(records[best]!.steps)}보나 걸었어.'),
          const SizedBox(height: 8),
          Center(
            child: _WeekToggle(
              lastWeek: _lastWeek,
              onChanged: (v) => setState(() => _lastWeek = v),
            ),
          ),
          const SizedBox(height: 4),
          KText(
            '${days.first.month}월 ${days.first.day}일 ~ '
            '${days.last.month}월 ${days.last.day}일 · 최근 7일',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(color: Color(0xE60B0D26), blurRadius: 6),
                Shadow(color: Color(0xE60B0D26), blurRadius: 2),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _ChartPanel(
            icon: 'steps',
            title: '걸음',
            goalLabel: '목표 ${comma(goal)}보',
            days: days,
            values: [for (final r in records) (r?.steps ?? 0).toDouble()],
            goal: goal.toDouble(),
            colors: const [Color(0xFFB8322E), Color(0xFFF07A4B)],
            format: (v) => v >= 1000
                ? '${(v / 1000).toStringAsFixed(1)}k'
                : v.round().toString(),
          ),
          const SizedBox(height: 12),
          _ChartPanel(
            icon: 'crystal',
            title: '필드 몬스터',
            goalLabel: '사냥한 마릿수',
            days: days,
            values: [
              for (final r in records)
                (r?.fieldMonstersPurified ?? 0).toDouble(),
            ],
            goal: 0, // 하루 한도가 드러나지 않게 목표선 없음 (11-11 #69)
            colors: const [Color(0xFF7A3FC0), Color(0xFFC9A0FF)],
            format: (v) => v == 0 ? '' : '${v.round()}',
          ),
          const SizedBox(height: 12),
          _ChartPanel(
            icon: 'moon',
            title: '여관 휴식',
            goalLabel: '하루 한 번',
            days: days,
            values: [
              for (final r in records) (r?.restsCompleted ?? 0).toDouble(),
            ],
            goal: 1,
            colors: const [Color(0xFF2559C9), Color(0xFF6CC4FF)],
            format: (v) => v == 0 ? '' : '${v.round()}번',
          ),
          const SizedBox(height: 12),
          Row(children: [
            _SummaryTile(
                icon: 'exp',
                label: '주간 경험치',
                value: comma(weekExp)),
            const SizedBox(width: 8),
            _SummaryTile(
                icon: 'levelup',
                label: '레벨 업',
                value: '$levelUps'),
            const SizedBox(width: 8),
            _SummaryTile(
                icon: 'medal',
                label: '새 칭호',
                value: '$newTitles'),
          ]),
          // 묶음 29 #182: 떠난 정령과의 추억
          if (widget.memory case final m?) ...[
            const SizedBox(height: 16),
            Text('${josa(m.name, '와/과')}의 추억',
                key: const Key('spiritMemory'), style: AppText.title(19)),
            const SizedBox(height: 8),
            OrnatePanel(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(children: [
                _MemoryRow(
                    label: '처음 만난 날',
                    value: '${m.met.year}년 ${m.met.month}월 ${m.met.day}일'),
                _MemoryRow(label: '함께한 날', value: '${m.days}일'),
                _MemoryRow(label: '함께 잡은 몬스터', value: '${m.monsters}마리'),
              ]),
            ),
          ],
          // 묶음 28 #181: 고대 유물 글귀 (모은 조각만, 늘어나는 방식)
          if (widget.prophecy.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('고대 유물 글귀',
                key: const Key('prophecyRecords'), style: AppText.title(19)),
            const SizedBox(height: 8),
            for (final (i, t) in widget.prophecy.indexed)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1E0B8),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0x99A07840)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${i + 1}',
                      style: AppText.title(15, color: const Color(0xFF6E4C2C))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: KText(t,
                        style: const TextStyle(
                            color: Color(0xFF3A2614),
                            fontSize: 14,
                            height: 1.5,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
          ],
          // 묶음 34: 왕의 사연 (쓰러뜨린 분신만, 차례대로)
          if (widget.kingStory.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('왕의 사연',
                key: const Key('kingStoryRecords'), style: AppText.title(19)),
            const SizedBox(height: 8),
            for (final (i, t) in widget.kingStory.indexed)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D3E2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0x998A82A0)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${i + 1}',
                      style: AppText.title(15, color: const Color(0xFF4A4258))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: KText(t,
                        style: const TextStyle(
                            color: Color(0xFF2A2433),
                            fontSize: 14,
                            height: 1.5,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
          ],
          NpcStoryRecords(stories: widget.npcStories),
          if (widget.trial case final t?) ...[
            const SizedBox(height: 16),
            Text('시련 최고 기록',
                key: const Key('trialRecords'), style: AppText.title(19)),
            const SizedBox(height: 8),
            OrnatePanel(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(children: [
                _MemoryRow(
                    label: '이번 주',
                    value: t.week > 0 ? '${t.week}판' : '아직 없어요'),
                _MemoryRow(
                    label: '지금까지',
                    value: t.ever > 0 ? '${t.ever}판' : '아직 없어요'),
              ]),
            ),
          ],
          const SizedBox(height: 16),
          Text('하루별 기록', style: AppText.title(19)),
          const SizedBox(height: 8),
          for (var i = 6; i >= 0; i--)
            if (records[i] != null)
              _DayRow(
                record: records[i]!,
                exp: p.dailyExp[history.indexOf(records[i]!)].total,
                today: today,
              ),
        ],
      ),
    );
  }
}

class _WeekToggle extends StatelessWidget {
  const _WeekToggle({required this.lastWeek, required this.onChanged});

  final bool lastWeek;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool selected, bool value) => GestureDetector(
          onTap: () => onChanged(value),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 96),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: selected
                ? BoxDecoration(
                    gradient: kGoldGradient,
                    borderRadius: BorderRadius.circular(20),
                  )
                : null,
            child: Text(label,
                style: TextStyle(
                  fontFamily: 'Title',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: selected ? AppColors.goldInk : AppColors.text,
                )),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF14173E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('이번 주', !lastWeek, false),
        seg('지난 주', lastWeek, true),
      ]),
    );
  }
}

/// 막대 그래프 패널: 목표선(점선), 값 표시, 요일
class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.icon,
    required this.title,
    required this.goalLabel,
    required this.days,
    required this.values,
    required this.goal,
    required this.colors,
    required this.format,
  });

  final String icon;
  final String title;
  final String goalLabel;
  final List<DateTime> days;
  final List<double> values;
  final double goal;
  final List<Color> colors;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final maxV = [goal * 1.25, 1.0, ...values].reduce((a, b) => a > b ? a : b);
    return OrnatePanel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            GameIcon(icon, size: 24),
            const SizedBox(width: 6),
            Text(title, style: AppText.title(16)),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Text(goalLabel,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 128,
            child: LayoutBuilder(builder: (context, c) {
              const labelH = 16.0;
              const dayH = 18.0;
              final barArea = c.maxHeight - labelH - dayH;
              final goalY = labelH + barArea * (1 - goal / maxV);
              return Stack(children: [
                // 목표선 (0이면 없음)
                if (goal > 0) Positioned(
                  left: 0,
                  right: 0,
                  top: goalY,
                  child: const _DashedLine(),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < values.length; i++)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              height: labelH,
                              child: Text(format(values[i]),
                                  style: const TextStyle(
                                      color: AppColors.text, fontSize: 12)),
                            ),
                            Container(
                              width: 20,
                              height: (barArea * values[i] / maxV)
                                  .clamp(values[i] > 0 ? 3.0 : 0.0, barArea)
                                  .toDouble(),
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4)),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: colors,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                      color: colors.last.withValues(alpha: 0.4),
                                      blurRadius: 6),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: dayH,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Text(
                                    RecordsScreen.week[days[i].weekday - 1],
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ]);
            }),
          ),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final n = (c.maxWidth / 8).floor();
      return Row(children: [
        for (var i = 0; i < n; i++)
          Container(
            width: 4,
            height: 1.2,
            margin: const EdgeInsets.only(right: 4),
            color: AppColors.goldBright.withValues(alpha: 0.7),
          ),
      ]);
    });
  }
}

class _MemoryRow extends StatelessWidget {
  const _MemoryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          ),
          Text(value,
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OrnatePanel(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        radius: 12,
        child: Column(children: [
          GameIcon(icon, size: 28),
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          Text(value, style: AppText.title(22, color: AppColors.text)),
        ]),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.record, required this.exp, required this.today});

  final DailyRecord record;
  final int exp;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final parts = [
      '${comma(r.steps)}보${r.stepGoalAchieved ? ' 달성' : ''}',
      if (r.rested) '휴식',
      if (r.dungeonRuns.isNotEmpty) '던전 ${r.dungeonRuns.length}회',
      if (r.fieldMonstersPurified > 0) '사냥 ${r.fieldMonstersPurified}',
      if (r.visitedPlaceIds.isNotEmpty) '장소 ${r.visitedPlaceIds.length}곳',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x66101333),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text(RecordsScreen.dayLabel(r.date, today),
                  style: const TextStyle(
                      color: AppColors.goldBright, fontWeight: FontWeight.w700)),
            ),
            Text('+${comma(exp)} EXP', style: AppText.title(14)),
          ]),
          const SizedBox(height: 4),
          Text(parts.join(' · '),
              style: const TextStyle(color: AppColors.text, fontSize: 13)),
        ],
      ),
    );
  }
}
