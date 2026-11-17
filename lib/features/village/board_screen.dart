import 'npc_header.dart';
import 'package:flutter/material.dart';
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

  /// 위에 얹은 머리(뒤로 가기 + 하르트)의 높이. 그려 본 뒤 재서 맞춘다
  double? _headerH;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final screenH = MediaQuery.sizeOf(context).height;
    return TourScreenMark(name: 'board', child: Scaffold(
      backgroundColor: const Color(0xFF2B1A0D),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final p = controller.player;
          final today = p.today!;
          // 묶음 16 #142: 막 열린 게시판(Lv.4)은 오늘의·길드 의뢰만
          final full = controller.boardFull;
          final urgent = full ? controller.urgent : null;
          final headerH = _headerH ?? pad.top + 160;
          return Stack(children: [
            Positioned.fill(
              child: ListView(
                key: const Key('boardScroll'),
                padding: EdgeInsets.zero,
                children: [
                  WoodBoard(
                    topInset: headerH + 4,
                    minHeight: screenH,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        JobSkillBar(
                            controller: controller,
                            places: const [SkillPlace.board]),
                        if (urgent != null && !controller.board.urgentDone) ...[
                          const BoardPlaque('긴급 의뢰', note: '오늘 자정까지'),
                          const SizedBox(height: 4),
                          NoteGrid(children: [
                            _UrgentNote(controller: controller),
                          ]),
                          const SizedBox(height: 14),
                        ],
                        _DailyPanel(
                          quests: QuestRules.forDay(today),
                          allDone: QuestRules.allDone(today),
                          streak: QuestRules.allDoneStreak(p.history),
                          day: today.dayKey,
                        ),
                        if (full) ...[
                          const SizedBox(height: 14),
                          _WeeklyPanel(controller: controller),
                        ],
                        const SizedBox(height: 14),
                        _ErrandPanel(controller: controller),
                        SizedBox(height: pad.bottom),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 위에 얹은 머리 (뒤로 가기 · 하르트)
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
                  padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 14),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      // 아래로 지나가는 쪽지가 위쪽 글과 겹쳐 보이지 않게 머리 부분은 짙게
                      colors: [Color(0xF20B0D26), Color(0xE00B0D26), Color(0x000B0D26)],
                      stops: [0, 0.8, 1],
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

/// 자식 크기가 정해지면 알려 준다 (그린 뒤)
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(BuildContext context, _RenderSizeReporter r) =>
      r.onSize = onSize;
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);

  ValueChanged<Size> onSize;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (size != _last) {
      _last = size;
      final s = size;
      WidgetsBinding.instance.addPostFrameCallback((_) => onSize(s));
    }
  }
}

/// 이 화면에서 사라지는 연출을 이미 보여 준 쪽지 (앱을 켜 둔 동안)
final Set<String> _vanished = {};

/// 한 줄에 쪽지 2개 (묶음 37 #206 · 묶음 39 #218): 두 칸 폭·간격이 같고 게시판 안에만.
/// 같은 줄 쪽지는 실제로 그려 본 높이 중 높은 쪽에 맞추고([EqualHeightRow]),
/// 다음 줄은 그 아래 핀 높이 + 여유만큼 띄워 어떤 쪽지도 다른 쪽지를 덮지 않는다
class NoteGrid extends StatelessWidget {
  const NoteGrid({super.key, required this.children});

  final List<Widget> children;

  static const double gap = 10;

  /// 줄 사이 (쪽지 위아래 여백 14 + 이것 = 핀이 튀어나온 높이 17 + 여유)
  static const double rowGap = 14;

  @override
  Widget build(BuildContext context) {
    Widget cell(Widget? c) => c == null
        ? const SizedBox.shrink()
        : Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: c);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i += 2)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : rowGap),
            child: EqualHeightRow(gap: gap, children: [
              cell(children[i]),
              cell(i + 1 < children.length ? children[i + 1] : null),
            ]),
          ),
      ],
    );
  }
}

