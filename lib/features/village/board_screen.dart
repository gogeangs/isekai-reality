import 'npc_header.dart';
import 'npc_request.dart';
import 'package:flutter/material.dart';
import '../battle/dungeon_screen.dart';
import 'package:flutter/rendering.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/models/daily_record.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../town/material_view.dart';
import 'board_parchment.dart';
import 'daily_quests.dart';
import '../../theme/top_notice.dart';
import '../tutorial/feature_tour.dart';
import '../jobs/job_skill_bar.dart';

part 'board_screen/header.dart';
part 'board_screen/notes.dart';
part 'board_screen/quests.dart';
part 'board_screen/errands.dart';
part 'board_screen/npc_asks.dart';

/// 마을 의뢰 게시판 (11-10 #26): 오늘의 의뢰 · 주간 · 길드 · 긴급.
/// 경험치는 오늘의·주간 의뢰만, 길드·긴급 의뢰는 금화·재료만 준다.
/// 묶음 26 #180: 나무 게시판에 핀으로 꽂은 양피지 쪽지 모양.
/// 묶음 33 #200·#201: 한 줄에 쪽지 2개(이름·진행만), 누르면 상세 창. 끝낸 쪽지는
/// 「완료」 인장이 찍히고 떼어지듯 사라진다
class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

/// 묶음 39 #217: 나무 게시판 그림이 화면 전체(폭에 맞추고 위아래로 스크롤).
/// 뒤로 가기·하르트 얼굴·이름 띠·말풍선은 게시판 위쪽에 얹는다(뒤에 살짝 어두운 그라데이션)
class _BoardScreenState extends State<BoardScreen> {
  AppController get controller => widget.controller;

  /// 위에 얹은 머리(뒤로 가기 + 하르트 + 탭)의 높이. 그려 본 뒤 재서 맞춘다
  double? _headerH;

  /// 묶음 70 #300: 같은 날 다시 들어오면 마지막 탭
  static String? _lastDay;
  static BoardTab? _lastTab;

  late BoardTab _tab = _firstTab();
  late final PageController _pages =
      PageController(initialPage: _tabs.indexOf(_tab).clamp(0, 3));

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  List<BoardTab> get _tabs => [
        BoardTab.today,
        if (controller.boardFull) BoardTab.weekly,
        if (controller.player.level.level >= BoardRules.errandTabLevel) BoardTab.errand,
        if (controller.activeAsks.isNotEmpty || controller.newAsks.isNotEmpty || _npcNotes(controller).isNotEmpty)
          BoardTab.npc,
      ];

  /// 받을 것이 있는 탭 (빨간 점)
  bool _claimable(BoardTab t) => switch (t) {
        BoardTab.errand => [
            for (var i = 0; i < controller.board.slots.length; i++)
              if (BoardRules.template(controller.board.slots[i].templateId,
                      level: controller.player.level.level)
                  case final tp?)
                if (controller.board.slots[i].accepted && controller.errandProgress(i) >= tp.target) i
          ].isNotEmpty,
        BoardTab.npc => controller.activeAsks.any(_askDone),
        // 묶음 84 #404: 긴급 의뢰를 아직 안 받았거나 다 해서 보상을 받을 수 있을 때
        BoardTab.today => _urgentOpen && (!controller.board.urgentAccepted || _urgentReady),
        _ => false,
      };

  bool get _urgentOpen =>
      controller.boardFull && controller.urgent != null && !controller.board.urgentDone;
  bool get _urgentReady =>
      controller.board.urgentAccepted && controller.urgentProgress >= controller.urgent!.quest.target;

  /// 묶음 78 #309: 탭의 받을 것 수 (빨간 숫자)
  int _claimCount(BoardTab t) => switch (t) {
        BoardTab.errand => [
            for (var i = 0; i < controller.board.slots.length; i++)
              if (BoardRules.template(controller.board.slots[i].templateId,
                      level: controller.player.level.level)
                  case final tp?)
                if (controller.board.slots[i].accepted && controller.errandProgress(i) >= tp.target) i
          ].length,
        BoardTab.npc => controller.activeAsks.where(_askDone).length,
        _ => 0,
      };

  bool _fresh(BoardTab t) => t == BoardTab.npc && controller.newAsks.isNotEmpty;

  BoardTab _firstTab() {
    final tabs = _tabs;
    final day = controller.player.today?.dayKey;
    if (_lastDay == day && _lastTab != null && tabs.contains(_lastTab)) return _lastTab!;
    for (final t in tabs) {
      if (_claimable(t)) return t;
    }
    for (final t in tabs) {
      if (_fresh(t)) return t;
    }
    return BoardTab.today;
  }

