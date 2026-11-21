part of '../board_screen.dart';

/// 오늘의 의뢰: 끝낸 것은 사라지고, 다 끝내면 보너스 쪽지만 → 접힘
class _DailyPanel extends StatelessWidget {
  const _DailyPanel({
    this.controller,
    required this.quests,
    required this.allDone,
    required this.streak,
    required this.day,
  });

  final AppController? controller;
  final List<QuestProgress> quests;
  final bool allDone;
  final int streak;
  final String day;

  @override
  Widget build(BuildContext context) {
    final total =
        quests.length * QuestRules.rewardExp + QuestRules.allDoneBonusExp;
    final done = quests.where((q) => q.completed).length;
    final notes = _questNotes(quests, 'd$day', 0, rewardExp: QuestRules.rewardExp, controller: controller);
    // 묶음 39 #216: 보너스 쪽지 대신 이름판 바로 아래 금빛 띠 한 줄
    // (보상은 지금처럼 다 끝내는 순간 저절로 들어온다)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BoardPlaque('오늘의 의뢰',
            key: const Key('dailyPlaque'),
            note: '완료 $done/${quests.length}'),
        _BonusBand(
          key: const Key('dailyBonusBand'),
          done: allDone,
          text: allDone
              ? '오늘 모두 완료 · 연속 $streak일째 · EXP +$total'
              : '${quests.length}개 모두 하면 EXP +${QuestRules.allDoneBonusExp}'
                  '${streak > 0 ? ' · 연속 $streak일째' : ''}',
        ),
        const SizedBox(height: 4),
        if (notes.isNotEmpty) NoteGrid(children: notes),
      ],
    );
  }
}

/// 묶음 78 #309: 오늘의·주간 의뢰 카드 — 진행 중 먼저, 받은 의뢰(보상은 저절로)는 맨 아래 흐리게 「완료」 도장
List<Widget> _questNotes(List<QuestProgress> qs, String scope, int seed,
    {required int rewardExp, int gold = 0, AppController? controller}) {
  final order = [
    for (final (i, q) in qs.indexed) if (!q.completed) (i, q),
    for (final (i, q) in qs.indexed) if (q.completed) (i, q),
  ];
  return [
    for (final (i, q) in order)
      Builder(builder: (context) {
        final id = '$scope|${q.title}';
        final current = q.unit == '보' ? comma(q.current) : '${q.current}';
        final target = q.unit == '보' ? comma(q.target) : '${q.target}';
        final dungeon = q.title.contains('던전');
        final map = !dungeon && (q.unit == '보' || q.unit == '마리');
        final icon = dungeon
            ? 'key'
            : q.unit == '보'
                ? 'steps'
                : q.unit == '마리'
                    ? 'quest'
                    : 'gold';
        return SmallNote(
          key: Key('questNote_$id'),
          title: q.title,
          seed: seed + i,
          icon: GameIcon(icon, size: 36),
          ratio: q.completed ? null : (q.target == 0 ? 0 : q.current / q.target),
          progress: q.completed ? '받았어요' : '$current / $target${q.unit}',
          reward: gold > 0 ? 'EXP +$rewardExp · 금화 +$gold' : 'EXP +$rewardExp',
          done: q.completed,
          button: q.completed || controller == null
              ? null
              : dungeon
                  ? '던전으로'
                  : map
                      ? '지도로'
                      : null,
          onButton: () {
            if (dungeon && controller != null) {
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DungeonScreen(controller: controller)));
            } else {
              tourBridge.popToRoot();
              tourBridge.openTab?.call(FeatureTourLayer.tMap);
            }
          },
          onTap: () => _showQuestDetail(context, q, rewardExp: rewardExp, gold: gold, weekly: gold > 0),
        );
      }),
  ];
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
    final done = quests.where((q) => q.completed).length;
    final now = controller.now;
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final week = DailyRecord.dayKeyOf(monday);
    final notes = _questNotes(quests, 'w$week', 3,
        rewardExp: BoardRules.weeklyExp, gold: BoardRules.weeklyGold, controller: controller);
    return FoldingQuestPanel(
      done: done == n && notes.isEmpty,
      foldedText: '주간 의뢰 모두 완료 · EXP +${n * BoardRules.weeklyExp} · '
          '금화 +${n * BoardRules.weeklyGold}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BoardPlaque('주간 의뢰', note: '완료 $done/$n · $left일 남음'),
          const _BoardNote('매주 월요일에 새로 시작해요.'),
          const SizedBox(height: 4),
          if (notes.isNotEmpty) NoteGrid(children: notes),
        ],
      ),
    );
  }
}