/// 쪽지 이름: 단어 중간에서 끊지 않는다. 한 줄에 조금 넘치면 글씨를 줄이고,
/// 많이 넘치면 단어 단위로 두 줄. 실제 글 폭(종이 안쪽)과 기기 글자 크기로 잰다 (묶음 39 #218)
class NoteTitle extends StatelessWidget {
  const NoteTitle(this.title, {super.key, this.size = 14});

  final String title;
  final double size;

  /// 이보다 작게는 줄이지 않는다 (그때는 두 줄)
  static const double minSize = 11.5;

  /// 칸 폭 [cell] 에서 쓸 글씨 크기와 줄 수 (칸 양옆 2 + 보이는 종이 안쪽 여백)
  static (double, int) fit(String title, double cell, TextScaler scaler,
          {double size = 14, Locale? locale}) =>
      fitIn(title, cell - 4 - ParchmentNote.smallSide * 2, scaler,
          size: size, locale: locale);

  /// 글 폭 [avail] 안에서 쓸 글씨 크기와 줄 수
  static (double, int) fitIn(String title, double avail, TextScaler scaler,
      {double size = 14, Locale? locale}) {
    final tp = TextPainter(
      text: TextSpan(text: keepAll(title), style: noteTitle(size)),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      locale: locale,
      maxLines: 1,
    )..layout();
    final full = tp.width;
    tp.dispose();
    // 기기 글꼴 폭이 조금 달라도 넘치지 않게 4% 여유
    final room = avail * 0.96;
    if (full <= room) return (size, 1);
    final s = (size * room / full * 10).floorToDouble() / 10;
    if (s >= minSize) return (s, 1);
    return (size, 2);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final (s, _) = fitIn(title, box.maxWidth, MediaQuery.textScalerOf(context),
            size: size, locale: Localizations.maybeLocaleOf(context));
        // 말줄임 없이, 혹시 기기 글꼴이 더 넓어도 종이 밖으로 나가지 않고 단어 단위로 줄바꿈
        return Text(keepAll(title),
            key: const Key('noteTitle'),
            softWrap: true,
            overflow: TextOverflow.visible,
            style: noteTitle(s));
      });
}

/// 작은 쪽지 (이름 + 짧은 진행). [glow] 면 금빛으로 빛나고 「받기!」 리본
class SmallNote extends StatelessWidget {
  const SmallNote({
    super.key,
    required this.title,
    required this.seed,
    this.ratio,
    this.progress,
    this.glow = false,
    this.sealed = false,
    this.sealIn = false,
    this.edge,
    this.done = false,
    this.onTap,
    this.npc,
  });

  /// 묶음 45 #231: 마을 사람 쪽지면 그 사람 얼굴을 작게
  final Npc? npc;

  final String title;
  final int seed;
  final double? ratio;
  final String? progress;
  final bool glow;
  final bool sealed;
  final bool sealIn;
  final Color? edge;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final note = ParchmentNote(
      seed: seed,
      small: true,
      edge: edge,
      faded: done,
      stamp: done
          ? const DoneStamp(small: true)
          : sealed
              ? WaxSeal(size: 34, stampIn: sealIn)
              : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (npc != null)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              NpcFace(key: Key('noteFace_${npc!.name}'), npc: npc!, size: 26),
              const SizedBox(width: 5),
              Expanded(child: NoteTitle(title)),
            ])
          else
            NoteTitle(title),
          if (ratio != null) ...[
            const SizedBox(height: 6),
            InkBar(ratio: ratio!.clamp(0.0, 1.0)),
          ],
          if (progress != null)
            Padding(
              // 도장 자리만큼 비우고, 숫자는 줄여서라도 다 보이게
              padding: EdgeInsets.only(top: 3, right: sealed ? 34 : 0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(progress!,
                    maxLines: 1,
                    style: const TextStyle(
                        color: kInkSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
    Widget out = note;
    if (glow) {
      out = Stack(clipBehavior: Clip.none, fit: StackFit.passthrough, children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                  color: AppColors.goldBright.withValues(alpha: 0.75),
                  blurRadius: 16,
                  spreadRadius: 1),
            ],
          ),
          child: note,
        ),
        const Positioned(right: -2, bottom: 2, child: _TakeRibbon()),
      ]);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: out,
    );
  }
}