  void _go(BoardTab t, {bool animate = true}) {
    setState(() => _tab = t);
    _lastTab = t;
    _lastDay = controller.player.today?.dayKey;
    final i = _tabs.indexOf(t);
    if (i < 0 || !_pages.hasClients) return;
    if (animate) {
      _pages.animateToPage(i, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
    } else {
      _pages.jumpToPage(i);
    }
  }

  String _sub(BoardTab t) {
    final p = controller.player;
    switch (t) {
      case BoardTab.today:
        final q = QuestRules.forDay(p.today!);
        return '${q.where((x) => x.completed).length}/${q.length}';
      case BoardTab.weekly:
        final q = BoardRules.thisWeek(controller.history);
        return '${q.where((x) => x.completed).length}/${q.length} · '
            '${BoardRules.daysLeftInWeek(controller.now)}일';
      case BoardTab.errand:
        return '${controller.board.doneToday}/${controller.errandsPerDay}';
      case BoardTab.npc:
        return '${controller.activeAsks.length + controller.newAsks.length}';
    }
  }

  Widget _page(BoardTab t, double headerH, double screenH, double bottom) {
    final p = controller.player;
    final today = p.today!;
    final Widget panel = switch (t) {
      BoardTab.today => _DailyPanel(
          controller: controller,
          quests: QuestRules.forDay(today),
          allDone: QuestRules.allDone(today),
          streak: QuestRules.allDoneStreak(p.history),
          day: today.dayKey,
        ),
      BoardTab.weekly => _WeeklyPanel(controller: controller),
      BoardTab.errand => _ErrandPanel(controller: controller),
      BoardTab.npc => _NpcAskPanel(controller: controller),
    };
    return ListView(
      key: Key('boardScroll_${t.name}'),
      padding: EdgeInsets.zero,
      children: [
        WoodBoard(
          topInset: headerH + 4,
          minHeight: screenH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              JobSkillBar(controller: controller, places: const [SkillPlace.board]),
              panel,
              SizedBox(height: bottom),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final screenH = MediaQuery.sizeOf(context).height;
    return TourScreenMark(name: 'board', child: Scaffold(
      backgroundColor: const Color(0xFF2B1A0D),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          // 묶음 16 #142: 막 열린 게시판(Lv.4)은 오늘의 의뢰만
          final full = controller.boardFull;
          final urgent = full ? controller.urgent : null;
          final headerH = _headerH ?? pad.top + 210;
          final tabs = _tabs;
          if (!tabs.contains(_tab)) _tab = BoardTab.today;
          return Stack(children: [
            Positioned.fill(
              child: PageView(
                key: const Key('boardPages'),
                controller: _pages,
                onPageChanged: (i) {
                  if (i < tabs.length && tabs[i] != _tab) {
                    setState(() => _tab = tabs[i]);
                    _lastTab = tabs[i];
                    _lastDay = controller.player.today?.dayKey;
                  }
                },
                children: [for (final t in tabs) _page(t, headerH, screenH, pad.bottom)],
              ),
            ),
            // 위에 얹은 머리 (뒤로 가기 · 하르트 · 탭)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _SizeReporter(
                onSize: (sz) {
                  if (_headerH == null || (sz.height - _headerH!).abs() > 1) {
                    setState(() => _headerH = sz.height);
                  }
                },
                child: Container(
                  key: const Key('boardHeader'),
                  padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      // 아래로 지나가는 쪽지가 위쪽 글과 겹쳐 보이지 않게 머리 부분은 짙게
                      colors: [Color(0xF20B0D26), Color(0xE80B0D26), Color(0x000B0D26)],
                      stops: [0, 0.88, 1],
                    ),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    OrnateTopBar(
                      title: '의뢰 게시판',
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: 6),
                    // 묶음 38 #213: 정령 띠 대신 마을 사람이 안내
                    NpcHeader(
                      controller: controller,
                      npc: Npc.hart,
                      guide: VillageRules.boardGuide,
                      situation: urgent != null && !controller.board.urgentDone
                          ? VillageRules.boardUrgent
                          : null,
                    ),
                    const SizedBox(height: 8),
                    // 묶음 70 #300: 쪽지 모양 탭
                    Row(children: [
                      for (final (i, t) in tabs.indexed) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: _BoardTabChip(
                            key: Key('boardTab_${t.name}'),
                            label: t.label,
                            sub: _sub(t),
                            selected: t == _tab,
                            dot: _claimable(t) || _fresh(t),
                            count: _claimCount(t),
                            onTap: () => _go(t),
                          ),
                        ),
                      ],
                    ]),
                  ]),
                ),
              ),
            ),
          ]);
        },
      ),
    ));
  }
}

/// 묶음 70 #300: 게시판 탭
enum BoardTab {
  today('오늘'),
  weekly('주간'),
  errand('조합'),
  npc('마을 사람');

  const BoardTab(this.label);
  final String label;
}

/// 묶음 77 #350: 마을 사람 쪽지가 붙은 조합 의뢰 칸
List<int> _npcNotes(AppController c) => [
      for (var i = 0; i < c.board.slots.length; i++)
        if (BoardRules.template(c.board.slots[i].templateId, level: c.player.level.level)?.npc != null) i,
    ];

/// 다 한 조합 의뢰 칸 먼저 (그다음은 그대로)
List<int> _errandOrder(AppController c, List<int> slots) {
  bool done(int i) {
    final s = c.board.slots[i];
    final t = BoardRules.template(s.templateId, level: c.player.level.level);
    return t != null && s.accepted && c.errandProgress(i) >= t.target;
  }

  return [...slots.where(done), ...slots.where((i) => !done(i))];
}

bool _askDone(NpcAskLine a) => a.ready && (a.kind != AskKind.special || a.stage == a.stages - 1);