/// 상세 창 모양 (큰 양피지가 펼쳐짐)
class _DetailSheet extends StatelessWidget {
  const _DetailSheet({
    required this.seed,
    required this.title,
    required this.line,
    required this.rewards,
    required this.actions,
    this.ratio,
    this.progress,
    this.timeLeft,
    this.stamp,
    this.edge,
  });

  final int seed;
  final String title;
  final String line;
  final double? ratio;
  final String? progress;
  final Widget rewards;
  final String? timeLeft;
  final List<Widget> actions;
  final Widget? stamp;
  final Color? edge;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          builder: (_, v, child) => Transform.scale(
              scale: v, alignment: Alignment.bottomCenter, child: child),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ParchmentNote(
              seed: 0,
              edge: edge,
              // 묶음 47 #239: 상세 창에서는 인장을 이름 옆(오른쪽 위)에 — 아래 버튼을 가리지 않게
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Text(keepAll(title), style: noteTitle(19))),
                    if (stamp != null) ...[
                      const SizedBox(width: 8),
                      KeyedSubtree(
                          key: const Key('detailSeal'),
                          child: IgnorePointer(child: stamp!)),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(line,
                      style: const TextStyle(color: kInkSoft, fontSize: 13)),
                  if (ratio != null) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: InkBar(ratio: ratio!.clamp(0.0, 1.0))),
                      const SizedBox(width: 8),
                      Text(progress ?? '',
                          style: const TextStyle(
                              color: kInkSoft,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ],
                  rewards,
                  if (timeLeft != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(timeLeft!,
                          style: const TextStyle(
                              color: kInkSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(height: 12),
                  Row(children: actions),
                ],
              ),
            ),
          ),
        ),
      );
}

/// 오늘의·주간 의뢰 상세 (보상은 끝내면 저절로)
Future<void> _showQuestDetail(BuildContext context, QuestProgress q,
        {required int rewardExp, int gold = 0, bool weekly = false}) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheet) {
        final current = q.unit == '보' ? comma(q.current) : '${q.current}';
        final target = q.unit == '보' ? comma(q.target) : '${q.target}';
        return _DetailSheet(
          seed: q.title.length,
          title: q.title,
          line: q.completed
              ? '끝냈어요! 보상은 저절로 받아요.'
              : weekly
                  ? '매주 월요일에 새로 시작해요. 끝내면 보상은 저절로 받아요.'
                  : '끝내면 보상은 저절로 받아요.',
          ratio: q.target == 0 ? 0 : q.current / q.target,
          progress: '$current / $target${q.unit}',
          rewards: NoteRewards(items: [
            (const GameIcon('exp', size: 15), 'EXP $rewardExp'),
            if (gold > 0)
              (
                const GameIcon('gold',
                    size: 15, fallback: Icons.monetization_on_rounded),
                '금화 $gold'
              ),
          ]),
          actions: [
            Expanded(
              child: GoldButton(
                label: '닫기',
                height: 42,
                fontSize: 14,
                onPressed: () => Navigator.of(sheet).maybePop(),
              ),
            ),
          ],
        );
      },
    );

/// 긴급 의뢰 쪽지 (빨간 테두리)
Future<void> _showUrgentDetail(BuildContext context, AppController c) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheet) => ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final u = c.urgent;
          if (u == null) return const SizedBox.shrink();
          final b = c.board;
          final progress = c.urgentProgress;
          final ready = b.urgentAccepted && progress >= u.quest.target;
          final prize = u.prize == UrgentPrize.key
              ? '던전 열쇠 1'
              : Materials.info(u.rare).name;
          return _DetailSheet(
            seed: 2,
            edge: const Color(0xFFB8322A),
            stamp: b.urgentAccepted && !ready ? const WaxSeal(size: 42) : null,
            title: u.quest.title,
            line: '긴급 의뢰예요. 오늘 자정까지만 붙어 있어요.',
            ratio: b.urgentAccepted ? progress / u.quest.target : null,
            progress: b.urgentAccepted
                ? '${comma(progress)} / ${comma(u.quest.target)}${u.quest.unit}'
                : null,
            rewards: NoteRewards(items: [
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
            timeLeft: '자정까지 ${_untilMidnight(c.now)}',
            actions: [
              Expanded(
                child: GoldButton(
                  label: !b.urgentAccepted
                      ? '수락하기'
                      : ready
                          ? '보상 받기'
                          : '진행 중',
                  height: 44,
                  fontSize: 15,
                  onPressed: !b.urgentAccepted
                      ? () => c.acceptUrgent()
                      : ready
                          ? () async {
                              await c.claimUrgent();
                              if (context.mounted) {
                                Navigator.of(context).maybePop();
                              }
                            }
                          : null,
                ),
              ),
            ],
          );
        },
      ),
    );