class _TakeRibbon extends StatelessWidget {
  const _TakeRibbon();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          gradient: kGoldGradient,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(color: Color(0x88000000), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: const Text('받기!',
            style: TextStyle(
                color: Color(0xFF3A2614),
                fontSize: 12,
                fontWeight: FontWeight.w900)),
      );
}

/// 끝낸 쪽지: 「완료」 인장이 찍히고 떼어지듯 사라진다 (한 번)
class VanishingNote extends StatefulWidget {
  const VanishingNote({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  State<VanishingNote> createState() => _VanishingNoteState();
}

class _VanishingNoteState extends State<VanishingNote>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..forward().whenComplete(() {
      _vanished.add(widget.id);
      if (mounted) setState(() {});
    });

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_vanished.contains(widget.id)) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) {
        // 앞 절반: 인장 · 뒤 절반: 위로 살짝 떼어지며 흐려짐
        final t = ((_a.value - 0.5) / 0.5).clamp(0.0, 1.0);
        final e = Curves.easeIn.transform(t);
        return Opacity(
          opacity: 1 - e,
          child: Transform.translate(
            offset: Offset(0, -18 * e),
            child: Transform.rotate(angle: -0.08 * e, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// 오늘의 의뢰: 끝낸 것은 사라지고, 다 끝내면 보너스 쪽지만 → 접힘
class _DailyPanel extends StatelessWidget {
  const _DailyPanel({
    required this.quests,
    required this.allDone,
    required this.streak,
    required this.day,
  });

  final List<QuestProgress> quests;
  final bool allDone;
  final int streak;
  final String day;

  @override
  Widget build(BuildContext context) {
    final total =
        quests.length * QuestRules.rewardExp + QuestRules.allDoneBonusExp;
    final done = quests.where((q) => q.completed).length;
    final notes = _questNotes(quests, 'd$day', 0, rewardExp: QuestRules.rewardExp);
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

/// 오늘의·주간 의뢰 쪽지 (끝낸 것은 한 번 사라지는 연출 뒤 빠짐)
List<Widget> _questNotes(List<QuestProgress> qs, String scope, int seed,
    {required int rewardExp, int gold = 0}) {
  final out = <Widget>[];
  for (final (i, q) in qs.indexed) {
    final id = '$scope|${q.title}';
    if (q.completed && _vanished.contains(id)) continue;
    final current = q.unit == '보' ? comma(q.current) : '${q.current}';
    final target = q.unit == '보' ? comma(q.target) : '${q.target}';
    final note = Builder(
      builder: (context) => SmallNote(
        key: Key('questNote_$id'),
        title: q.title,
        seed: seed + i + q.title.length,
        ratio: q.completed ? null : (q.target == 0 ? 0 : q.current / q.target),
        progress: q.completed ? null : '$current / $target${q.unit}',
        done: q.completed,
        onTap: () => _showQuestDetail(context, q,
            rewardExp: rewardExp, gold: gold, weekly: gold > 0),
      ),
    );
    out.add(q.completed ? VanishingNote(key: Key('vanish_$id'), id: id, child: note) : note);
  }
  return out;
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
        rewardExp: BoardRules.weeklyExp, gold: BoardRules.weeklyGold);
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

/// 길드 의뢰 칸 (예전 「수시 의뢰」)
class _ErrandPanel extends StatelessWidget {
  const _ErrandPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final b = controller.board;
    return FoldingQuestPanel(
      done: b.doneToday >= controller.errandsPerDay,
      foldedText: '조합 의뢰 오늘 모두 완료 · ${b.doneToday}개',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BoardPlaque('조합 의뢰',
              note: '오늘 ${b.doneToday} / ${controller.errandsPerDay}'),
          const _BoardNote('수락하면 시작 · 끝내면 2시간 뒤 새 의뢰 · 자정에 모두 바뀌어요'),
          const SizedBox(height: 4),
          NoteGrid(children: [
            for (var i = 0; i < b.slots.length; i++)
              _ErrandNote(controller: controller, slot: i),
          ]),
        ],
      ),
    );
  }
}

/// 길드 의뢰 남은 시간 (자정까지)
String _untilMidnight(DateTime now) {
  final mid = DateTime(now.year, now.month, now.day + 1);
  final left = mid.difference(now);
  return left.inHours > 0
      ? '${left.inHours}시간 ${left.inMinutes % 60}분'
      : '${left.inMinutes % 60 + 1}분';
}

class _ErrandNote extends StatefulWidget {
  const _ErrandNote({required this.controller, required this.slot});

  final AppController controller;
  final int slot;

  @override
  State<_ErrandNote> createState() => _ErrandNoteState();
}

class _ErrandNoteState extends State<_ErrandNote> {
  /// 방금 보상을 받은 쪽지 (인장 → 사라짐)
  (String, String)? _claimed;

  Future<void> _claim(ErrandTemplate t) async {
    final c = widget.controller;
    final ok = await c.claimErrand(widget.slot);
    if (!mounted || !ok) return;
    setState(() => _claimed = (
          'errand|${widget.slot}|${t.id}|${c.now.millisecondsSinceEpoch}',
          t.title
        ));
    showTopNotice(context, '의뢰 완료! ${t.rewardLabel}');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final slot = widget.slot;
    final b = c.board;
    final s = b.slots[slot];
    final t = BoardRules.template(s.templateId);
    final claimed = _claimed;
    if (claimed != null && !_vanished.contains(claimed.$1)) {
      return VanishingNote(
        id: claimed.$1,
        child: SmallNote(title: claimed.$2, seed: slot + 7, done: true),
      );
    }
    if (t == null) {
      final ready = s.readyAt;
      final String text;
      if (b.doneToday >= c.errandsPerDay) {
        text = '오늘 조합 의뢰는 다 끝냈어요';
      } else if (ready != null && c.now.isBefore(ready)) {
        final left = ready.difference(c.now);
        text = '새 의뢰가 ${left.inHours > 0 ? '${left.inHours}시간 ' : ''}'
            '${left.inMinutes % 60}분 뒤에 붙어요';
      } else {
        text = '오늘은 더 붙지 않아요';
      }
      // 묶음 39 #219: 다른 쪽지와 같은 종이 모양 그대로 흐리게 (잘리지 않게 바깥 Opacity 없이)
      return ParchmentNote(
        key: Key('errandEmpty_$slot'),
        seed: slot + 7,
        small: true,
        faded: true,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.hourglass_bottom_rounded, color: kInkSoft, size: 16),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(keepAll(text),
                softWrap: true,
                style: const TextStyle(
                    color: kInkSoft, fontSize: 12, height: 1.3)),
          ),
        ]),
      );
    }
    final progress = c.errandProgress(slot);
    final done = s.accepted && progress >= t.target;
    return SmallNote(
      key: Key('errandNote_$slot'),
      npc: _npcOf(t),
      title: t.title,
      seed: slot + (s.templateId?.length ?? 0),
      ratio: s.accepted ? progress / t.target : null,
      progress: s.accepted
          ? '${comma(progress)} / ${comma(t.target)}${t.unit}'
          : '수락 전',
      glow: done,
      sealed: s.accepted && !done,
      onTap: done
          ? () => _claim(t)
          : () => showErrandDetail(context, c, slot),
    );
  }
}

/// 길드 의뢰 상세 창 (큰 양피지): 이름·설명·진행·보상·남은 시간 + 수락/포기/보상 받기.
/// 수락 도장 「쿵」은 여기서
Future<void> showErrandDetail(
        BuildContext context, AppController c, int slot) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheet) => TourScreenMark(
        name: 'errandDetail',
        child: _ErrandDetail(controller: c, slot: slot),
      ),
    );

class _ErrandDetail extends StatefulWidget {
  const _ErrandDetail({required this.controller, required this.slot});

  final AppController controller;
  final int slot;

  @override
  State<_ErrandDetail> createState() => _ErrandDetailState();
}

class _ErrandDetailState extends State<_ErrandDetail> {
  bool? _wasAccepted;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final c = widget.controller;
          final slot = widget.slot;
          final s = c.board.slots[slot];
          final t = BoardRules.template(s.templateId);
          if (t == null) return const SizedBox.shrink();
          final progress = c.errandProgress(slot);
          final done = s.accepted && progress >= t.target;
          final stampIn = _wasAccepted == false && s.accepted;
          _wasAccepted = s.accepted;
          return _DetailSheet(
            seed: slot,
            stamp: done
                ? null
                : s.accepted
                    ? WaxSeal(key: ValueKey('seal_$slot'), stampIn: stampIn, size: 42)
                    : null,
            title: t.title,
            line: switch ((_npcOf(t), s.accepted)) {
              (final n?, false) =>
                '${josa(VillageRules.npc(n).name, '이/가')} 붙인 쪽지예요. 수락하면 그때부터 세요.',
              (_, true) => '수락했어요. 끝내면 쪽지가 빛나요.',
              _ => '수락하면 그때부터 세요.',
            },
            ratio: s.accepted ? progress / t.target : null,
            progress: s.accepted
                ? '${comma(progress)} / ${comma(t.target)}${t.unit}'
                : null,
            rewards: ErrandRewards(t: t),
            timeLeft: '자정까지 ${_untilMidnight(c.now)}',
            actions: [
              // 묶음 47 #239: 「포기」는 왼쪽에 붉은 테두리 작은 버튼, 누르면 확인 창
              if (s.accepted && !done) ...[
                _AbandonButton(
                  key: Key('errandAbandon_$slot'),
                  onConfirmed: () async {
                    await c.abandonErrand(slot);
                    if (context.mounted) Navigator.of(context).maybePop();
                  },
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: GoldButton(
                  key: Key(!s.accepted
                      ? 'errandAccept_$slot'
                      : done
                          ? 'errandClaim_$slot'
                          : 'errandWait_$slot'),
                  label: !s.accepted
                      ? '수락하기'
                      : done
                          ? '보상 받기'
                          : '진행 중',
                  height: 44,
                  fontSize: 15,
                  onPressed: !s.accepted
                      ? () async {
                          await c.acceptErrand(slot);
                          // 도장이 「쿵」 찍힌 걸 보고 닫힌다
                          await Future<void>.delayed(
                              const Duration(milliseconds: 1100));
                          if (context.mounted) Navigator.of(context).maybePop();
                        }
                      : done
                          ? () async {
                              final ok = await c.claimErrand(slot);
                              if (!context.mounted) return;
                              Navigator.of(context).maybePop();
                              if (ok) {
                                showTopNotice(
                                    context, '의뢰 완료! ${t.rewardLabel}');
                              }
                            }
                          : null,
                ),
              ),
            ],
          );
        },
      );
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
class _UrgentNote extends StatelessWidget {
  const _UrgentNote({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final u = c.urgent!;
    final b = c.board;
    final progress = c.urgentProgress;
    final ready = b.urgentAccepted && progress >= u.quest.target;
    return SmallNote(
      key: const Key('urgentNote'),
      title: u.quest.title,
      seed: 2,
      edge: const Color(0xFFB8322A),
      ratio: b.urgentAccepted ? progress / u.quest.target : null,
      progress: b.urgentAccepted
          ? '${comma(progress)} / ${comma(u.quest.target)}${u.quest.unit}'
          : '수락 전',
      glow: ready,
      sealed: b.urgentAccepted && !ready,
      onTap: ready
          ? () async {
              await c.claimUrgent();
              if (context.mounted) showTopNotice(context, '긴급 의뢰 완료!');
            }
          : () => _showUrgentDetail(context, c),
    );
  }
}

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

/// 이름판 바로 아래 작은 한 줄 설명 (묶음 37 #206). 묶음 38 #215: 나무판 위에서도 또렷하게
/// 작은 어두운 반투명 띠 위에 밝은 글씨. 넘치면 글씨를 줄여서라도 한 줄
class _BoardNote extends StatelessWidget {
  const _BoardNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 5, 2, 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 3, 9, 4),
          decoration: BoxDecoration(
            color: const Color(0xC21A0F06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(text,
                maxLines: 1,
                style: const TextStyle(
                    color: Color(0xFFF6E7C4),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      );
}

/// 오늘의 의뢰 보너스 금빛 띠 (묶음 39 #216): 설명 띠와 같은 모양·높이, 색만 금빛.
/// 다 끝내면 조금 더 밝게 빛난다
class _BonusBand extends StatelessWidget {
  const _BonusBand({super.key, required this.text, required this.done});

  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 5, 2, 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(7, 2, 9, 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: done
                ? const [Color(0xFFF7D978), Color(0xFFD9A441)]
                : const [Color(0xE6D9B060), Color(0xE6B8862E)]),
            borderRadius: BorderRadius.circular(8),
            boxShadow: done
                ? [
                    BoxShadow(
                        color: AppColors.goldBright.withValues(alpha: 0.6),
                        blurRadius: 10),
                  ]
                : null,
          ),
          child: Row(children: [
            const GameIcon('medal', size: 16),
            const SizedBox(width: 4),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(text,
                    maxLines: 1,
                    style: const TextStyle(
                        color: Color(0xFF3A2614),
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ),
      );
}

/// 길드 의뢰 보상 띠: 금화·마석·재료를 아이콘과 함께 (11-11 #46)
/// 묶음 45 #231: 마을 사람 쪽지의 그 사람
Npc? _npcOf(ErrandTemplate t) =>
    Npc.values.where((n) => n.name == t.npc).firstOrNull;

class ErrandRewards extends StatelessWidget {
  const ErrandRewards({super.key, required this.t});

  final ErrandTemplate t;

  @override
  Widget build(BuildContext context) => NoteRewards(items: [
        if (t.exp > 0)
          (
            const Icon(Icons.auto_awesome_rounded, size: 15, color: kInkSoft),
            '경험치 ${t.exp}'
          ),
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


/// 묶음 47 #239: 의뢰 포기 버튼 (붉은 테두리, 누르면 확인 창)
class _AbandonButton extends StatelessWidget {
  const _AbandonButton({super.key, required this.onConfirmed});

  final Future<void> Function() onConfirmed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFA8322A),
          side: const BorderSide(color: Color(0xFFB8453A), width: 1.6),
          backgroundColor: const Color(0x22B8453A),
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (d) => GameAlert(
              title: const Text('이 의뢰를 포기할까요?'),
              content: const KText('지금까지 센 것은 사라지고, 2시간 뒤 새 의뢰가 붙어요.'),
              actions: [
                TextButton(
                    key: const Key('errandAbandonNo'),
                    onPressed: () => Navigator.of(d).pop(false),
                    child: const Text('계속하기')),
                TextButton(
                    key: const Key('errandAbandonYes'),
                    onPressed: () => Navigator.of(d).pop(true),
                    child: const Text('포기하기')),
              ],
            ),
          );
          if (ok == true) await onConfirmed();
        },
        child: const Text('포기',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );
}
